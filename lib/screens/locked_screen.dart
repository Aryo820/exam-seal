import 'dart:async';

import 'package:flutter/material.dart';

import '../models/exam_sessions.dart';
import 'supervisor_decision_screen.dart';
import 'supervisor_pin_screen.dart';

/// Stitch S06 - Ujian Terkunci.
class LockedScreen extends StatefulWidget {
  const LockedScreen({
    required this.session,
    required this.violationCount,
    required this.violationReason,
    required this.verifySupervisorPin,
    required this.onContinueExam,
    required this.onEndExam,
    this.onAuthorizationCancelled,
    super.key,
  }) : assert(violationCount >= 3);

  final ExamSession session;
  final int violationCount;
  final String violationReason;
  final FutureOr<bool> Function(String pin) verifySupervisorPin;
  final VoidCallback onContinueExam;
  final VoidCallback onEndExam;
  final VoidCallback? onAuthorizationCancelled;

  @override
  State<LockedScreen> createState() => _LockedScreenState();
}

class _LockedScreenState extends State<LockedScreen> {
  int _failedPinAttempts = 0;
  DateTime? _pinLockedUntil;

  Future<void> _openSupervisorPin() async {
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SupervisorPinScreen(
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
          latestViolationReason: widget.violationReason,
        ),
      ),
    );
    if (decision == SupervisorDecision.continueExam) {
      widget.onContinueExam();
    } else if (decision == SupervisorDecision.endExam) {
      widget.onEndExam();
    } else {
      widget.onAuthorizationCancelled?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
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
                      Text.rich(
                        TextSpan(
                          text: 'Kode sesi: ',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF595959),
                          ),
                          children: [
                            TextSpan(
                              text: widget.session.sessionCode,
                              style: const TextStyle(
                                color: Color(0xFF171717),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
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
                        Icons.lock_outline,
                        size: 32,
                        color: Color(0xFFB42318),
                        semanticLabel: 'Ujian terkunci',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ujian dikunci',
                        style: TextStyle(
                          fontSize: 30,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB42318),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pelanggaran: ${widget.violationCount}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB42318),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Semantics(
                        container: true,
                        liveRegion: true,
                        label:
                            'Ujian dikunci. Pelanggaran: ${widget.violationCount}. Alasan: ${widget.violationReason}',
                        child: ExcludeSemantics(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFEF3F2),
                              border: Border(
                                left: BorderSide(
                                  color: Color(0xFFB42318),
                                  width: 4,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ALASAN',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFB42318),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.violationReason,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Tetap di tempat dan angkat tangan. Pengawas akan memeriksa keadaan sebelum menentukan apakah ujian dapat dilanjutkan.',
                        style: TextStyle(fontSize: 16, height: 1.5),
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
                          'Hanya pengawas yang boleh memasukkan PIN.',
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
}
