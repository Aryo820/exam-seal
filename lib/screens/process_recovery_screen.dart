import 'dart:async';

import 'package:flutter/material.dart';

import '../models/exam_sessions.dart';
import 'supervisor_decision_screen.dart';
import 'supervisor_pin_screen.dart';

/// Stitch S10 - Pemulihan setelah proses aplikasi terhenti.
class ProcessRecoveryScreen extends StatefulWidget {
  const ProcessRecoveryScreen({
    required this.session,
    required this.violationCount,
    required this.verifySupervisorPin,
    required this.onContinueExam,
    required this.onEndExam,
    this.onAuthorizationCancelled,
    this.onOpenTeacherMode,
    super.key,
  }) : assert(violationCount >= 0);

  final ExamSession session;
  final int violationCount;
  final FutureOr<bool> Function(String pin) verifySupervisorPin;
  final VoidCallback onContinueExam;
  final VoidCallback onEndExam;
  final VoidCallback? onAuthorizationCancelled;
  final Future<void> Function()? onOpenTeacherMode;

  @override
  State<ProcessRecoveryScreen> createState() => _ProcessRecoveryScreenState();
}

class _ProcessRecoveryScreenState extends State<ProcessRecoveryScreen> {
  int _failedPinAttempts = 0;
  DateTime? _pinLockedUntil;

  Future<void> _openSupervisorPin() async {
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SupervisorPinScreen(
          heading: 'Periksa sesi yang dipulihkan',
          description:
              'Pengawas memasukkan PIN lima digit sebelum menentukan kelanjutan sesi.',
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

    final decision = await Navigator.of(context).push<SupervisorDecision>(
      MaterialPageRoute<SupervisorDecision>(
        builder: (_) => SupervisorDecisionScreen(
          session: widget.session,
          violationCount: widget.violationCount,
          latestViolationReason:
              'Aplikasi sempat tertutup. Isian Google Forms mungkin tidak pulih.',
          statusLabel: 'Menunggu pemeriksaan',
          eventLabel: 'Catatan pemulihan',
          warningMessage:
              'Pemulihan tidak menambah pelanggaran baru. Counter dan riwayat yang tersimpan tetap dipertahankan.',
        ),
      ),
    );
    if (decision == SupervisorDecision.continueExam) {
      widget.onContinueExam();
    } else if (decision == SupervisorDecision.endExam) {
      widget.onEndExam();
    } else if (decision == SupervisorDecision.openTeacherMode) {
      await widget.onOpenTeacherMode?.call();
    } else {
      widget.onAuthorizationCancelled?.call();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 24,
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, size: 20),
            SizedBox(width: 8),
            Text(
              'ExamSeal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
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
                    const SizedBox(height: 24),
                    const Icon(
                      Icons.restart_alt,
                      size: 36,
                      color: Color(0xFF8A4B08),
                      semanticLabel: 'Sesi perlu diperiksa',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ujian perlu pemeriksaan pengawas',
                      style: TextStyle(
                        fontSize: 30,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Pelanggaran tersimpan: ${widget.violationCount}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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
                      child: const Text(
                        'Aplikasi sempat tertutup. Sesi ujian ditemukan kembali, tetapi jawaban yang belum tersimpan di Google Forms mungkin tidak dapat dipulihkan.',
                        style: TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Pemulihan ini tidak menambah pelanggaran baru.',
                            style: TextStyle(fontSize: 15, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _openSupervisorPin,
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
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Sesi tidak dapat dibuka tanpa keputusan pengawas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Color(0xFF595959),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
