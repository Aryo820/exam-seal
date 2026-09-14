import 'dart:async';

import 'package:flutter/material.dart';

import '../models/exam_sessions.dart';
import '../services/attempt_state_machine.dart';
import '../services/exam_session_controller.dart';
import '../services/exam_protection.dart';
import '../services/local_auth_gate.dart';
import '../services/session_store.dart';
import '../screens/boot_screen.dart' show SplashPlaceholder;
import '../screens/create_session_screen.dart';
import '../screens/ended_screen.dart';
import '../screens/exam_screen.dart';
import '../screens/home_screen.dart';
import '../screens/locked_screen.dart';
import '../screens/pre_exam_screen.dart';
import '../screens/process_recovery_screen.dart';
import '../screens/repeat_session_screen.dart';
import '../screens/scan_qr_screen.dart';
import '../screens/session_qr_screen.dart';
import '../screens/teacher_sessions_screen.dart';

/// Composition root sederhana: satu widget tingkat atas yang memiliki
/// [ExamSessionController] dan merutekan screen sesuai state attempt.
/// Tanpa provider/riverpod/bloc — hanya StatefulWidget + callback publik
/// screen yang sudah ada.
class ExamApp extends StatefulWidget {
  const ExamApp({required this.controller, this.formContent, super.key});

  final ExamSessionController controller;

  /// Pengganti konten WebView (hanya untuk pengujian widget); alur
  /// produksi membiarkannya null sehingga WebView Google Forms dibuat.
  final Widget? formContent;

  @override
  State<ExamApp> createState() => _ExamAppState();
}

class _ExamAppState extends State<ExamApp> with WidgetsBindingObserver {
  ExamSessionController get controller => widget.controller;

  final _navigatorKey = GlobalKey<NavigatorState>();

  StoredAttempt? _current;
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_boot());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Boot: retensi → pemulihan proteksi tertunda → attempt tersimpan →
  /// rute yang benar (FR12). Restart saat attempt aktif → recoveryPending
  /// tanpa pelanggaran baru, bukan langsung membuka Google Forms.
  Future<void> _boot() async {
    try {
      await controller.runRetention();
    } on StorageFailure {
      // Retensi gagal bukan alasan menahan siswa; boot tetap lanjut.
    }
    try {
      await controller.resolvePendingRestores();
    } on StorageFailure {
      // Pemulihan tertunda gagal dicoba; EndedScreen menyediakan retry.
    }
    try {
      final current = await controller.loadCurrentAttempt();
      if (current != null && current.state == AttemptState.active) {
        await controller.markProcessDeath();
        _current = await controller.loadCurrentAttempt();
      } else {
        _current = current;
      }
    } on StorageFailure {
      _current = null;
    }
    if (!mounted) return;
    setState(() => _booting = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_refreshProtectionOnResume());
  }

  /// Baca ulang proteksi saat resume: pencabutan akses oleh pengguna saat
  /// ujian harus terlihat (PRD FR09).
  Future<void> _refreshProtectionOnResume() async {
    final protection = controller.protection;
    if (protection is! ExamProtection || _current == null) return;
    if (_current!.state != AttemptState.active &&
        _current!.state != AttemptState.locked) {
      return;
    }
    await protection.refreshOnResume();
    if (!mounted) return;
    // Akses dicabut saat ujian → event ambigu tercatat, pengawas menangani.
    final status = await protection.checkStatus();
    if (!status.notificationAccessGranted) {
      await controller.recordAmbiguousEvent('notificationAccessRevoked');
    }
    setState(() {});
  }

  Future<bool> _verifySupervisorPin(String pin) async {
    final session = _current?.session;
    if (session != null) {
      return controller.verifySupervisorPin(pin, session);
    }
    final sessions = await controller.listTeacherSessions();
    if (sessions.isEmpty) return false;
    return controller.verifySupervisorPin(pin, sessions.first);
  }

  void _push(Widget screen) {
    _navigatorKey.currentState?.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  void _goHome() {
    _current = null;
    _push(_homeScreen());
  }

  // ---- Beranda & mode guru ----

  Widget _homeScreen() => HomeScreen(
        hasActiveStudentSession: _current != null,
        verifySupervisorPin: _verifySupervisorPin,
        onResumeStudentSession: _resumeStoredAttempt,
        onOpenTeacherMode: () => unawaited(_openTeacherMode()),
        onOpenStudentScan: () => _navigatorKey.currentState?.push(
              MaterialPageRoute<void>(builder: (_) => _scanScreen()),
            ),
      );

  Future<void> _openTeacherMode() async {
    // Push segera dengan daftar terakhir diketahui, lalu perbarui saat
    // data siap; siswa tidak menunggu I/O untuk melihat mode guru.
    _push(TeacherSessionsScreen(
      sessions: _teacherSessions,
      onCreateSession: _openCreateSession,
    ));
    try {
      _teacherSessions = await controller.listTeacherSessions();
    } on StorageFailure {
      return;
    }
    if (!mounted) return;
    _push(TeacherSessionsScreen(
      sessions: _teacherSessions,
      onCreateSession: _openCreateSession,
    ));
  }

  List<ExamSession> _teacherSessions = const [];

  VoidCallback get _openCreateSession =>
      () => _push(CreateSessionScreen(createSession: _createSession));

  Future<bool> Function(String, Uri) get _createSession =>
      (examName, formUrl) async {
        try {
          final created = await controller.createTeacherSession(
            examName: examName,
            formUrl: formUrl,
          );
          if (!mounted) return false;
          _push(_sessionQrScreen(created.session));
          return true;
        } on StorageFailure {
          return false;
        }
      };

  Widget _sessionQrScreen(ExamSession session) => SessionQrScreen(
        session: session,
        authenticateSupervisor: LocalAuthGate.authenticate,
        readSupervisorPin: () => controller.readTeacherPin(session.sessionId),
      );

  // ---- Mode siswa ----

  Widget _scanScreen() => ScanQrScreen(onSession: _onScanned);

  Future<void> _onScanned(ExamSession scanned) async {
    final result = await controller.importScannedSession(scanned);
    if (!mounted) return;
    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error!)),
      );
      return;
    }
    try {
      _current = await controller.loadCurrentAttempt();
    } on StorageFailure {
      _current = null;
    }
    switch (result.route) {
      case ScanImportRoute.preExam:
        _push(_preExamScreen(scanned));
      case ScanImportRoute.storedAttempt:
        await _resumeStoredAttempt();
      case ScanImportRoute.endedNeedsPin:
        _push(_repeatScreen(scanned));
      case null:
        _goHome();
    }
  }

  Future<void> _resumeStoredAttempt() async {
    final current = _current;
    if (current == null) {
      _push(_homeScreen());
      return;
    }
    switch (current.state) {
      case AttemptState.locked:
        _push(_lockedScreen());
      case AttemptState.recoveryPending:
        _push(_recoveryScreen());
      case AttemptState.active:
      case AttemptState.preExam:
        _push(_examScreen());
      case AttemptState.ended:
        _push(_homeScreen());
    }
  }

  // ---- Pre-exam & mulai ----

  Widget _preExamScreen(ExamSession session) => PreExamScreen(
        session: session,
        loadReadiness: () => controller.assessReadiness(session),
        onOpenNotificationSettings: () async {
          final protection = controller.protection;
          if (protection is ExamProtection) {
            await protection.openNotificationPolicySettings();
          }
        },
        onStart: () => _startAttempt(session),
      );

  Future<bool> _startAttempt(ExamSession session) async {
    final result = await controller.startStudentAttempt(session);
    if (!mounted || !result.started) return false;
    _current = await controller.loadCurrentAttempt();
    _push(_examScreen());
    return true;
  }

  // ---- Ujian aktif ----

  Widget _examScreen() {
    final current = _current!;
    final session = current.session ?? _fallbackSession();
    return ExamScreen(
      session: session,
      violationCount: current.violationCount,
      violationReason: current.violationReason,
      verifySupervisorPin: _verifySupervisorPin,
      registerViolation: (trigger) async {
        final result = await controller.registerViolation(trigger);
        return ViolationResultMsg(
          outcome: result.outcome,
          violationCount: result.violationCount,
          reason: result.reason,
        );
      },
      recordAmbiguousEvent: (type) => controller.recordAmbiguousEvent(type),
      onViolationLock: _onViolationLock,
      endAttemptWithAuthorization: () =>
          controller.finishAttemptAfterPin(
            reason: 'Diakhiri pengawas setelah pemeriksaan pengiriman jawaban.',
          ),
      retryRestoreSettings: controller.retryRestoreSettings,
      onReturnHome: _goHome,
    );
  }

  Future<void> _onViolationLock() async {
    _current = await controller.loadCurrentAttempt();
    if (!mounted) return;
    _push(_lockedScreen());
  }

  // ---- Terkunci ----

  Widget _lockedScreen() {
    final current = _current!;
    final session = current.session ?? _fallbackSession();
    final rawReason =
        current.violationReason ?? AttemptStateMachine.countedViolationTriggers.first;
    return LockedScreen(
      session: session,
      violationCount: current.violationCount,
      violationReason: AttemptStateMachine.describeTrigger(rawReason),
      verifySupervisorPin: _verifySupervisorPin,
      onContinueExam: () async {
        await controller.confirmContinueAfterPin();
        _current = await controller.loadCurrentAttempt();
        if (!mounted) return;
        _push(_examScreen());
      },
      onEndExam: () async {
        final restored = await controller.finishAttemptAfterPin(
          reason: 'Diakhiri pengawas dari ujian terkunci.',
        );
        if (!mounted) return;
        _showEnded(
          session,
          'Diakhiri pengawas dari ujian terkunci.',
          restored,
        );
      },
    );
  }

  // ---- Pemulihan proses ----

  Widget _recoveryScreen() {
    final current = _current!;
    final session = current.session ?? _fallbackSession();
    return ProcessRecoveryScreen(
      session: session,
      violationCount: current.violationCount,
      verifySupervisorPin: _verifySupervisorPin,
      onContinueExam: () async {
        await controller.confirmContinueAfterPin();
        _current = await controller.loadCurrentAttempt();
        if (!mounted) return;
        _push(_examScreen());
      },
      onEndExam: () async {
        final restored = await controller.finishAttemptAfterPin(
          reason: 'Diakhiri pengawas setelah pemulihan aplikasi.',
        );
        if (!mounted) return;
        _showEnded(
          session,
          'Diakhiri pengawas setelah pemulihan aplikasi.',
          restored,
        );
      },
    );
  }

  void _showEnded(ExamSession session, String reason, bool settingsRestored) {
    _current = null;
    _push(EndedScreen(
      session: session,
      endReason: reason,
      settingsRestored: settingsRestored,
      retryRestoreSettings: controller.retryRestoreSettings,
      onReturnHome: _goHome,
    ));
  }

  // ---- Pengulangan sesi berakhir ----

  Widget _repeatScreen(ExamSession session) => RepeatSessionScreen(
        session: session,
        previousViolationCount: _current?.violationCount ?? 0,
        verifySupervisorPin: (pin) => controller.verifySupervisorPin(pin, session),
        onRepeatApproved: () async {
          final result = await controller.repeatStudentAttempt(session);
          if (!mounted) return;
          if (!result.started) return;
          _current = await controller.loadCurrentAttempt();
          _push(_examScreen());
        },
      );

  ExamSession _fallbackSession() => ExamSession(
        schemaVersion: 2,
        sessionId: 'unknown',
        sessionCode: '—',
        examName: 'Sesi ujian',
        formUrl: Uri.parse('https://forms.gle/example'),
        pinSalt: '',
        pinVerifier: '',
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExamSeal',
      debugShowCheckedModeBanner: false,
      theme: _theme,
      navigatorKey: _navigatorKey,
      home: _booting
          ? const SplashPlaceholder()
          : (_current != null ? _attemptShell() : _homeScreen()),
    );
  }

  Widget _attemptShell() {
    final state = _current!.state;
    if (state == AttemptState.recoveryPending) return _recoveryScreen();
    if (state == AttemptState.locked) {
      // FR06: konten soal disembunyikan dan tidak dapat diinteraksikan,
      // tetapi WebView dipertahankan — mengunci tidak me-reload Form.
      // LockedScreen menutupi penuh di atas ExamScreen yang di-Offstage.
      return Stack(
        textDirection: TextDirection.ltr,
        children: [
          Offstage(child: _examScreen()),
          Positioned.fill(child: _lockedScreen()),
        ],
      );
    }
    return _examScreen();
  }

  static final ThemeData _theme = ThemeData(
    scaffoldBackgroundColor: Colors.white,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF171717),
      primary: const Color(0xFF171717),
      surface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF171717),
      surfaceTintColor: Colors.transparent,
    ),
  );
}
