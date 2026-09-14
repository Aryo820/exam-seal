import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
    required this.verifySupervisorPin,
    required this.registerViolation,
    required this.recordAmbiguousEvent,
    required this.onViolationLock,
    required this.endAttemptWithAuthorization,
    required this.retryRestoreSettings,
    required this.onReturnHome,
    this.formContent,
    super.key,
  });

  final ExamSession session;
  final int violationCount;
  final String? violationReason;
  final FutureOr<bool> Function(String pin) verifySupervisorPin;

  /// Mendaftarkan pelanggaran terbukti ke controller; hasilnya menentukan
  /// overlay peringatan atau penguncian.
  final Future<ViolationResultMsg> Function(String trigger) registerViolation;

  /// Mencatat event ambigu (panggilan, jaringan, fokus) tanpa counter.
  final Future<void> Function(String type) recordAmbiguousEvent;

  /// Dipanggil saat pelanggaran mencapai ambang: state locked sudah
  /// dipersist controller, UI berpindah ke layar terkunci.
  final Future<void> Function() onViolationLock;

  /// Persist state berakhir lalu pulihkan proteksi; mengembalikan status
  /// pemulihan pengaturan yang sebenarnya. Dipanggil setelah PIN pengawas
  /// diverifikasi di CompletionApprovalScreen.
  final Future<bool> Function() endAttemptWithAuthorization;

  final FutureOr<bool> Function() retryRestoreSettings;
  final VoidCallback onReturnHome;
  final Widget? formContent;

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

class _ExamScreenState extends State<ExamScreen>
    with WidgetsBindingObserver {
  WebViewController? _webViewController;
  int _progress = 0;
  String? _error;
  String? _notice;
  bool _warningAcknowledged = false;
  bool _ending = false;

  int _violationCount = 0;
  String? _violationReason;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _violationCount = widget.violationCount;
    _violationReason = widget.violationReason;
    if (widget.formContent == null) _createWebView();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Pemicu terbukti dalam matriks: aplikasi ditinggalkan saat attempt
      // aktif (pengguna berpindah aplikasi, bukan sekadar kehilangan fokus
      // sesaat karena dialog milik aplikasi).
      unawaited(_registerViolation('appLeftWhileActive'));
    } else if (state == AppLifecycleState.inactive) {
      // Dialog OS/notifikasi sesaat: event ambigu, dicatat tanpa counter.
      unawaited(widget.recordAmbiguousEvent('focusLost'));
    }
  }

  bool get _showWarning =>
      _violationCount > 0 && _violationCount < 3 && !_warningAcknowledged;

  void _createWebView() {
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (progress) {
              if (mounted) setState(() => _progress = progress);
            },
            onPageStarted: (_) {
              if (mounted) setState(() => _error = null);
            },
            onWebResourceError: (error) {
              if (error.isForMainFrame == false || !mounted) return;
              if (error.errorType == WebResourceErrorType.hostLookup) {
                // Jaringan putus: event ambigu, bukan pelanggaran.
                unawaited(widget.recordAmbiguousEvent('networkLost'));
              }
              setState(
                () => _error =
                    'Form gagal dimuat. Periksa koneksi lalu coba lagi.',
              );
            },
            onNavigationRequest: (request) {
              final target = Uri.tryParse(request.url);
              if (target != null && _allowsNavigation(target)) {
                return NavigationDecision.navigate;
              }
              if (mounted) {
                setState(
                  () => _notice = 'Tautan di luar Google Forms diblokir.',
                );
              }
              return NavigationDecision.prevent;
            },
          ),
        );
      _webViewController = controller;
      unawaited(
        controller.loadRequest(widget.session.formUrl).catchError((_) {
          if (mounted) {
            setState(
              () =>
                  _error = 'Form gagal dimuat. Periksa koneksi lalu coba lagi.',
            );
          }
        }),
      );
    } catch (_) {
      _error = 'WebView tidak tersedia pada perangkat ini.';
    }
  }

  bool _allowsNavigation(Uri target) =>
      target.scheme == 'https' && target.host == widget.session.formUrl.host;

  /// Pemicu terbukti dari matriks deteksi: aplikasi ditinggalkan saat
  /// attempt aktif (mis. siswa berpindah aplikasi). Dipanggil observer
  /// di composition root; dipercaya hanya untuk pemicu dalam matriks.
  Future<void> _registerViolation(String trigger) async {
    final result = await widget.registerViolation(trigger);
    if (!mounted) return;
    if (result.outcome == ViolationOutcome.locked) {
      await widget.onViolationLock();
      return;
    }
    setState(() {
      _violationCount = result.violationCount;
      _violationReason = result.reason;
      _warningAcknowledged = false;
    });
  }

  Future<void> _requestCompletion() async {
    if (_ending) return;
    final ended = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CompletionApprovalScreen(
          session: widget.session,
          violationCount: _violationCount,
          verifySupervisorPin: widget.verifySupervisorPin,
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
    final form = widget.formContent ?? _buildWebView();
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
                  if (_progress < 100 &&
                      _error == null &&
                      widget.formContent == null)
                    LinearProgressIndicator(value: _progress / 100),
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

  Widget _buildWebView() {
    if (_error != null) {
      return _LoadError(
        message: _error!,
        onRetry: () {
          setState(() {
            _error = null;
            _progress = 0;
          });
          final controller = _webViewController;
          if (controller == null) {
            _createWebView();
          } else {
            unawaited(controller.loadRequest(widget.session.formUrl));
          }
        },
      );
    }
    final controller = _webViewController;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return WebViewWidget(controller: controller);
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

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_outlined, size: 32),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
}
