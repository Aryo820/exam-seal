import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/exam_sessions.dart';
import '../services/qr_codec.dart';
import '../services/session_store.dart' show StorageFailure;

/// Adapted from Stitch S02; diagnostic prototype controls are omitted.
class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({this.onSession, super.key});

  /// Dipanggil sekali untuk payload QR sah; composition root yang
  /// memutuskan rute berikutnya (pre-exam, status tersimpan, atau PIN
  /// pengulangan).
  final FutureOr<void> Function(ExamSession session)? onSession;

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final _picker = ImagePicker();
  bool _busy = false;
  bool _delivering = false;
  bool _delivered = false;
  String? _message;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    if (_supported) unawaited(_recoverImage());
  }

  Future<void> _recoverImage() async {
    setState(() => _busy = true);
    try {
      final lost = await _picker.retrieveLostData();
      if (!mounted) return;
      if (lost.exception != null) {
        _message =
            'Gambar sebelumnya tidak dapat dipulihkan. Pilih gambar lagi.';
      } else if (lost.files?.isNotEmpty == true) {
        await _analyze(lost.files!.first.path);
      }
    } catch (_) {
      if (mounted) {
        _message =
            'Gambar sebelumnya tidak dapat dipulihkan. Pilih gambar lagi.';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _detected(BarcodeCapture capture) {
    if (_busy || _delivered || _message != null || !mounted) return;
    final codes = capture.barcodes.where(
      (b) => b.format == BarcodeFormat.qrCode,
    );
    if (codes.isEmpty) return;
    unawaited(_handleCodes(codes.map((b) => b.rawValue ?? '')));
  }

  Future<void> _handleCodes(Iterable<String> values) async {
    if (!mounted || _delivering || _delivered) return;
    final result = decodeScan(values);
    final session = result.session;
    if (session == null) {
      setState(() => _message = result.error);
      return;
    }
    setState(() => _busy = true);
    await _deliver(session);
  }

  Future<void> _deliver(ExamSession session) async {
    _delivering = true;
    try {
      final deliver = widget.onSession;
      if (deliver == null) {
        throw StorageFailure(
          'Penyimpanan sesi belum tersedia. Minta bantuan pengawas.',
        );
      }
      await deliver(session);
      _delivered = true;
    } on StorageFailure catch (e) {
      if (mounted) setState(() => _message = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Sesi tidak dapat disimpan atau dibuka. Periksa penyimpanan lalu scan ulang.',
        );
      }
    } finally {
      _delivering = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _analyze(String path) async {
    final analyzer = MobileScannerController(
      autoStart: false,
      formats: [BarcodeFormat.qrCode],
    );
    try {
      final result = await analyzer.analyzeImage(path);
      if (!mounted) return;
      await _handleCodes(
        result?.barcodes
                .where((b) => b.format == BarcodeFormat.qrCode)
                .map((b) => b.rawValue ?? '') ??
            const <String>[],
      );
    } finally {
      await analyzer.dispose();
    }
  }

  Future<void> _pickImage() async {
    if (_busy || _delivered) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    // Remove the camera widget before opening another native surface.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (image != null && mounted) await _analyze(image.path);
    } catch (_) {
      if (mounted) _message = 'Gambar tidak dapat dibaca. Coba gambar QR lain.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_delivering,
      child: Scaffold(
        appBar: AppBar(title: const Text('Scan QR Ujian')),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(
                        height: 2,
                        thickness: 2,
                        color: Color(0xFF171717),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Arahkan kamera ke QR sesi dari guru',
                        style: TextStyle(
                          fontSize: 28,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Pastikan satu QR terlihat jelas dan seluruh kodenya masuk dalam bingkai.',
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: Color(0xFF595959),
                        ),
                      ),
                      const SizedBox(height: 24),
                      AspectRatio(
                        aspectRatio: 1,
                        child: ColoredBox(
                          color: const Color(0xFF171717),
                          child: !_supported
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text(
                                      'Pemindaian QR tersedia di aplikasi Android.',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                )
                              : _busy || _delivered
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    semanticsLabel: 'Membaca gambar QR',
                                  ),
                                )
                              : _message != null
                              ? const Center(
                                  child: Icon(
                                    Icons.qr_code_2,
                                    color: Colors.white,
                                    size: 64,
                                  ),
                                )
                              : MobileScanner(
                                  onDetect: _detected,
                                  errorBuilder: (_, error) => Center(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        error.errorCode ==
                                                MobileScannerErrorCode
                                                    .permissionDenied
                                            ? 'Izin kamera ditolak. Aktifkan izin kamera di pengaturan aplikasi atau pilih QR dari galeri.'
                                            : 'Kamera tidak tersedia. Gunakan QR dari galeri.',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  overlayBuilder: (_, constraints) =>
                                      IgnorePointer(
                                        child: Center(
                                          child: Container(
                                            width: constraints.maxWidth * .72,
                                            height: constraints.maxHeight * .72,
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_message != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _message!,
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() => _message = null),
                          child: const Text('Scan ulang'),
                        ),
                      ] else if (!_busy && _supported)
                        const Text(
                          'Mencari QR sesi...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF595959),
                          ),
                        ),
                      const SizedBox(height: 24),
                      const Text(
                        'Kembali atau membatalkan pemilihan gambar sebelum ujian bukan pelanggaran.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xFF595959),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 56),
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2),
                      ),
                      side: const BorderSide(color: Color(0xFF737373)),
                    ),
                    onPressed: _busy || _delivered || !_supported
                        ? null
                        : _pickImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text(
                      'Pilih dari Galeri',
                      style: TextStyle(fontSize: 16),
                    ),
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
