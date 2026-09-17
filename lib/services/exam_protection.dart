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

/// Satu sinyal mentah dari ExamGuard native. Selalu fakta observasi
/// (latar, fokus, interupsi), BUKAN vonis pelanggaran — Flutter yang
/// mengklasifikasi (PRD FR05).
class GuardEvent {
  const GuardEvent({required this.type, required this.atMillis, this.detail});

  /// Dibaca dari map EventChannel {type, atMillis, detail?}.
  /// Mengembalikan null bila payload tidak berbentuk event yang dikenal.
  static GuardEvent? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final type = raw['type'];
    final atMillis = raw['atMillis'];
    if (type is! String || type.isEmpty || atMillis is! int) return null;
    final detail = raw['detail'];
    return GuardEvent(
      type: type,
      atMillis: atMillis,
      detail: detail is String ? detail : null,
    );
  }

  /// Jenis sinyal native: appBackgrounded, appForegrounded,
  /// windowFocusLost, windowFocusGained, possibleSystemInterruption,
  /// examGuardStarted, examGuardStopped.
  final String type;
  final int atMillis;
  final String? detail;
}

/// Wrapper tunggal untuk MethodChannel proteksi Android. Screen Flutter
/// tidak pernah memanggil native channel secara langsung — semua lewat
/// kelas ini (dikonsumsi ExamSessionController/ExamProtectionBridge).
class ExamProtection implements ExamProtectionBridge {
  ExamProtection({void Function(String message)? onLog}) : _onLog = onLog;

  static const _channel = MethodChannel('examseal/protection');
  static const _events = EventChannel('examseal/exam_guard_events');

  /// Batas FR10: peringatan maksimal dua detik per pelanggaran.
  static const maxAlertMs = 2000;

  final void Function(String message)? _onLog;

  /// Hasil pemeriksaan terakhir yang diketahui; di-refresh saat resume.
  ProtectionStatus? _lastStatus;

  @override
  bool get screenProtectionReady => _lastStatus?.supported == true;

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
    // FLAG_SECURE baru aktif saat Mulai Ujian; preflight hanya memeriksa
    // apakah perangkat mendukungnya dan akses DND sudah diberikan.
    return status.supported && status.notificationAccessGranted;
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
    final activated = await checkStatus();
    final verified =
        ok == true &&
        activated.secureWindowActive &&
        activated.notificationProtectionActive;
    if (!verified) await restore();
    return verified;
  }

  /// Lepas proteksi dan pulihkan pengaturan yang diubah aplikasi.
  /// Mengembalikan true hanya bila pemulihan benar-benar berhasil.
  @override
  Future<bool> deactivate() => restore();

  @override
  Future<bool> restore() async {
    final ok = await _invoke<bool>('restore');
    final status = await checkStatus();
    return ok == true && !status.secureWindowActive;
  }

  /// Buka halaman pengaturan akses Notification Policy atas aksi eksplisit
  /// pengguna (tombol); tidak pernah otomatis saat aplikasi dibuka.
  Future<bool> openNotificationPolicySettings() async {
    final ok = await _invoke<bool>('openNotificationPolicySettings');
    return ok == true;
  }

  // ---- ExamGuard eksplisit (hanya monitoring, tanpa putusan) ----

  /// Nyalakan monitoring lifecycle native. Idempoten di sisi Kotlin.
  /// Best-effort: false berarti observasi tidak jalan, bukan berarti
  /// ujian harus gagal — proteksi keras tetap di [activate].
  @override
  Future<bool> startExamGuard() async {
    final ok = await _invoke<bool>('startExamGuard');
    return ok == true;
  }

  /// Matikan monitoring. Idempoten; aman dipanggil saat sudah berhenti.
  @override
  Future<bool> stopExamGuard() async {
    final ok = await _invoke<bool>('stopExamGuard');
    return ok == true;
  }

  Future<bool> isExamGuardActive() async {
    final ok = await _invoke<bool>('isExamGuardActive');
    return ok == true;
  }

  /// Aliran sinyal native → Flutter. Hanya emit saat guard aktif.
  /// Konsumen WAJIB memperlakukan setiap event sebagai catatan ambigu
  /// (recordAmbiguousEvent), tidak pernah sebagai penambah counter —
  /// penghitung tetap matriks Flutter agar tidak dobel-hitung.
  Stream<GuardEvent> guardEvents() => _events.receiveBroadcastStream().where((
    raw,
  ) {
    if (raw == null) return false;
    // Event status guard sendiri bukan sinyal perangkat; saring agar
    // tidak menjadi noise catatan.
    final event = GuardEvent.fromMap(raw);
    return event != null &&
        event.type != 'examGuardStarted' &&
        event.type != 'examGuardStopped';
  }).map((raw) => GuardEvent.fromMap(raw)!);

  // ---- Peringatan native (FR10) ----

  /// Getarkan peringatan sekali. Durasi dijepit ke 1..[maxAlertMs].
  /// False bila perangkat tidak bisa bergetar — bukan error fatal.
  Future<bool> vibrateWarning({int durationMs = 1000}) async {
    final capped = durationMs.clamp(1, maxAlertMs);
    final ok = await _invoke<bool>('vibrateWarning', {'durationMs': capped});
    return ok == true;
  }

  /// Bunyikan nada peringatan (fondasi native: simpan volume → coba
  /// maksimum → bunyi → pulihkan di [stopWarningSound]). Volume maksimum
  /// tidak dijamin vendor; kegagalan dilaporkan false, bukan crash.
  Future<bool> playWarningSound({int durationMs = maxAlertMs}) async {
    final capped = durationMs.clamp(1, maxAlertMs);
    final ok = await _invoke<bool>('playWarningSound', {
      'durationMs': capped,
    });
    return ok == true;
  }

  /// Hentikan nada dan pulihkan volume pengguna. Idempoten.
  Future<bool> stopWarningSound() async {
    final ok = await _invoke<bool>('stopWarningSound');
    return ok == true;
  }

  // ---- Kunci layar / screen pinning (tanpa device owner) ----

  /// Minta OS mem-pin aplikasi. True hanya berarti permintaan terkirim;
  /// pertama kali OS menampilkan dialog persetujuan sistem yang asinkron,
  /// sehingga pemanggil WAJIB verifikasi lewat [isScreenPinned] (polling).
  @override
  Future<bool> requestScreenPin() async {
    final ok = await _invoke<bool>('requestScreenPin');
    return ok == true;
  }

  /// Lepas pin. Sinkron, tanpa dialog, terverifikasi. Idempoten.
  @override
  Future<bool> stopScreenPin() async {
    final ok = await _invoke<bool>('stopScreenPin');
    return ok == true;
  }

  /// True bila aplikasi benar-benar ter-pin saat ini.
  @override
  Future<bool> isScreenPinned() async {
    final ok = await _invoke<bool>('isScreenPinned');
    return ok == true;
  }

  /// Baca ulang status saat aplikasi resumed (proteksi bisa dicabut
  /// pengguna lewat pengaturan saat ujian berlangsung).
  Future<ProtectionStatus> refreshOnResume() => checkStatus();
}
