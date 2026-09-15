import 'dart:async';

import 'package:flutter/material.dart';

import '../models/exam_sessions.dart';
import 'supervisor_pin_screen.dart';

/// Stitch S08 - Persetujuan Selesai.
class CompletionApprovalScreen extends StatefulWidget {
  const CompletionApprovalScreen({
    required this.session,
    required this.violationCount,
    required this.verifySupervisorPin,
    required this.cancelEndAuthorization,
    super.key,
  });

  final ExamSession session;
  final int violationCount;
  final FutureOr<bool> Function(String pin) verifySupervisorPin;
  final VoidCallback cancelEndAuthorization;

  @override
  State<CompletionApprovalScreen> createState() =>
      _CompletionApprovalScreenState();
}

class _CompletionApprovalScreenState extends State<CompletionApprovalScreen> {
  int _failedPinAttempts = 0;
  DateTime? _pinLockedUntil;

  Future<void> _requestEndApproval() async {
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SupervisorPinScreen(
          heading: 'Akhiri ujian',
          description:
              'Setelah memeriksa bukti pengiriman Google Forms, masukkan PIN pengawas lima digit.',
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
        icon: const Icon(
          Icons.warning_amber_outlined,
          color: Color(0xFFB42318),
        ),
        title: const Text('Akhiri ujian?'),
        content: const Text(
          'Pastikan pengawas sudah memeriksa bukti pengiriman jawaban. Status sesi berakhir bukan bukti Google Forms menerima jawaban.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
              foregroundColor: Colors.white,
            ),
            child: const Text('Akhiri Ujian'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop(true);
    } else {
      widget.cancelEndAuthorization();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Persetujuan Selesai',
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
                    const SizedBox(height: 4),
                    Text(
                      'Pelanggaran: ${widget.violationCount}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(
                      height: 2,
                      thickness: 2,
                      color: Color(0xFF171717),
                    ),
                    const SizedBox(height: 32),
                    const Icon(
                      Icons.pan_tool_alt_outlined,
                      size: 32,
                      semanticLabel: 'Minta bantuan pengawas',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tetap di tempat dan angkat tangan.',
                      style: TextStyle(
                        fontSize: 28,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Pengawas perlu memeriksa bukti pengiriman jawaban pada perangkat ini sebelum memasukkan PIN.',
                      style: TextStyle(fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF4DF),
                        border: Border(
                          left: BorderSide(color: Color(0xFF8A4B08), width: 4),
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Color(0xFF8A4B08),
                            semanticLabel: 'Informasi penting',
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'ExamSeal tidak dapat memastikan jawaban sudah terkirim ke Google Forms.',
                              style: TextStyle(fontSize: 14, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _requestEndApproval,
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
                      child: const Text('Kembali ke Ujian'),
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
}
