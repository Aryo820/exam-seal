import '../models/exam_sessions.dart';

/// State eksplisit attempt ujian lokal. Dialog PIN dan overlay peringatan
/// adalah lapisan UI di atas state ini; mereka tidak dapat mengubah atau
/// menyimpan state lama (PRD ExamSeal, "Alur state yang harus konsisten").
enum AttemptState { preExam, active, locked, recoveryPending, ended }

/// Hasil pendaftaran pelanggaran: peringatan (counter 1-2) atau penguncian.
enum ViolationOutcome { warned, locked }

/// Transisi attempt yang aman. Semua perubahan state melewati kelas ini
/// agar invarian PRD terjaga di satu tempat:
/// - attempt aktif tidak dapat diam-diam ditimpa scan baru;
/// - pelanggaran ketiga mengunci;
/// - setelah Lanjutkan dari terkunci, pelanggaran berikutnya langsung
///   mengunci kembali (tidak ada tiga kesempatan baru);
/// - attempt berakhir hanya dapat diulang setelah PIN pengawas benar.
class AttemptStateMachine {
  AttemptStateMachine({required this.initialViolationCount})
    : violationCount = initialViolationCount,
      _state = AttemptState.preExam;

  AttemptStateMachine.restored({
    required AttemptState state,
    required this.initialViolationCount,
    required this.violationCount,
  }) : _state = state;

  /// Ambang penguncian awal: tiga pelanggaran. Kebijakan inti; tidak dapat
  /// diubah guru maupun siswa.
  static const int initialViolationLimit = 3;

  /// Setelah pernah terkunci (counter >= 3), pelanggaran berikutnya pada
  /// attempt yang sama langsung mengunci kembali.
  static const int relockThreshold = initialViolationLimit;

  final int initialViolationCount;
  int violationCount;

  AttemptState _state;
  String? _sessionId;

  AttemptState get state => _state;
  String? get sessionId => _sessionId;

  /// Event ambigu yang dicatat tetapi tidak pernah menambah counter:
  /// panggilan masuk, jaringan putus, dialog OS, kehilangan fokus saja,
  /// crash/reboot, dan peluncuran ulang (PRD FR05).
  static const Set<String> ambiguousEventTypes = {
    'incomingCall',
    'networkLost',
    'webViewFailed',
    'formUnavailable',
    'focusLost',
    'osDialog',
    'processDeath',
    'appRelaunch',
  };

  /// Matriks terpusat pemicu yang boleh menambah counter. Hanya pemicu
  /// yang benar-benar dapat dibuktikan pada perangkat uji yang masuk;
  /// ini satu-satunya tempat pemicu dihitung, jangan tambahkan pemicu
  /// palsu agar overlay muncul.
  static const Set<String> countedViolationTriggers = {
    'appLeftWhileActive',
  };

  /// Deskripsi yang dapat dibaca siswa/pengawas untuk setiap pemicu
  /// terbukti. Pemicu tanpa deskripsi memakai kode mentahnya.
  static String describeTrigger(String trigger) => switch (trigger) {
        'appLeftWhileActive' => 'Anda meninggalkan layar ujian.',
        _ => trigger,
      };

  /// Mulai attempt pertama: hanya dari preExam, tanpa PIN siswa.
  bool start() {
    if (_state != AttemptState.preExam) return false;
    _state = AttemptState.active;
    return true;
  }

  /// Ikat attempt ke satu sesi. Menerima binding hanya bila attempt belum
  /// terikat; sesi lain ditolak agar data sesi aktif tidak diganti
  /// diam-diam oleh scan baru (invarian data PRD §7).
  void bindSession(ExamSession session) {
    final current = _sessionId;
    if (current != null) {
      throw StateError('Attempt sudah terikat sesi $current.');
    }
    _sessionId = session.sessionId;
  }

  /// Catat kejadian. Mengembalikan true hanya bila event ini menambah
  /// counter pelanggaran; event ambigu dan pemicu di luar matriks selalu
  /// false (dicatat tanpa counter).
  bool recordEvent({required String type}) {
    if (!countedViolationTriggers.contains(type)) return false;
    if (_state != AttemptState.active) return false;
    registerViolation(reason: type);
    return true;
  }

  /// Daftarkan pelanggaran terbukti. Counter 1-2 memberi peringatan;
  /// mencapai ambang mengunci. Setelah pernah terkunci (counter >= 3),
  /// pelanggaran berikutnya langsung mengunci kembali.
  ViolationOutcome registerViolation({required String reason}) {
    if (_state == AttemptState.locked) {
      violationCount++;
      return ViolationOutcome.locked;
    }
    if (_state != AttemptState.active) {
      throw StateError('Pelanggaran hanya relevan pada attempt aktif.');
    }
    final relockNow = violationCount >= relockThreshold;
    violationCount++;
    if (relockNow || violationCount >= initialViolationLimit) {
      _state = AttemptState.locked;
      return ViolationOutcome.locked;
    }
    return ViolationOutcome.warned;
  }

  /// Pengawas melanjutkan attempt terkunci/pemulihan: sesi sama,
  /// counter dan riwayat tetap.
  bool continueBySupervisor() {
    if (_state != AttemptState.locked && _state != AttemptState.recoveryPending) {
      return false;
    }
    _state = AttemptState.active;
    return true;
  }

  /// Pengawas mengakhiri attempt (dari aktif/terkunci/recoveryPending).
  bool endBySupervisor({required String reason}) {
    if (_state == AttemptState.ended) return false;
    _state = AttemptState.ended;
    return true;
  }

  /// Pengawas mengizinkan attempt baru setelah attempt berakhir:
  /// counter nol, riwayat attempt lama tetap tersimpan di store.
  bool repeatBySupervisor() {
    if (_state != AttemptState.ended) return false;
    violationCount = 0;
    _state = AttemptState.active;
    return true;
  }

  /// Proses mati pada attempt aktif: pindah ke recoveryPending tanpa
  /// menambah pelanggaran.
  bool markProcessDeath() {
    if (_state != AttemptState.active) return false;
    _state = AttemptState.recoveryPending;
    return true;
  }

  /// Pulihkan state tersimpan saat boot. Bukan transisi pengguna;
  /// hanya untuk mengisi ulang dari store.
  void restore(AttemptState state) {
    _state = state;
  }
}
