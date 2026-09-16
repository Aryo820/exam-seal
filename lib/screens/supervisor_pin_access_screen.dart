import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/exam_sessions.dart';
import '../services/local_auth_gate.dart';

/// Stitch T05 - Akses PIN setelah autentikasi kunci layar perangkat guru.
class SupervisorPinAccessScreen extends StatefulWidget {
  const SupervisorPinAccessScreen({
    required this.session,
    this.authenticateDevice,
    this.readPin,
    super.key,
  });

  final ExamSession session;
  final FutureOr<bool> Function()? authenticateDevice;
  final FutureOr<String?> Function()? readPin;

  @override
  State<SupervisorPinAccessScreen> createState() =>
      _SupervisorPinAccessScreenState();
}

class _SupervisorPinAccessScreenState extends State<SupervisorPinAccessScreen>
    with WidgetsBindingObserver {
  String? _pin;
  String? _error;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _pin != null && mounted) {
      setState(() => _pin = null);
    }
  }

  Future<void> _authenticate() async {
    final authenticate = widget.authenticateDevice;
    final readPin = widget.readPin;
    if (_authenticating || authenticate == null || readPin == null) {
      setState(
        () => _error =
            'Autentikasi perangkat dan penyimpanan PIN belum tersedia.',
      );
      return;
    }

    setState(() {
      _authenticating = true;
      _error = null;
    });
    try {
      if (!await authenticate()) {
        if (mounted) {
          setState(
            () => _error =
                'Autentikasi dibatalkan atau tidak cocok. PIN tetap dikunci.',
          );
        }
        return;
      }
      if (!mounted) return;
      final pin = await readPin();
      if (!RegExp(r'^\d{5}$').hasMatch(pin ?? '')) {
        throw const FormatException('Invalid supervisor PIN');
      }
      if (mounted) setState(() => _pin = pin);
    } on DeviceAuthenticationUnavailable {
      if (mounted) {
        setState(
          () => _error =
              'Kunci layar HP belum siap. Atur PIN, pola, atau sandi layar di Setelan, lalu coba lagi.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'PIN tidak dapat dibuka. Periksa penyimpanan sesi lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  Future<void> _copyPin() async {
    final pin = _pin;
    if (pin == null) return;
    await Clipboard.setData(ClipboardData(text: pin));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN disalin. Simpan di tempat aman.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Akses PIN Pengawas',
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
            const Text(
              'EXAMSEAL / MODE GURU - AREA PRIVAT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Color(0xFF595959),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'PIN pengawas sesi',
              style: TextStyle(
                fontSize: 28,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gunakan hanya untuk intervensi langsung oleh pengawas.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF595959),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              color: const Color(0xFFF3F3F3),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _Metadata(
                      label: 'NAMA UJIAN',
                      value: widget.session.examName,
                    ),
                  ),
                  const SizedBox(width: 16),
                  _Metadata(
                    label: 'KODE SESI',
                    value: widget.session.sessionCode,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 2, thickness: 2, color: Color(0xFF171717)),
            if (_error != null) ...[
              const SizedBox(height: 20),
              Semantics(
                liveRegion: true,
                child: Container(
                  color: const Color(0xFFFEF3F2),
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFB42318),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              color: const Color(0xFFF3F3F3),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'KREDENSIAL SESI',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Color(0xFF595959),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _pin == null ? '•••••' : _pin!.split('').join(' '),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_pin == null)
                    FilledButton.icon(
                      onPressed: _authenticating ? null : _authenticate,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      icon: _authenticating
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.fingerprint, size: 22),
                      label: Text(
                        _authenticating
                            ? 'Memeriksa...'
                            : 'Autentikasi Kunci Layar HP',
                      ),
                    )
                  else ...[
                    FilledButton.icon(
                      onPressed: _copyPin,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      icon: const Icon(Icons.copy_outlined, size: 20),
                      label: const Text('Salin PIN'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _pin = null),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        foregroundColor: const Color(0xFF171717),
                        side: const BorderSide(color: Color(0xFF171717)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      icon: const Icon(Icons.lock_outline, size: 20),
                      label: const Text('Kunci Kembali PIN'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              color: const Color(0xFFFFF4DF),
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Jangan tunjukkan PIN kepada siswa. Pengawas memasukkannya langsung saat mendatangi meja siswa.',
                style: TextStyle(
                  color: Color(0xFF8A4B08),
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFF595959)),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ],
  );
}
