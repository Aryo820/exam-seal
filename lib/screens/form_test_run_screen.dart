import 'dart:async';

import 'package:flutter/material.dart';

import '../models/exam_sessions.dart';
import '../widgets/restricted_form_view.dart';
import 'supervisor_pin_screen.dart';

class FormTestRunScreen extends StatefulWidget {
  const FormTestRunScreen({
    required this.session,
    required this.verifyPin,
    required this.recordBlocked,
    super.key,
  });

  final ExamSession session;
  final Future<bool> Function(String) verifyPin;
  final Future<void> Function() recordBlocked;

  @override
  State<FormTestRunScreen> createState() => _FormTestRunScreenState();
}

class _FormTestRunScreenState extends State<FormTestRunScreen> {
  bool _inspected = false;
  bool _closing = false;
  bool _authorized = false;
  bool _storageFailed = false;
  int _blockedCount = 0;
  Future<void> _pendingWrites = Future.value();

  void _recordBlocked() {
    setState(() => _blockedCount++);
    _pendingWrites = _pendingWrites
        .then((_) => widget.recordBlocked())
        .catchError((Object _) {
          if (mounted) setState(() => _storageFailed = true);
        });
  }

  Future<void> _close() async {
    if (_closing) return;
    setState(() => _closing = true);
    final approved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SupervisorPinScreen(
          verifyPin: widget.verifyPin,
          heading: 'Tutup uji Form',
          description:
              'Masukkan PIN pengawas untuk kembali ke pemeriksaan manual. Menutup uji tidak membuktikan jawaban terkirim.',
        ),
      ),
    );
    await _pendingWrites;
    if (!mounted) return;
    if (approved == true) {
      setState(() => _authorized = true);
      // PopScope harus dibangun ulang sebelum rute ditutup.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(_inspected && !_storageFailed);
      });
    } else {
      setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _authorized,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_close());
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Uji Form'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _storageFailed
                    ? 'Catatan uji gagal disimpan. Tutup dan ulangi uji sebelum membagikan QR.'
                    : 'Kirim jawaban percobaan, lalu periksa respons sebagai guru. Navigasi diblokir: $_blockedCount.',
              ),
            ),
            Expanded(
              child: RestrictedFormView(
                url: widget.session.formUrl,
                onInspected: (value) => _inspected = value,
                onBlocked: _recordBlocked,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(
                onPressed: _closing ? null : _close,
                child: const Text('Tutup Uji dengan PIN'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
