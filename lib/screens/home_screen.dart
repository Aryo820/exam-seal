import 'package:flutter/material.dart';

import 'scan_qr_screen.dart';
import 'teacher_sessions_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    this.hasActiveStudentSession = false,
    this.onResumeStudentSession,
    this.onOpenTeacherMode,
    this.onOpenStudentScan,
    super.key,
  }) : assert(!hasActiveStudentSession || onResumeStudentSession != null);

  final bool hasActiveStudentSession;
  final VoidCallback? onResumeStudentSession;
  final VoidCallback? onOpenTeacherMode;
  final VoidCallback? onOpenStudentScan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'ExamSeal',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            const Divider(height: 2, thickness: 2, color: Color(0xFF171717)),
            const SizedBox(height: 48),
            const Text(
              'Pilih mode',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'Gunakan ExamSeal sebagai siswa atau guru.',
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Color(0xFF595959),
              ),
            ),
            const SizedBox(height: 32),
            _mode(
              context,
              'Siswa',
              'Ikuti ujian dengan QR sesi dari guru.',
              Icons.qr_code_scanner,
              true,
            ),
            const SizedBox(height: 16),
            _mode(
              context,
              'Guru',
              'Siapkan sesi ujian dan QR untuk siswa.',
              Icons.school_outlined,
              false,
            ),
            const SizedBox(height: 32),
            const Divider(color: Color(0xFFD6D6D6)),
            const SizedBox(height: 16),
            const Text(
              'Ujian Google Forms dengan pengawasan langsung di kelas.',
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

  Widget _mode(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    bool student,
  ) {
    final foreground = student ? Colors.white : const Color(0xFF171717);
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: student ? const Color(0xFF171717) : Colors.white,
        foregroundColor: foreground,
        padding: const EdgeInsets.all(24),
        side: const BorderSide(color: Color(0xFF737373)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        alignment: Alignment.centerLeft,
      ),
      onPressed: () {
        if (student) {
          final openScan = onOpenStudentScan;
          if (openScan != null) {
            openScan();
          } else {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ScanQrScreen()),
            );
          }
        } else if (hasActiveStudentSession) {
          _confirmTeacherMode(context);
        } else {
          _openTeacherMode(context);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmTeacherMode(BuildContext context) async {
    final openTeacherMode = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFF737373)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Buka mode guru?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    tooltip: 'Tutup',
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Sesi ujian siswa masih aktif. Masuk ke mode guru tidak akan mengakhiri atau menghapus sesi ini.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Color(0xFF595959),
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                child: const Text('Kembali ke Ujian'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  foregroundColor: const Color(0xFF171717),
                  side: const BorderSide(color: Color(0xFF171717)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                child: const Text('Buka Mode Guru'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!context.mounted || openTeacherMode == null) return;
    if (!openTeacherMode) {
      onResumeStudentSession!();
      return;
    }

    if (context.mounted) _openTeacherMode(context);
  }

  void _openTeacherMode(BuildContext context) {
    final callback = onOpenTeacherMode;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TeacherSessionsScreen()),
    );
  }
}
