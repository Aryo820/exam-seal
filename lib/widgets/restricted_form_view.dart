import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/form_url_policy.dart';

/// WebView bersama untuk uji guru dan ujian siswa; tidak membaca jawaban.
class RestrictedFormView extends StatefulWidget {
  const RestrictedFormView({
    required this.url,
    this.onInspected,
    this.onBlocked,
    this.onOperationalIssue,
    super.key,
  });
  final Uri url;
  final ValueChanged<bool>? onInspected;
  final VoidCallback? onBlocked;
  final ValueChanged<String>? onOperationalIssue;
  @override
  State<RestrictedFormView> createState() => _RestrictedFormViewState();
}

class _RestrictedFormViewState extends State<RestrictedFormView> {
  late final FormNavigationPolicy _policy = FormNavigationPolicy(widget.url);
  WebViewController? _controller;
  String? _error;
  String? _notice;
  bool _visible = false;
  int _progress = 0;
  int _pageVersion = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  void _fail(String message) {
    if (!mounted) return;
    _pageVersion++;
    setState(() {
      _error = message;
      _visible = false;
    });
    widget.onInspected?.call(false);
  }

  void _blocked() {
    if (!mounted) return;
    setState(
      () => _notice =
          'Navigasi tidak didukung diblokir. Tetap gunakan Form sesi ini.',
    );
    widget.onBlocked?.call();
  }

  void _reportOperationalIssue(String type) =>
      widget.onOperationalIssue?.call(type);

  void _networkInterrupted() {
    if (!mounted) return;
    if (!_visible) {
      _fail(
        'Form gagal dimuat. Periksa koneksi lalu coba lagi bersama pengawas.',
      );
      return;
    }
    setState(
      () => _notice =
          'Koneksi terputus. Halaman yang sudah terbuka tetap dipertahankan. Jangan memuat ulang sebelum pengawas memeriksa.',
    );
  }

  Future<void> _open() async {
    try {
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.white);
      await controller.addJavaScriptChannel(
        'ExamSealForm',
        onMessageReceived: (message) {
          if (message.message == 'unsupported') {
            _fail(
              'Form memerlukan upload file atau fitur di luar pilot. Hubungi pengawas.',
            );
          } else if (message.message == 'blocked') {
            _blocked();
          }
        },
      );
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null &&
                _policy.allows(uri, isMainFrame: request.isMainFrame)) {
              return NavigationDecision.navigate;
            }
            _blocked();
            if (uri?.host == 'accounts.google.com') {
              _reportOperationalIssue('formUnavailable');
              _fail('Form meminta login Google dan tidak sesuai pilot.');
            }
            return NavigationDecision.prevent;
          },
          onPageStarted: (url) {
            _pageVersion++;
            _currentUrl = url;
            final uri = Uri.tryParse(url);
            if (uri == null || !_policy.allows(uri)) {
              _fail(
                'Halaman di luar Form sesi ini diblokir. Hubungi pengawas.',
              );
              return;
            }
            if (mounted) {
              setState(() {
                _visible = false;
                _error = null;
              });
            }
            widget.onInspected?.call(false);
          },
          onPageFinished: (url) => unawaited(_inspect(url)),
          onWebResourceError: (error) {
            if (error.isForMainFrame == false) return;
            final rendererLost = error.description.toLowerCase().contains(
              'renderer process gone',
            );
            _reportOperationalIssue(
              rendererLost ? 'webViewFailed' : 'networkLost',
            );
            if (rendererLost) {
              _fail(
                'Form gagal dimuat. Periksa koneksi lalu coba lagi bersama pengawas.',
              );
            } else {
              _networkInterrupted();
            }
          },
          onHttpError: (error) {
            if (error.request?.uri.toString() != _currentUrl) return;
            _reportOperationalIssue('formUnavailable');
            _fail('Server Form mengembalikan kesalahan. Hubungi pengawas.');
          },
        ),
      );
      if (!mounted) return;
      setState(() => _controller = controller);
      await controller.loadRequest(widget.url);
    } catch (_) {
      _reportOperationalIssue('webViewFailed');
      _fail(
        'WebView tidak tersedia atau gagal disiapkan. Coba lagi bersama pengawas.',
      );
    }
  }

  String? _currentUrl;

  Future<void> _inspect(String url) async {
    final version = _pageVersion;
    final uri = Uri.tryParse(url);
    if (!mounted ||
        _error != null ||
        uri == null ||
        url != _currentUrl ||
        uri.host != 'docs.google.com') {
      return;
    }
    try {
      if (!_policy.allows(uri)) {
        _fail('Halaman Form tidak sesuai sesi.');
        return;
      }
      final raw = await _controller!.runJavaScriptReturningResult(
        formDocumentGuard(_policy.formPath!),
      );
      final result = (raw is String ? jsonDecode(raw) : raw) as Map;
      if (!mounted || version != _pageVersion) return;
      if (result['upload'] == true ||
          (result['hasForm'] != true && !uri.path.endsWith('/formResponse'))) {
        _reportOperationalIssue('formUnavailable');
        _fail(
          'Form ditutup, meminta login, atau memerlukan fitur di luar pilot. Hubungi pengawas.',
        );
        return;
      }
      _policy.observePage(uri, hasForm: result['hasForm'] == true);
      setState(() => _visible = true);
      widget.onInspected?.call(true);
    } catch (_) {
      if (version == _pageVersion) {
        _fail('Pembatasan Form belum dapat diperiksa. Hubungi pengawas.');
      }
    }
  }

  Future<void> _retry() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Muat ulang Form?'),
        content: const Text(
          'Isian dapat hilang. Minta pengawas memeriksa sebelum memuat ulang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Muat Ulang'),
          ),
        ],
      ),
    );
    if (!mounted || approved != true) return;
    final target = _policy.formPath == null
        ? widget.url
        : Uri.https('docs.google.com', '${_policy.formPath}/viewform');
    if (!_policy.allows(target)) {
      _fail('Pengulangan Form ditahan. Minta keputusan pengawas.');
      return;
    }
    if (_controller == null) {
      await _open();
      return;
    }
    try {
      await _controller!.loadRequest(target);
    } catch (_) {
      _reportOperationalIssue('networkLost');
      _fail('Form gagal dimuat ulang. Hubungi pengawas.');
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (_notice != null)
        MaterialBanner(
          content: Text(_notice!),
          actions: [
            TextButton(
              onPressed: () => setState(() => _notice = null),
              child: const Text('Tutup'),
            ),
            TextButton(onPressed: _retry, child: const Text('Muat Ulang')),
          ],
        ),
      if (_progress < 100 && _error == null)
        LinearProgressIndicator(value: _progress / 100),
      Expanded(
        child: Stack(
          children: [
            if (_controller != null)
              Offstage(
                offstage: !_visible,
                child: WebViewWidget(controller: _controller!),
              ),
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      OutlinedButton(
                        onPressed: _retry,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

/// Tidak mengirim isi soal/jawaban ke Dart; hanya status struktur dan blokir.
String formDocumentGuard(String formPath) =>
    '''
(() => {
  const root = ${jsonEncode(formPath)};
  const report = value => ExamSealForm.postMessage(value);
  const allowed = value => {
    try {
      const u = new URL(value, location.href);
      return u.protocol === 'https:' && u.host === 'docs.google.com' &&
        !u.username && !u.password && !u.hash &&
        [root + '/viewform', root + '/formResponse'].includes(u.pathname) &&
        ![...u.searchParams.keys()].some(k => k.toLowerCase().startsWith('edit'));
    } catch (_) { return false; }
  };
  if (!window.__examSealGuard) {
    window.__examSealGuard = true;
    window.open = () => { report('blocked'); return null; };
    document.addEventListener('click', event => {
      const a = event.target.closest && event.target.closest('a');
      if (a && (a.target && a.target !== '_self' || a.hasAttribute('download') || !allowed(a.href))) {
        event.preventDefault(); event.stopImmediatePropagation(); report('blocked');
      }
    }, true);
    const validForm = form => allowed(form.action) && (!form.target || form.target === '_self') && !form.querySelector('input[type=file]');
    document.addEventListener('submit', event => {
      if (!validForm(event.target)) { event.preventDefault(); event.stopImmediatePropagation(); report('unsupported'); }
    }, true);
    const submit = HTMLFormElement.prototype.submit;
    HTMLFormElement.prototype.submit = function() {
      if (validForm(this)) return submit.call(this);
      report('unsupported');
    };
    new MutationObserver(() => {
      if (document.querySelector('input[type=file]')) report('unsupported');
    }).observe(document.documentElement, {childList:true, subtree:true});
  }
  const hasForm = [...document.forms].some(form => allowed(form.action));
  return {hasForm:hasForm, upload:!!document.querySelector('input[type=file]')};
})();
''';
