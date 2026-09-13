import 'package:flutter/material.dart';

import '../models/exam_sessions.dart';

/// Stitch S03 - Persiapan Ujian.
class PreExamScreen extends StatelessWidget {
  const PreExamScreen({required this.session, super.key});

  final ExamSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Persiapan ujian')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(
              session.examName,
              style: const TextStyle(
                fontSize: 28,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'KODE SESI',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF595959),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              session.sessionCode,
              style: const TextStyle(
                fontSize: 20,
                height: 1.4,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 2, thickness: 2, color: Color(0xFF171717)),
            const SizedBox(height: 16),
            const Text(
              'Cocokkan nama ujian dan kode ini dengan layar guru sebelum melanjutkan.',
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Color(0xFF595959),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Kesiapan perangkat',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const _ReadinessRow(
              icon: Icons.qr_code_2,
              label: 'QR sesi',
              status: 'Lolos pemeriksaan',
              ready: true,
            ),
            const _ReadinessRow(
              icon: Icons.link,
              label: 'Link Google Forms',
              status: 'Lolos pemeriksaan',
              ready: true,
            ),
            const _ReadinessRow(
              icon: Icons.phonelink_lock,
              label: 'Proteksi layar',
              status: 'Belum tersedia',
            ),
            const _ReadinessRow(
              icon: Icons.notifications_off_outlined,
              label: 'Pengendalian notifikasi',
              status: 'Belum tersedia',
            ),
            const _ReadinessRow(
              icon: Icons.save_outlined,
              label: 'Penyimpanan sesi',
              status: 'Belum tersedia',
            ),
            const SizedBox(height: 16),
            Container(
              color: const Color(0xFFFEF3F2),
              padding: const EdgeInsets.all(16),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: Color(0xFFB42318)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Perangkat belum siap. Minta bantuan pengawas atau gunakan ujian alternatif.',
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Aturan ujian',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const _Rule(
              number: '1',
              text:
                  'Pelanggaran pertama dan kedua memberi peringatan; pelanggaran ketiga mengunci ujian.',
            ),
            const _Rule(
              number: '2',
              text:
                  'Keluar dari sesi membutuhkan persetujuan dan PIN pengawas.',
            ),
            const _Rule(
              number: '3',
              text:
                  'Peringatan dapat disertai bunyi atau getaran singkat sesuai kemampuan HP.',
            ),
            const _Rule(
              number: '4',
              text:
                  'Panggilan masuk dan jaringan putus tidak otomatis dihitung sebagai pelanggaran.',
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              child: const Text('Mulai Ujian', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ujian hanya dapat dimulai setelah semua pemeriksaan wajib lolos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF595959),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({
    required this.icon,
    required this.label,
    required this.status,
    this.ready = false,
  });

  final IconData icon;
  final String label;
  final String status;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final color = ready ? const Color(0xFF216E4E) : const Color(0xFFB42318);
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFD6D6D6))),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(fontSize: 14, height: 1.4, color: color),
                ),
              ],
            ),
          ),
          Icon(
            ready ? Icons.check_circle : Icons.cancel_outlined,
            color: color,
            semanticLabel: status,
          ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Text(
            '$number.',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 16, height: 1.5)),
        ),
      ],
    ),
  );
}
