import 'dart:async';

import 'package:flutter/material.dart';

import '../models/exam_sessions.dart';
import '../services/exam_session_controller.dart';

/// Stitch S03 - Persiapan Ujian.
class PreExamScreen extends StatefulWidget {
  const PreExamScreen({
    required this.session,
    required this.loadReadiness,
    required this.onOpenNotificationSettings,
    required this.onStart,
    super.key,
  });

  final ExamSession session;
  final Future<ReadinessReport> Function() loadReadiness;
  final FutureOr<void> Function() onOpenNotificationSettings;

  /// Mengaktifkan proteksi, persist attempt active, lalu membuka ujian.
  /// Mengembalikan true bila attempt benar-benar dimulai.
  final Future<bool> Function() onStart;

  @override
  State<PreExamScreen> createState() => _PreExamScreenState();
}

class _PreExamScreenState extends State<PreExamScreen> {
  ReadinessReport? _readiness;
  bool _starting = false;
  String? _startError;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final readiness = await widget.loadReadiness();
      if (!mounted) return;
      setState(() => _readiness = readiness);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _startError = 'Pemeriksaan kesiapan gagal. Minta bantuan pengawas.',
      );
    }
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _startError = null;
    });
    try {
      final started = await widget.onStart();
      if (!mounted || started) return;
      setState(
        () => _startError =
            'Perangkat belum siap. Minta bantuan pengawas atau gunakan ujian alternatif.',
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final readiness = _readiness;
    final allReady = readiness?.allMandatoryPassed ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Persiapan ujian')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(
              widget.session.examName,
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
              widget.session.sessionCode,
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
            _ReadinessRow(
              icon: Icons.qr_code_2,
              label: 'QR sesi',
              status: readiness == null
                  ? 'Memeriksa...'
                  : (readiness.qrValid ? 'Lolos pemeriksaan' : 'QR tidak valid'),
              ready: readiness?.qrValid ?? false,
            ),
            _ReadinessRow(
              icon: Icons.link,
              label: 'Link Google Forms',
              status: readiness == null
                  ? 'Memeriksa...'
                  : (readiness.urlValid
                      ? 'Lolos pemeriksaan'
                      : 'Tautan tidak valid'),
              ready: readiness?.urlValid ?? false,
            ),
            _ReadinessRow(
              icon: Icons.phonelink_lock,
              label: 'Proteksi layar',
              status: readiness == null
                  ? 'Memeriksa...'
                  : (readiness.screenProtectionReady
                      ? 'Aktif di perangkat ini'
                      : 'Belum tersedia'),
              ready: readiness?.screenProtectionReady ?? false,
            ),
            _ReadinessRow(
              icon: Icons.notifications_off_outlined,
              label: 'Pengendalian notifikasi',
              status: readiness == null
                  ? 'Memeriksa...'
                  : (readiness.notificationControlReady
                      ? 'Akses diberikan'
                      : 'Akses belum diberikan'),
              ready: readiness?.notificationControlReady ?? false,
              onActionLabel: readiness != null && !readiness.notificationControlReady
                  ? 'Buka Pengaturan'
                  : null,
              onAction: widget.onOpenNotificationSettings,
            ),
            _ReadinessRow(
              icon: Icons.save_outlined,
              label: 'Penyimpanan sesi',
              status: readiness == null
                  ? 'Memeriksa...'
                  : (readiness.storageWritable
                      ? 'Dapat menyimpan sesi'
                      : 'Penyimpanan gagal'),
              ready: readiness?.storageWritable ?? false,
            ),
            const SizedBox(height: 16),
            Container(
              color: const Color(0xFFFEF3F2),
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFB42318)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      allReady
                          ? 'Semua pemeriksaan wajib lolos. Pastikan kode sesi cocok sebelum mulai.'
                          : 'Perangkat belum siap. Minta bantuan pengawas atau gunakan ujian alternatif.',
                      style: const TextStyle(fontSize: 14, height: 1.5),
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
              onPressed: allReady && !_starting ? _start : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              child: Text(
                _starting ? 'Memulai...' : 'Mulai Ujian',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (_startError != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _startError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFFB42318),
                  ),
                ),
              ),
            ],
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
    this.onActionLabel,
    this.onAction,
  });

  final IconData icon;
  final String label;
  final String status;
  final bool ready;
  final String? onActionLabel;
  final FutureOr<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    final color = ready ? const Color(0xFF216E4E) : const Color(0xFFB42318);
    final action = onActionLabel != null && onAction != null;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFD6D6D6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                ready ? Icons.check_circle : Icons.cancel_outlined,
                color: color,
                semanticLabel: status,
              ),
            ],
          ),
          if (action)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => onAction!(),
                  child: Text(onActionLabel!),
                ),
              ),
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
