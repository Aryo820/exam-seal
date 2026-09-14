import 'dart:async';

import 'package:flutter/material.dart';

import '../models/exam_sessions.dart';

/// Stitch T03 - Uji Form sebelum QR dibagikan.
class FormTestScreen extends StatefulWidget {
  const FormTestScreen({
    required this.session,
    this.runFormTest,
    this.confirmFormReady,
    this.onAccessPin,
    super.key,
  });

  final ExamSession session;
  final FutureOr<bool> Function()? runFormTest;
  final FutureOr<bool> Function()? confirmFormReady;
  final VoidCallback? onAccessPin;

  @override
  State<FormTestScreen> createState() => _FormTestScreenState();
}

class _FormTestScreenState extends State<FormTestScreen> {
  static const _checks = [
    'Form dapat dibuka tanpa meminta login Google.',
    'Tidak ada pertanyaan upload file atau layanan luar.',
    "Setelah submit, tidak ada tautan 'Edit tanggapan Anda'.",
    "Setelah submit, tidak ada tautan 'Kirim tanggapan lain'.",
    'Respons uji masuk ke tab respons atau spreadsheet milik guru.',
  ];

  final _checked = List<bool>.filled(_checks.length, false);
  bool _testCompleted = false;
  bool _declared = false;
  bool _busy = false;
  String? _error;

  bool get _canConfirm =>
      _testCompleted && _checked.every((value) => value) && _declared && !_busy;

  Future<void> _runTest() async {
    if (_busy) return;
    final runFormTest = widget.runFormTest;
    if (runFormTest == null) {
      setState(
        () => _error =
            'Mode uji Form belum tersedia. Status kesiapan tidak diubah.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _testCompleted = false;
      _declared = false;
      _checked.fillRange(0, _checked.length, false);
    });
    try {
      final completed = await runFormTest();
      if (mounted) setState(() => _testCompleted = completed);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Uji Form tidak dapat dibuka. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    final confirmFormReady = widget.confirmFormReady;
    if (confirmFormReady == null) {
      setState(
        () => _error =
            'Status kesiapan belum dapat disimpan. QR belum diterbitkan.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await confirmFormReady();
      if (!mounted) return;
      if (saved) {
        setState(() => _busy = false);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(
          () => _error =
              'Status kesiapan belum dapat disimpan. QR belum diterbitkan.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Status kesiapan belum dapat disimpan. QR belum diterbitkan.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: const Text(
          'Uji Form',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFD6D6D6)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.session.examName,
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kode sesi: ${widget.session.sessionCode}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF595959)),
              ),
              const SizedBox(height: 20),
              const Divider(height: 2, thickness: 2, color: Color(0xFF171717)),
              const SizedBox(height: 24),
              const Text(
                'Uji kelayakan Google Forms',
                style: TextStyle(
                  fontSize: 28,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Validasi URL hanya memeriksa format. Jalankan satu pengerjaan penuh sampai submit sebelum QR dibagikan.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),
              _Step(
                number: '01',
                title: 'Jalankan uji Form penuh',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Isi contoh jawaban melalui ExamSeal dan tekan tombol Kirim yang sebenarnya.',
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _busy ? null : widget.onAccessPin,
                      child: const Text('Akses PIN Pengawas'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _busy ? null : _runTest,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 20),
                      label: Text(
                        _busy ? 'Membuka Uji Form...' : 'Buka Uji Form',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _testCompleted
                          ? 'Uji Form telah ditutup. Lengkapi pemeriksaan manual di bawah.'
                          : 'Keluar dari mode uji tetap mengikuti prosedur PIN pengawas.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: _testCompleted
                            ? const Color(0xFF216E4E)
                            : const Color(0xFF595959),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Step(
                number: '02',
                title: 'Daftar periksa manual',
                child: Column(
                  children: [
                    for (var index = 0; index < _checks.length; index++) ...[
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          _checks[index],
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                        value: _checked[index],
                        onChanged: _testCompleted
                            ? (value) => setState(
                                () => _checked[index] = value ?? false,
                              )
                            : null,
                      ),
                      if (index != _checks.length - 1)
                        const Divider(height: 1, color: Color(0xFFD6D6D6)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F3F3),
                  border: Border.all(color: const Color(0xFF171717), width: 2),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'Saya telah menguji Form sampai submit dan memeriksa seluruh ketentuan di atas. Form tidak akan diubah selama ujian.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text(
                      'Ini adalah konfirmasi manual guru, bukan pemeriksaan otomatis ExamSeal.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                    value: _declared,
                    onChanged: _testCompleted
                        ? (value) => setState(() => _declared = value ?? false)
                        : null,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFB42318),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _canConfirm ? _confirm : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                icon: const Icon(Icons.qr_code_2, size: 20),
                label: const Text(
                  'Konfirmasi Form Siap',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'QR baru dapat ditampilkan setelah konfirmasi ini berhasil disimpan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFF595959),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.child});

  final String number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFD6D6D6)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'LANGKAH $number',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF595959),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}
