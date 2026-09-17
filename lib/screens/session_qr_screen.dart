import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/exam_sessions.dart';
import '../services/qr_codec.dart';

/// Stitch T04 - QR publik untuk sesi yang telah lolos pemeriksaan guru.
class SessionQrScreen extends StatefulWidget {
  const SessionQrScreen({required this.session, super.key});

  final ExamSession session;

  @override
  State<SessionQrScreen> createState() => _SessionQrScreenState();
}

class _SessionQrScreenState extends State<SessionQrScreen> {
  bool _sharing = false;
  String? _shareError;

  Future<bool> _shareWithSystem(Uint8List png) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(png, name: 'qr-sesi.png', mimeType: 'image/png'),
        ],
        subject: 'QR Sesi ${widget.session.sessionCode}',
      ),
    );
    return result.status == ShareResultStatus.success;
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() {
      _sharing = true;
      _shareError = null;
    });
    try {
      final shared = await _shareWithSystem(
        await renderSessionQrPng(widget.session),
      );
      if (mounted && !shared) {
        setState(() => _shareError = 'Gambar QR tidak berhasil dibagikan.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _shareError = 'Gambar QR tidak berhasil dibagikan.');
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payload = encodeSessionQr(widget.session);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'QR Sesi Ujian',
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
                'Kode QR sesi ujian',
                style: TextStyle(
                  fontSize: 28,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tampilkan QR ini kepada siswa di ruang ujian.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Color(0xFF595959),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.session.examName,
                style: const TextStyle(
                  fontSize: 24,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'KODE SESI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF595959),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.session.sessionCode,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 2, thickness: 2, color: Color(0xFF171717)),
              const SizedBox(height: 24),
              Center(
                child: Semantics(
                  label: 'QR sesi ${widget.session.sessionCode}',
                  image: true,
                  child: ExcludeSemantics(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(20),
                      child: QrImageView(
                        data: payload,
                        version: QrVersions.auto,
                        size: 248,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F3F3),
                  border: Border(
                    left: BorderSide(color: Color(0xFF171717), width: 4),
                  ),
                ),
                child: const Text(
                  'Siswa membuka ExamSeal lalu memilih Scan QR Ujian. Menampilkan ulang layar ini memakai ID dan konfigurasi sesi yang sama.',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
              if (_shareError != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _shareError!,
                    style: const TextStyle(
                      color: Color(0xFFB42318),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _sharing ? null : _share,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                icon: const Icon(Icons.share_outlined, size: 20),
                label: Text(
                  _sharing ? 'Membagikan QR...' : 'Bagikan Gambar QR',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  foregroundColor: const Color(0xFF171717),
                  side: const BorderSide(color: Color(0xFF171717)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                child: const Text('Kembali ke Daftar Sesi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
