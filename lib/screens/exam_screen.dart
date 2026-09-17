import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/restricted_form_view.dart';

import '../models/exam_sessions.dart';
import '../services/attempt_state_machine.dart';
import 'completion_approval_screen.dart';
import 'ended_screen.dart';

/// Stitch S04 - Ujian Aktif.
class ExamScreen extends StatefulWidget {
  const ExamScreen({
    required this.session,
    required this.violationCount,
    required this.violationReason,
    required this.registerViolation,
    required this.recordAmbiguousEvent,
    required this.onViolationLock,
    required this.endAttemptWithAuthorization,
    required this.retryRestoreSettings,
    required this.onReturnHome,
    this.formContent,
    this.protectionNotice,
    this.attemptActive = true,
    this.clock,
    this.departureGrace = const Duration(seconds: 2),
    this.onWarningAlert,
    this.userExitSignal,
    this.isScreenPinned,
    this.registerSevereViolation,
    super.key,
  });

  final ExamSession session;
  final int violationCount;
  final String? violationReason;

  /// Benar hanya bila attempt yang ditampilkan masih `active`. Induk
  /// ([ExamApp]) wajib meneruskan false saat state sudah locked/pemulihan:
  /// layar ini tetap mounted di balik lapisan terkunci (Offstage) sehingga
  /// tanpa flag ini lifecycle bisa menambah counter yang sudah terkunci.
  final bool attemptActive;

  /// Jam untuk mengukur durasi kepergian (matriks FR05). Diisi test agar
  /// deterministik; produksi memakai [DateTime.now].
  final DateTime Function()? clock;

  /// Ambang matriks v1 (FR05/Q03): kepergian yang lebih singkat dari ini
  /// hanya dicatat ambigu ("kehilangan fokus saja bukan bukti").
  final Duration departureGrace;

  /// Dipanggil (best-effort, tanpa blokir UI) setiap kali pelanggaran
  /// terhitung baru dipersist — untuk getar + bunyi peringatan native
  /// (FR10). Opsional agar widget tetap bisa dipakai tanpa bridge native
  /// di test. Induk mengisi dengan pemanggilan WarningManager.
  final Future<void> Function()? onWarningAlert;

  /// Penghitung sinyal keluar-disengaja native (`userInitiatedExit` dari
  /// onUserLeaveHint: tombol Home/Recent). Induk menaikkan nilainya setiap
  /// ada sinyal saat attempt aktif. Kenaikan yang terlihat di sini menandai
  /// kepergian berjalan sebagai "disengaja" sehingga dihitung tanpa
  /// menunggu ambang [departureGrace] (matriks v2, PRD FR05/Q03).
  /// Opsional; null berarti tidak ada konfirmasi native.
  final ValueListenable<int>? userExitSignal;

  /// Tanya status screen pin native. Dipakai di [_handleReturn]: bila
  /// attempt aktif tetapi pin sudah lepas (unpin paksa), kepergian dihitung
  /// langsung tanpa grace (matriks v3) karena ini aksi sadar meloloskan
  /// diri. Null = tidak ada pengecekan (perilaku lama, untuk test/widget
  /// non-Android). Kegagalan query dianggap ter-pin (fail-open) agar
  /// gangguan bridge tidak menjadi vonis.
  final Future<bool> Function()? isScreenPinned;

  /// Mendaftarkan pelanggaran terbukti ke controller; hasilnya menentukan
  /// overlay peringatan atau penguncian.
  final Future<ViolationResultMsg> Function(String trigger) registerViolation;

  /// Mendaftarkan pelanggaran BERAT (unpin paksa): langsung mengunci dari
  /// hitungan berapa pun (matriks v4). Opsional agar widget tetap bisa
  /// dipakai tanpa jalur berat; bila null, unpin mengikuti jalur hitungan
  /// normal (tetap dihitung, tanpa grace).
  final Future<ViolationResultMsg> Function(String trigger)?
  registerSevereViolation;

  /// Mencatat event ambigu (panggilan, jaringan, fokus) tanpa counter.
  final Future<void> Function(String type) recordAmbiguousEvent;

  /// Dipanggil saat pelanggaran mencapai ambang: state locked sudah
  /// dipersist controller, UI berpindah ke layar terkunci.
  final Future<void> Function() onViolationLock;

  /// Persist state berakhir lalu pulihkan proteksi; mengembalikan status
  /// pemulihan pengaturan yang sebenarnya. Dipanggil setelah konfirmasi
  /// pengawas di CompletionApprovalScreen.
  final Future<bool> Function() endAttemptWithAuthorization;

  final FutureOr<bool> Function() retryRestoreSettings;
  final VoidCallback onReturnHome;
  final Widget? formContent;
  final ValueListenable<String?>? protectionNotice;

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

/// Pesan hasil pelanggaran dari controller untuk UI.
class ViolationResultMsg {
  const ViolationResultMsg({
    required this.outcome,
    required this.violationCount,
    required this.reason,
  });
  final ViolationOutcome outcome;
  final int violationCount;
  final String reason;
}

class _ExamScreenState extends State<ExamScreen> with WidgetsBindingObserver {
  /// Pemicu terhitung matriks v1 (PRD FR05/Q03): satu-satunya pemicu yang
  /// boleh menambah counter. Lifecycle hanya boleh menembakkannya lewat
  /// [_handleReturn], tidak langsung.
  static const _countedTrigger = 'appLeftWhileActive';

  /// Pemicu pelanggaran berat matriks v4: unpin paksa kunci layar.
  static const _severeTrigger = 'screenUnpinned';

  String? _notice;
  bool _warningAcknowledged = false;
  bool _ending = false;

  int _violationCount = 0;
  String? _violationReason;

  /// Pelacakan satu kepergian (FR05: satu aksi = satu hitungan).
  /// [_awaySince] null berarti aplikasi dianggap di depan.
  DateTime? _awaySince;
  bool _departureReported = false;
  bool _reporting = false;

  /// True bila kepergian berjalan dikonfirmasi disengaja oleh sinyal
  /// native (onUserLeaveHint). Pengecekan dilakukan di dua titik
  /// (saat pergi dan saat kembali) karena urutan tiba sinyal native itu
  /// asinkron dan bisa mendahului maupun menyusul callback lifecycle.
  bool _userExitConfirmed = false;
  int _lastSeenExitCount = 0;

  DateTime _now() => widget.clock?.call() ?? DateTime.now();

  /// Sinkronkan penanda keluar-disengaja dari induk. Dipanggil setiap
  /// ada perubahan lifecycle agar urutan tiba sinyal tidak penting.
  void _syncUserExitSignal() {
    final count = widget.userExitSignal?.value ?? _lastSeenExitCount;
    if (count != _lastSeenExitCount) {
      _lastSeenExitCount = count;
      _userExitConfirmed = true;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _violationCount = widget.violationCount;
    _violationReason = widget.violationReason;
  }

  @override
  void didUpdateWidget(covariant ExamScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.violationCount != oldWidget.violationCount ||
        widget.violationReason != oldWidget.violationReason) {
      _violationCount = widget.violationCount;
      _violationReason = widget.violationReason;
      _warningAcknowledged = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      // Selalu catat ambigu dulu (FR05): sinyal ini saja bukan bukti.
      unawaited(widget.recordAmbiguousEvent('focusLost'));
      // Tandai awal kepergian sekali saja; callback beruntun dari satu
      // kepergian yang sama tidak boleh membuka hitungan baru. Flag
      // direset di sini sehingga kepergian berikutnya bisa dihitung lagi.
      if (_awaySince == null) {
        _awaySince = _now();
        _departureReported = false;
      }
      _syncUserExitSignal();
    } else if (state == AppLifecycleState.resumed) {
      _syncUserExitSignal();
      unawaited(_handleReturn());
    }
  }

  /// Evaluasi saat kembali ke aplikasi (matriks v2/v3/v4, PRD FR05/Q03).
  /// Dihitung bila attempt masih active, kepergian belum dilaporkan, dan:
  /// - pin layar sudah lepas paksa → pelanggaran BERAT, langsung kunci
  ///   (matriks v4, tanpa ambang), ATAU
  /// - kepergian dikonfirmasi disengaja sinyal native (tanpa ambang), ATAU
  /// - durasi pergi mencapai [ExamScreen.departureGrace].
  /// Kepergian singkat tanpa konfirmasi dan pin utuh = tetap ambigu saja.
  Future<void> _handleReturn() async {
    final awaySince = _awaySince;
    _awaySince = null;
    final confirmedExit = _userExitConfirmed;
    _userExitConfirmed = false;
    if (awaySince == null ||
        _departureReported ||
        _reporting ||
        _ending ||
        !widget.attemptActive ||
        _violationCount >= AttemptStateMachine.initialViolationLimit) {
      return;
    }
    final unpinned = await _isUnpinned();
    if (!confirmedExit &&
        !unpinned &&
        _now().difference(awaySince) < widget.departureGrace) {
      return;
    }
    _reporting = true;
    try {
      final ViolationResultMsg result;
      if (unpinned && widget.registerSevereViolation != null) {
        result = await widget.registerSevereViolation!(_severeTrigger);
      } else {
        result = await widget.registerViolation(_countedTrigger);
      }
      _departureReported = true;
      // Bunyikan peringatan native untuk setiap hitungan baru (FR10),
      // tanpa memblokir transisi UI dan tanpa menggagalkan apa pun bila
      // perangkat tidak mendukungnya.
      unawaited(_alertWarning());
      if (!mounted) return;
      if (result.outcome == ViolationOutcome.locked) {
        // State locked sudah dipersist controller; serahkan ke induk agar
        // layar terkunci tampil. Dialog yang sedang terbuka tidak boleh
        // membatalkannya (tabel state PRD).
        await widget.onViolationLock();
      } else {
        setState(() {
          _violationCount = result.violationCount;
          _violationReason = result.reason;
          _warningAcknowledged = false;
        });
      }
    } on StateError {
      // Balapan dengan transisi induk (mis. attempt sudah berakhir/
      // terkunci lebih dulu): bukan pelanggaran baru, abaikan.
      _departureReported = true;
    } finally {
      _reporting = false;
    }
  }

  bool get _showWarning =>
      _violationCount > 0 && _violationCount < 3 && !_warningAcknowledged;

  /// True bila pin layar dipastikan sudah lepas (matriks v3). Fail-open:
  /// tanpa callback atau bila query gagal, dianggap pin masih utuh agar
  /// gangguan bridge tidak berubah menjadi vonis pelanggaran.
  Future<bool> _isUnpinned() async {
    final query = widget.isScreenPinned;
    if (query == null) return false;
    try {
      return !await query();
    } catch (_) {
      return false;
    }
  }

  /// Pemicu peringatan native best-effort. Tidak pernah melempar ke
  /// pemanggil; kegagalan perangkat berarti peringatan visual saja yang
  /// tampil (FR10: visual selalu tersedia).
  Future<void> _alertWarning() async {
    try {
      await widget.onWarningAlert?.call();
    } catch (_) {
      // Abaikan: peringatan visual tetap menjadi jalur utama.
    }
  }

  Future<void> _requestCompletion() async {
    if (_ending) return;
    final ended = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CompletionApprovalScreen(
          session: widget.session,
          violationCount: _violationCount,
        ),
      ),
    );
    if (ended != true || !mounted) return;

    setState(() => _ending = true);
    try {
      final settingsRestored = await widget.endAttemptWithAuthorization();
      if (!mounted) return;
      setState(() => _ending = false);
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => EndedScreen(
            session: widget.session,
            endReason:
                'Diakhiri pengawas setelah pemeriksaan pengiriman jawaban.',
            settingsRestored: settingsRestored,
            retryRestoreSettings: widget.retryRestoreSettings,
            onReturnHome: widget.onReturnHome,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _ending = false;
          _notice =
              'Sesi belum dapat diakhiri. Status ujian tetap aktif. Coba lagi bersama pengawas.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final form =
        widget.formContent ??
        RestrictedFormView(
          url: widget.session.formUrl,
          onOperationalIssue: (event) =>
              unawaited(widget.recordAmbiguousEvent(event.type)),
        );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_showWarning) unawaited(_requestCompletion());
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _Header(
                    session: widget.session,
                    violationCount: _violationCount,
                  ),
                  if (_notice != null)
                    MaterialBanner(
                      content: Text(_notice!),
                      actions: [
                        TextButton(
                          onPressed: () => setState(() => _notice = null),
                          child: const Text('Tutup'),
                        ),
                      ],
                    ),
                  if (widget.protectionNotice != null)
                    ValueListenableBuilder<String?>(
                      valueListenable: widget.protectionNotice!,
                      builder: (_, notice, _) => notice == null
                          ? const SizedBox.shrink()
                          : MaterialBanner(
                              content: Text(notice),
                              actions: [
                                TextButton(
                                  onPressed: _requestCompletion,
                                  child: const Text('Pengawas'),
                                ),
                              ],
                            ),
                    ),
                  Expanded(child: form),
                  _CompletionAction(
                    onPressed: _ending ? null : _requestCompletion,
                    ending: _ending,
                  ),
                ],
              ),
              if (_showWarning)
                Positioned.fill(
                  child: _ViolationWarning(
                    count: _violationCount,
                    reason: _violationReason ?? 'Peringatan pelanggaran',
                    onAcknowledged: () {
                      setState(() => _warningAcknowledged = true);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.session, required this.violationCount});

  final ExamSession session;
  final int violationCount;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 10),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xFF171717), width: 2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'ExamSeal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              'Pelanggaran: $violationCount',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          session.examName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          session.sessionCode,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    ),
  );
}

class _ViolationWarning extends StatelessWidget {
  const _ViolationWarning({
    required this.count,
    required this.reason,
    required this.onAcknowledged,
  });

  final int count;
  final String reason;
  final VoidCallback onAcknowledged;

  @override
  Widget build(BuildContext context) {
    final lastWarning = count == 2;
    return ColoredBox(
      color: const Color(0x99000000),
      child: Center(
        child: Semantics(
          container: true,
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: lastWarning ? 'Peringatan terakhir' : 'Peringatan pertama',
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFF8A4B08)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_outlined,
                      color: Color(0xFF8A4B08),
                      semanticLabel: 'Peringatan',
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        lastWarning
                            ? 'Peringatan terakhir'
                            : 'Peringatan pertama',
                        style: const TextStyle(
                          color: Color(0xFF8A4B08),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  reason,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Kejadian ini dihitung sebagai pelanggaran.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Color(0xFF595959),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFFF4DF),
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    lastWarning
                        ? 'Jika terjadi satu pelanggaran lagi, ujian akan dikunci dan pengawas harus membantu.'
                        : 'Pelanggaran berikutnya akan menampilkan peringatan terakhir. Pelanggaran ketiga mengunci ujian.',
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Halaman ujian tetap terbuka. Jawaban dikelola oleh Google Forms.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Color(0xFF595959),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  autofocus: true,
                  onPressed: onAcknowledged,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  child: const Text('Kembali ke Ujian'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletionAction extends StatelessWidget {
  const _CompletionAction({required this.onPressed, required this.ending});

  final VoidCallback? onPressed;
  final bool ending;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Color(0xFFD6D6D6))),
    ),
    child: Column(
      children: [
        OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            foregroundColor: const Color(0xFF171717),
            side: const BorderSide(color: Color(0xFF171717)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          child: Text(
            ending ? 'Mengakhiri Sesi...' : 'Minta Persetujuan Selesai',
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Setelah mengirim jawaban, tetap di tempat dan minta pengawas memeriksa.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: Color(0xFF595959),
          ),
        ),
      ],
    ),
  );
}
