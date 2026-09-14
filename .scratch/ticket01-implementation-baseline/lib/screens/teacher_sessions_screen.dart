import 'package:flutter/material.dart';

import '../models/exam_sessions.dart';
import 'create_session_screen.dart';
import 'session_qr_screen.dart';

/// Stitch T01 - Daftar sesi lokal pada HP guru.
class TeacherSessionsScreen extends StatelessWidget {
  const TeacherSessionsScreen({
    this.sessions = const [],
    this.onCreateSession,
    this.onShowQr,
    super.key,
  });

  final List<ExamSession> sessions;
  final VoidCallback? onCreateSession;
  final ValueChanged<ExamSession>? onShowQr;

  void _createSession(BuildContext context) {
    final callback = onCreateSession;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CreateSessionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Sesi Guru',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFD6D6D6)),
      ),
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        children: [
          const Text(
            'Sesi ujian',
            style: TextStyle(
              fontSize: 30,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Kelola sesi Google Forms yang dibuat dan disimpan di perangkat ini.',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Color(0xFF595959),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F3F3),
              border: Border(
                left: BorderSide(color: Color(0xFF171717), width: 4),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.phone_android_outlined, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sesi tersimpan lokal di HP ini. Tidak ada sinkronisasi cloud atau pemantauan siswa.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _createSession(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: const Text(
              'Buat Sesi Baru',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Sesi tersimpan',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${sessions.length} sesi',
                style: const TextStyle(fontSize: 13, color: Color(0xFF595959)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sessions.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD6D6D6)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.inbox_outlined, size: 28),
                  SizedBox(height: 16),
                  Text(
                    'Belum ada sesi ujian',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Buat sesi baru untuk menyiapkan ujian dan QR yang akan dipindai siswa.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFF595959),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final session in sessions) ...[
              _SessionCard(
                session: session,
                onShowQr: () {
                  final callback = onShowQr;
                  if (callback != null) {
                    callback(session);
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SessionQrScreen(session: session),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    ),
  );
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onShowQr});

  final ExamSession session;
  final VoidCallback onShowQr;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFF737373)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          session.examName,
          style: const TextStyle(
            fontSize: 18,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Kode sesi: ${session.sessionCode}',
          style: const TextStyle(fontSize: 14, color: Color(0xFF595959)),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onShowQr,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: const Color(0xFF171717),
            side: const BorderSide(color: Color(0xFF171717)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          icon: const Icon(Icons.qr_code_2, size: 20),
          label: const Text('Tampilkan QR'),
        ),
        const SizedBox(height: 8),
        const Text(
          'Menampilkan QR ini tidak membuat sesi baru.',
          style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF595959)),
        ),
      ],
    ),
  );
}
