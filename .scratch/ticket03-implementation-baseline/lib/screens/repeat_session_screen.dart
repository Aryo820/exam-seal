import 'dart:async';

import 'package:flutter/material.dart';

import '../models/exam_sessions.dart';
import 'supervisor_pin_screen.dart';

/// Stitch S11 - Pengulangan sesi yang telah berakhir.
class RepeatSessionScreen extends StatefulWidget {
  const RepeatSessionScreen({
    required this.session,
    required this.previousViolationCount,
    required this.verifySupervisorPin,
    required this.onRepeatApproved,
    super.key,
  }) : assert(previousViolationCount >= 0);

  final ExamSession session;
  final int previousViolationCount;
  final FutureOr<bool> Function(String pin) verifySupervisorPin;

  /// Dipanggil setelah PIN benar dan pengawas mengonfirmasi attempt baru;
  /// composition root memulai attempt (readiness dicek ulang).
  final Future<void> Function() onRepeatApproved;

  @override
  State<RepeatSessionScreen> createState() => _RepeatSessionScreenState();
}

class _RepeatSessionScreenState extends State<RepeatSessionScreen> {
  int _failedPinAttempts = 0;
  DateTime? _pinLockedUntil;

  Future<void> _requestNewAttempt() async {
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SupervisorPinScreen(
          heading: 'Izinkan pengulangan sesi',
          description:
              'Pengawas memasukkan PIN lima digit untuk membuka konfirmasi attempt baru.',
          verifyPin: widget.verifySupervisorPin,
          initialFailedAttempts: _failedPinAttempts,
          initialLockedUntil: _pinLockedUntil,
          onAttemptStateChanged: (attempts, lockedUntil) {
            _failedPinAttempts = attempts;
            _pinLockedUntil = lockedUntil;
          },
        ),
      ),
    );
    if (verified != true || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        icon: const Icon(Icons.replay_outlined, color: Color(0xFF216E4E)),
        title: const Text('Buat attempt baru?'),
        content: const Text(
          'Attempt baru dimulai dengan counter pelanggaran 0. Riwayat attempt sebelumnya tetap disimpan selama masa retensi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Buat Attempt Baru'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop(true);
      await widget.onRepeatApproved();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Pengulangan Sesi',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFD6D6D6)),
      ),
    ),
    body: SafeArea(
      top: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            sliver: SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF595959),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(
                    height: 2,
                    thickness: 2,
                    color: Color(0xFF171717),
                  ),
                  const SizedBox(height: 28),
                  const Icon(
                    Icons.block_outlined,
                    size: 36,
                    semanticLabel: 'Sesi telah berakhir',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sesi ini sudah diakhiri',
                    style: TextStyle(
                      fontSize: 30,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'QR ini mengarah ke sesi yang sudah selesai. Pengulangan tidak dibuat otomatis dan memerlukan izin pengawas.',
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFF3F3F3),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ATTEMPT SEBELUMNYA',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF595959),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Status: Selesai',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pelanggaran: ${widget.previousViolationCount}',
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Riwayat lokal tetap disimpan selama masa retensi 7 hari.',
                          style: TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Setelah PIN benar, pengawas masih harus mengonfirmasi pembuatan attempt baru. Counter baru dimulai dari 0 tanpa mengubah riwayat lama.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFF595959),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _requestNewAttempt,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    icon: const Icon(Icons.lock_outline, size: 20),
                    label: const Text(
                      'PIN Pengawas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      foregroundColor: const Color(0xFF171717),
                      side: const BorderSide(color: Color(0xFF171717)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    child: const Text('Batal & Kembali ke Beranda'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
