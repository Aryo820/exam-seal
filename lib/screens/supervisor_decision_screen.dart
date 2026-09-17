import 'package:flutter/material.dart';

import '../models/exam_sessions.dart';

enum SupervisorDecision { continueExam, endExam, openTeacherMode }

/// Stitch S07 - Keputusan Pengawas.
class SupervisorDecisionScreen extends StatelessWidget {
  const SupervisorDecisionScreen({
    required this.session,
    required this.violationCount,
    required this.latestViolationReason,
    this.statusLabel = 'Ujian terkunci',
    this.eventLabel = 'Pelanggaran terakhir',
    this.warningMessage =
        'Jika ujian dilanjutkan, counter dan riwayat tetap tersimpan. Pelanggaran berikutnya akan langsung mengunci ujian kembali.',
    super.key,
  }) : assert(violationCount >= 0);

  final ExamSession session;
  final int violationCount;
  final String latestViolationReason;
  final String statusLabel;
  final String eventLabel;
  final String warningMessage;

  Future<void> _confirmEndExam(BuildContext context) async {
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
          'Sesi akan diakhiri dan tidak dapat dilanjutkan tanpa membuat percobaan baru. Status berakhir bukan bukti jawaban Google Forms sudah terkirim.',
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
    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop(SupervisorDecision.endExam);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Keputusan Pengawas',
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
                      session.examName,
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
                            text: session.sessionCode,
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
                    Container(
                      width: double.infinity,
                      color: const Color(0xFFEDF7F1),
                      padding: const EdgeInsets.all(16),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: Color(0xFF216E4E),
                            semanticLabel: 'Konfirmasi pengawas',
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Pilih satu tindakan untuk sesi ini.',
                              style: TextStyle(fontSize: 14, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Tentukan penanganan',
                      style: TextStyle(
                        fontSize: 28,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SummaryRow(label: 'Status', value: statusLabel),
                    _SummaryRow(
                      label: 'Jumlah pelanggaran',
                      value: '$violationCount',
                    ),
                    _SummaryRow(
                      label: eventLabel,
                      value: latestViolationReason,
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
                      child: Text(
                        warningMessage,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(SupervisorDecision.continueExam),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text(
                        'Lanjutkan Ujian',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(SupervisorDecision.openTeacherMode),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        foregroundColor: const Color(0xFF171717),
                        side: const BorderSide(color: Color(0xFF171717)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text(
                        'Buka Mode Guru',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _confirmEndExam(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        foregroundColor: const Color(0xFFB42318),
                        side: const BorderSide(color: Color(0xFFB42318)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text(
                        'Akhiri Ujian',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFD6D6D6))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF595959)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
