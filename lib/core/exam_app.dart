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
import '../screens/form_test_screen.dart';
import '../screens/form_test_run_screen.dart';
import '../screens/supervisor_pin_access_screen.dart';
import '../screens/supervisor_pin_screen.dart';
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
  final _protectionNotice = ValueNotifier<String?>(null);
  final _attemptView = ValueNotifier<StoredAttempt?>(null);

  StoredAttempt? _current;
  bool _booting = true;
  bool _retryingRecovery = false;
  String? _bootRecoveryError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_boot());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _protectionNotice.dispose();
    _attemptView.dispose();
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
    var restored = false;
    try {
      restored = await controller.resolvePendingRestores();
    } catch (_) {
      restored = false;
    }
    if (!restored) {
      if (!mounted) return;
      setState(() {
        _booting = false;
        _bootRecoveryError =
            'Pemulihan proteksi perangkat diperlukan. Minta pengawas memeriksa perangkat ini sebelum ujian dilanjutkan.';
      });
      return;
    }
    try {
      final current = await controller.loadCurrentAttempt();
      if (current != null && current.state == AttemptState.active) {
        await controller.markProcessDeath();
        _setCurrent(await controller.loadCurrentAttempt());
      } else {
        _setCurrent(current);
      }
    } on StorageFailure {
      _setCurrent(null);
    }
    if (!mounted) return;
    setState(() {
      _booting = false;
      _bootRecoveryError = null;
    });
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
    String? notice;
    try {
      final status = await protection.refreshOnResume();
      if (!status.notificationAccessGranted) {
        await controller.recordAmbiguousEvent('notificationAccessRevoked');
        notice =
            'Akses pengendalian notifikasi dicabut. Status ujian dipertahankan; minta pengawas menangani perangkat ini.';
      } else if (!status.secureWindowActive ||
          !status.notificationProtectionActive) {
        await controller.recordAmbiguousEvent('protectionRefreshFailed');
        notice =
            'Proteksi perangkat tidak lagi aktif. Status ujian dipertahankan; minta pengawas menangani perangkat ini.';
      }
    } catch (_) {
      notice =
          'Status proteksi tidak dapat diperiksa. Status ujian dipertahankan; minta pengawas menangani perangkat ini.';
    }
    if (!mounted) return;
    _protectionNotice.value = notice;
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

  void _setCurrent(StoredAttempt? current) {
    _current = current;
    _attemptView.value = current;
  }

  void _goHome() {
    _setCurrent(null);
    _push(_homeScreen());
  }

  Future<void> _retryBootRecovery() async {
    if (_retryingRecovery) return;
    setState(() {
      _retryingRecovery = true;
      _booting = true;
      _bootRecoveryError = null;
    });
    await _boot();
    if (mounted) setState(() => _retryingRecovery = false);
  }

  Widget _bootRecoveryScreen() => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_outlined, size: 40),
              const SizedBox(height: 16),
              Text(
                _bootRecoveryError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _retryingRecovery ? null : _retryBootRecovery,
                child: Text(
                  _retryingRecovery ? 'Memulihkan...' : 'Coba Pulihkan',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // ---- Beranda & mode guru ----

  Widget _homeScreen() => HomeScreen(
    hasActiveStudentSession: _current != null,
    verifySupervisorPin: (pin) async {
      final session = _current?.session;
      return session != null &&
          await controller.authorizeTeacherMode(pin, session);
    },
    onResumeStudentSession: _resumeStoredAttempt,
    onOpenTeacherMode: () => unawaited(
      _current == null ? _openTeacherMode() : _openTeacherModeAfterActivePin(),
    ),
    onOpenStudentScan: () => _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(builder: (_) => _scanScreen()),
    ),
  );

  Future<void> _openTeacherMode() async {
    await _navigatorKey.currentState?.push<void>(
      MaterialPageRoute(
        builder: (_) => TeacherSessionsScreen(
          loadSessions: controller.listTeacherSessions,
          onCreateSession: _openCreateSession,
          onShowQr: _openSessionQr,
        ),
      ),
    );
  }

  Future<void> _openTeacherModeFromActive(ExamSession session) async {
    final verified = await _navigatorKey.currentState?.push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SupervisorPinScreen(
          heading: 'Buka mode guru',
          description:
              'Masukkan PIN pengawas lima digit. Sesi siswa tetap aktif.',
          verifyPin: (pin) => controller.authorizeTeacherMode(pin, session),
        ),
      ),
    );
    if (verified != true || !mounted) return;
    if (!await controller.confirmTeacherModeAfterActivePin() || !mounted) {
      return;
    }
    await _openTeacherMode();
  }

  Future<void> _openTeacherModeAfterActivePin() async {
    if (!await controller.confirmTeacherModeAfterActivePin() || !mounted) {
      return;
    }
    await _openTeacherMode();
  }

  Future<void> _openTeacherModeAfterVerifiedPin() async {
    if (!await controller.authorizeTeacherModeAfterVerifiedPin()) return;
    if (mounted) await _openTeacherMode();
  }

  Future<void> _openCreateSession() async {
    ExamSession? createdSession;
    final created = await _navigatorKey.currentState?.push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateSessionScreen(
          createSession: (name, url) async {
            final result = await controller.createTeacherSession(
              examName: name,
              formUrl: url,
            );
            createdSession = result.session;
            return true;
          },
        ),
      ),
    );
    if (!mounted || created != true || createdSession == null) return;
    await _openSessionQr(createdSession!);
  }

  Future<void> _openSessionQr(ExamSession session) async {
    try {
      if (!await controller.isFormConfirmed(session)) {
        if (!mounted) return;
        var inspected = false;
        final confirmed = await _navigatorKey.currentState?.push<bool>(
          MaterialPageRoute(
            builder: (formContext) => FormTestScreen(
              session: session,
              onAccessPin: () => _navigatorKey.currentState?.push<void>(
                MaterialPageRoute(
                  builder: (_) => SupervisorPinAccessScreen(
                    session: session,
                    authenticateDevice: LocalAuthGate.authenticate,
                    readPin: () => controller.readTeacherPin(session.sessionId),
                  ),
                ),
              ),
              runFormTest: () async {
                inspected = false;
                await controller.beginFormTest(session);
                if (!mounted ||
                    !formContext.mounted ||
                    ModalRoute.of(formContext)?.isCurrent != true) {
                  return false;
                }
                inspected =
                    await _navigatorKey.currentState?.push<bool>(
                      MaterialPageRoute(
                        builder: (_) => FormTestRunScreen(
                          session: session,
                          verifyPin: (pin) =>
                              controller.verifySupervisorPin(pin, session),
                          recordBlocked: () =>
                              controller.recordFormNavigationBlocked(session),
                        ),
                      ),
                    ) ==
                    true;
                return inspected;
              },
              confirmFormReady: () async =>
                  inspected && await controller.confirmFormReady(session),
            ),
          ),
        );
        if (confirmed != true) return;
      }
      if (!mounted) return;
      await _navigatorKey.currentState?.push<void>(
        MaterialPageRoute(builder: (_) => _sessionQrScreen(session)),
      );
    } catch (_) {
      final context = _navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'QR belum dapat dibuka. Periksa penyimpanan dan ulangi pemeriksaan Form.',
            ),
          ),
        );
      }
    }
  }

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
      throw StorageFailure(result.error!);
    }
    _setCurrent(await controller.loadCurrentAttempt());
    if (!mounted) return;
    if (_current != null) {
      await _resumeStoredAttempt();
      return;
    }
    switch (result.route) {
      case ScanImportRoute.preExam:
        _push(_preExamScreen(scanned));
      case ScanImportRoute.storedAttempt:
        throw StorageFailure(
          'Status sesi berubah. Scan ulang untuk memeriksa status terbaru.',
        );
      case ScanImportRoute.endedNeedsPin:
        final previous = await controller.loadLastEndedAttemptFor(scanned);
        _push(_repeatScreen(scanned, previous?.violationCount ?? 0));
      case null:
        throw StorageFailure('Sesi belum dapat dibuka. Coba scan ulang.');
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
      case AttemptState.recoveryPending:
      case AttemptState.active:
      case AttemptState.preExam:
        _push(_attemptShell());
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
    _setCurrent(await controller.loadCurrentAttempt());
    _push(_attemptShell());
    return true;
  }

  // ---- Ujian aktif ----

  Widget _examScreen() {
    final current = _current!;
    final session = current.session ?? _fallbackSession();
    return ExamScreen(
      session: session,
      formContent: widget.formContent,
      protectionNotice: _protectionNotice,
      violationCount: current.violationCount,
      violationReason: current.violationReason,
      verifySupervisorPin: (pin) => controller.authorizeEnd(pin, session),
      cancelEndAuthorization: controller.cancelEndAuthorization,
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
      endAttemptWithAuthorization: () => controller.finishAttemptAfterPin(
        reason: 'Diakhiri pengawas setelah pemeriksaan pengiriman jawaban.',
      ),
      retryRestoreSettings: controller.retryRestoreSettings,
      onReturnHome: _goHome,
      onOpenTeacherMode: () => unawaited(_openTeacherModeFromActive(session)),
    );
  }

  Future<void> _onViolationLock() async {
    _setCurrent(await controller.loadCurrentAttempt());
    if (!mounted) return;
  }

  // ---- Terkunci ----

  Widget _lockedScreen() {
    final current = _current!;
    final session = current.session ?? _fallbackSession();
    final rawReason =
        current.violationReason ??
        AttemptStateMachine.countedViolationTriggers.first;
    return LockedScreen(
      session: session,
      violationCount: current.violationCount,
      violationReason: AttemptStateMachine.describeTrigger(rawReason),
      verifySupervisorPin: _verifySupervisorPin,
      onContinueExam: _continueProtectedAttempt,
      onAuthorizationCancelled: controller.cancelSupervisorAuthorization,
      onOpenTeacherMode: _openTeacherModeAfterVerifiedPin,
      onEndExam: () async {
        if (!await controller.authorizeEndAfterVerifiedPin()) return;
        final restored = await controller.finishAttemptAfterPin(
          reason: 'Diakhiri pengawas dari ujian terkunci.',
        );
        if (!mounted) return;
        _showEnded(session, 'Diakhiri pengawas dari ujian terkunci.', restored);
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
      onContinueExam: _continueProtectedAttempt,
      onAuthorizationCancelled: controller.cancelSupervisorAuthorization,
      onOpenTeacherMode: _openTeacherModeAfterVerifiedPin,
      onEndExam: () async {
        if (!await controller.authorizeEndAfterVerifiedPin()) return;
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
    _setCurrent(null);
    _push(
      EndedScreen(
        session: session,
        endReason: reason,
        settingsRestored: settingsRestored,
        retryRestoreSettings: controller.retryRestoreSettings,
        onReturnHome: _goHome,
      ),
    );
  }

  Future<void> _continueProtectedAttempt() async {
    if (!await controller.confirmContinueAfterPin()) {
      final context = _navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Proteksi perangkat gagal diaktifkan. Ujian tetap terkunci; minta pengawas menangani perangkat ini.',
            ),
          ),
        );
      }
      return;
    }
    _setCurrent(await controller.loadCurrentAttempt());
    if (!mounted) return;
  }

  // ---- Pengulangan sesi berakhir ----

  Widget _repeatScreen(ExamSession session, int previousViolationCount) =>
      RepeatSessionScreen(
        session: session,
        previousViolationCount: previousViolationCount,
        verifySupervisorPin: (pin) =>
            controller.verifyRepeatSupervisorPin(pin, session),
        onAuthorizationCancelled: controller.cancelSupervisorAuthorization,
        onRepeatApproved: () async {
          final result = await controller.repeatStudentAttempt(session);
          if (!mounted) return;
          if (!result.started) return;
          _setCurrent(await controller.loadCurrentAttempt());
          _push(_attemptShell());
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
          : (_bootRecoveryError != null
                ? _bootRecoveryScreen()
                : (_current != null ? _attemptShell() : _homeScreen())),
    );
  }

  Widget _attemptShell() => ValueListenableBuilder<StoredAttempt?>(
    valueListenable: _attemptView,
    builder: (context, current, child) {
      final state = current?.state;
      if (current == null) return _homeScreen();
      if (state == AttemptState.recoveryPending) return _recoveryScreen();
      return Stack(
        textDirection: TextDirection.ltr,
        children: [
          Offstage(
            offstage: state == AttemptState.locked,
            child: _examScreen(),
          ),
          if (state == AttemptState.locked)
            Positioned.fill(child: _lockedScreen()),
        ],
      );
    },
  );

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
