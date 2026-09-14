import 'dart:async';

import 'package:flutter/services.dart';

import 'exam_session_controller.dart';

/// Hasil pemeriksaan status proteksi native. Klaim dibatasi pada
/// kemampuan yang benar-benar tersedia di perangkat: tidak mengklaim
/// panel notifikasi pasti tertutup atau screenshot pasti terblokir di
/// semua HP (PRD FR08/FR09).
class ProtectionStatus {
  const ProtectionStatus({
    required this.supported,
    required this.secureWindowActive,
    required this.notificationAccessGranted,
    required this.notificationProtectionActive,
    this.error,
  });

  final bool supported;
  final bool secureWindowActive;
  final bool notificationAccessGranted;
  final bool notificationProtectionActive;
  final String? error;
}

/// Wrapper tunggal untuk MethodChannel proteksi Android. Screen Flutter
/// tidak pernah memanggil native channel secara langsung — semua lewat
/// kelas ini (dikonsumsi ExamSessionController/ExamProtectionBridge).
class ExamProtection implements ExamProtectionBridge {
  ExamProtection({void Function(String message)? onLog})
    : _onLog = onLog;

  static const _channel = MethodChannel('examseal/protection');

  final void Function(String message)? _onLog;

  /// Hasil pemeriksaan terakhir yang diketahui; di-refresh saat resume.
  ProtectionStatus? _lastStatus;

  @override
  bool get screenProtectionReady =>
      _lastStatus?.supported == true && (_lastStatus?.secureWindowActive ?? false);

  @override
  bool get notificationControlReady =>
      _lastStatus?.notificationAccessGranted ?? false;

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      _onLog?.call('protection/$method failed: ${e.code} ${e.message}');
      if (e.code == 'unavailable') return null;
      rethrow;
    } on MissingPluginException {
      _onLog?.call('protection/$method: native bridge unavailable');
      return null;
    }
  }

  /// Periksa dukungan/kesiapan proteksi perangkat (API 24+). Jangan
  /// mengubah apa pun; hanya membaca status.
  Future<ProtectionStatus> checkStatus() async {
    final raw = await _invoke<Map<dynamic, dynamic>>('checkStatus');
    if (raw == null) {
      return const ProtectionStatus(
        supported: false,
        secureWindowActive: false,
        notificationAccessGranted: false,
        notificationProtectionActive: false,
        error: 'Bridge proteksi tidak tersedia pada perangkat ini.',
      );
    }
    final status = ProtectionStatus(
      supported: raw['supported'] as bool? ?? false,
      secureWindowActive: raw['secureWindowActive'] as bool? ?? false,
      notificationAccessGranted:
          raw['notificationAccessGranted'] as bool? ?? false,
      notificationProtectionActive:
          raw['notificationProtectionActive'] as bool? ?? false,
      error: raw['error'] as String?,
    );
    _lastStatus = status;
    return status;
  }

  @override
  Future<bool> isReady() async {
    final status = await checkStatus();
    return status.supported && status.secureWindowActive;
  }

  /// Aktifkan FLAG_SECURE dan pengendalian notifikasi DND milik aplikasi.
  /// Tidak meminta akses DND otomatis; bila akses belum ada, kembalikan
  /// false dan biarkan UI mengarahkan siswa ke pengaturan secara eksplisit.
  @override
  Future<bool> activate() async {
    final status = await checkStatus();
    if (!status.supported || !status.notificationAccessGranted) {
      return false;
    }
    final ok = await _invoke<bool>('activate');
    await checkStatus();
    return ok == true;
  }

  /// Lepas proteksi dan pulihkan pengaturan yang diubah aplikasi.
  /// Mengembalikan true hanya bila pemulihan benar-benar berhasil.
  @override
  Future<bool> deactivate() => restore();

  @override
  Future<bool> restore() async {
    final ok = await _invoke<bool>('restore');
    await checkStatus();
    return ok == true;
  }

  /// Buka halaman pengaturan akses Notification Policy atas aksi eksplisit
  /// pengguna (tombol); tidak pernah otomatis saat aplikasi dibuka.
  Future<bool> openNotificationPolicySettings() async {
    final ok = await _invoke<bool>('openNotificationPolicySettings');
    return ok == true;
  }

  /// Baca ulang status saat aplikasi resumed (proteksi bisa dicabut
  /// pengguna lewat pengaturan saat ujian berlangsung).
  Future<ProtectionStatus> refreshOnResume() => checkStatus();
}
