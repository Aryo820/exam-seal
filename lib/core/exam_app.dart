import 'dart:async';

import 'package:flutter/material.dart';

import '../models/exam_sessions.dart';
import '../services/attempt_state_machine.dart';
import '../services/exam_session_controller.dart';
import '../services/exam_protection.dart';
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
  final _protectionNotice = ValueNotifier<String?>(null);
  final _attemptView = ValueNotifier<StoredAttempt?>(null);

  StoredAttempt? _current;
  bool _booting = true;
  bool _retryingRecovery = false;
  String? _bootRecoveryError;

  /// Langganan sinyal ExamGuard native, satu untuk seumur aplikasi.
  /// Handler mengabaikan event bila tidak ada attempt yang menahan,
  /// sehingga tidak ada kebocoran perilaku di luar ujian.
  StreamSubscription<GuardEvent>? _guardSubscription;

  /// Penghitung sinyal keluar-disengaja native (onUserLeaveHint).
  /// Diteruskan ke ExamScreen sebagai satu-satunya pintu hitung, sehingga
  /// satu kepergian tidak pernah dihitung dua kali (native + Dart).
  final _nativeExitSignal = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscribeGuardEvents();
    unawaited(_boot());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_guardSubscription?.cancel());
    _nativeExitSignal.dispose();
    _protectionNotice.dispose();
    _attemptView.dispose();
    super.dispose();
  }

  /// Dengarkan sinyal mentah ExamGuard. Setiap event HANYA dicatat
  /// sebagai event ambigu (FR05) — tidak pernah menambah counter.
  /// Penghitung tetap matriks Flutter di ExamScreen agar satu kepergian
  /// tidak dihitung dua kali (native + Dart).
  void _subscribeGuardEvents() {
    final protection = controller.protection;
    if (protection is! ExamProtection) return;
    _guardSubscription = protection.guardEvents().listen(
      (event) => unawaited(_recordNativeSignal(event)),
      onError: (_) {},
    );
  }

  Future<void> _recordNativeSignal(GuardEvent event) async {
    final current = _current;
    if (current == null ||
        (current.state != AttemptState.active &&
            current.state != AttemptState.locked)) {
      return;
    }
    try {
      await controller.recordAmbiguousEvent('native:${event.type}');
    } catch (_) {
      // Pencatatan ambigu tidak boleh mengganggu ujian berjalan.
    }
    // Sinyal keluar-disengaja (tombol Home/Recent, bukan panggilan atau
    // dialog) diteruskan sebagai angka ke ExamScreen. Titik hitung tetap
    // satu (di _handleReturn) sehingga tidak ada hitungan ganda.
    if (event.type == 'userInitiatedExit' &&
        current.state == AttemptState.active) {
      _nativeExitSignal.value++;
    }
  }

  /// Boot: retensi → pemulihan proteksi tertunda → attempt tersimpan →
  /// rute yang benar (FR12). Restart saat attempt aktif → recoveryPending
  /// tanpa pelanggaran baru, bukan langsung membuka Google Forms.
  Future<void> _boot() async {
    try {
      await controller.runRetention();
    } on StorageFailure {
      _blockBoot(
        'Data retensi tidak dapat dibaca. Minta pengawas memeriksa penyimpanan sebelum ujian dilanjutkan.',
      );
      return;
    }
    var restored = false;
    try {
      restored = await controller.resolvePendingRestores();
    } catch (_) {
      restored = false;
    }
    if (!restored) {
      _blockBoot(
        'Pemulihan proteksi perangkat diperlukan. Minta pengawas memeriksa perangkat ini sebelum ujian dilanjutkan.',
      );
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
      _blockBoot(
        'Data percobaan tidak dapat dibaca. Minta pengawas memeriksa penyimpanan sebelum ujian dilanjutkan.',
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _booting = false;
      _bootRecoveryError = null;
    });
  }

  void _blockBoot(String message) {
    if (!mounted) return;
    setState(() {
      _booting = false;
      _bootRecoveryError = message;
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
    onResumeStudentSession: _resumeStoredAttempt,
    onOpenTeacherMode: () => unawaited(_openTeacherMode()),
    onOpenStudentScan: () => _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(builder: (_) => _scanScreen()),
    ),
  );

  Future<void> _openTeacherMode() async {
    await _navigatorKey.currentState?.push<void>(
      MaterialPageRoute(
        builder: (_) => TeacherSessionsScreen(
          loadSessions: controller.listTeacherSessions,
          canCreateSession: _current == null,
          canDeleteSession: _current == null,
          onCreateSession: _openCreateSession,
          onShowQr: _openSessionQr,
          onDeleteSession: (session) async {
            final result = await controller.deleteTeacherSession(session);
            return result.deleted ? null : result.error;
          },
        ),
      ),
    );
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
              'QR belum dapat dibuka. Periksa penyimpanan lalu coba lagi.',
            ),
          ),
        );
      }
    }
  }

  Widget _sessionQrScreen(ExamSession session) =>
      SessionQrScreen(session: session);

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
      case ScanImportRoute.endedNeedsConfirmation:
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
      attemptActive: current.state == AttemptState.active,
      userExitSignal: _nativeExitSignal,
      isScreenPinned: _queryScreenPinned,
      registerViolation: (trigger) async {
        final result = await controller.registerViolation(trigger);
        return ViolationResultMsg(
          outcome: result.outcome,
          violationCount: result.violationCount,
          reason: result.reason,
        );
      },
      registerSevereViolation: (trigger) async {
        final result = await controller.registerSevereViolation(trigger);
        return ViolationResultMsg(
          outcome: result.outcome,
          violationCount: result.violationCount,
          reason: result.reason,
        );
      },
      recordAmbiguousEvent: (type) => controller.recordAmbiguousEvent(type),
      onViolationLock: _onViolationLock,
      onWarningAlert: _playNativeWarningAlert,
      endAttemptWithAuthorization: () => controller.finishCurrentAttempt(
        reason: 'Diakhiri pengawas setelah pemeriksaan pengiriman jawaban.',
      ),
      retryRestoreSettings: controller.retryRestoreSettings,
      onReturnHome: _goHome,
    );
  }

  /// Tanya status pin ke bridge native. Fail-open (true) untuk bridge
  /// non-native (test/widget) dan saat query gagal: gangguan bridge tidak
  /// boleh berubah menjadi vonis unpin.
  Future<bool> _queryScreenPinned() async {
    final protection = controller.protection;
    if (protection is! ExamProtection) return true;
    try {
      return await protection.isScreenPinned();
    } catch (_) {
      return true;
    }
  }

  /// Peringatan native per hitungan baru (FR10: getar + bunyi singkat,
  /// masing-masing maksimal tiga detik). Best-effort penuh: perangkat yang
  /// tidak mendukung tetap menampilkan peringatan visual; kegagalan tidak
  /// pernah melempar ke UI.
  Future<void> _playNativeWarningAlert() async {
    final protection = controller.protection;
    if (protection is! ExamProtection) return;
    try {
      await protection.vibrateWarning(durationMs: 3000);
    } catch (_) {
      // Abaikan: lanjut ke bunyi, lalu selesai diam-diam.
    }
    try {
      await protection.playWarningSound(durationMs: ExamProtection.maxAlertMs);
    } catch (_) {
      // Abaikan: visual tetap menjadi jalur utama (FR10).
    }
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
      onContinueExam: _continueProtectedAttempt,
      onEndExam: () async {
        final restored = await controller.finishCurrentAttempt(
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
      onContinueExam: _continueProtectedAttempt,
      onEndExam: () async {
        final restored = await controller.finishCurrentAttempt(
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
    if (!await controller.continueLockedAttempt()) {
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
        onRepeatApproved: () async {
          final result = await controller.repeatStudentAttempt(session);
          if (!mounted) return;
          if (!result.started) return;
          _setCurrent(await controller.loadCurrentAttempt());
          _push(_attemptShell());
        },
      );

  ExamSession _fallbackSession() => ExamSession(
    schemaVersion: 3,
    sessionId: 'unknown',
    sessionCode: '—',
    examName: 'Sesi ujian',
    formUrl: Uri.parse('https://forms.gle/example'),
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
