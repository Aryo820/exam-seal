import '../models/exam_sessions.dart';
import 'attempt_state_machine.dart';
import 'form_url_policy.dart';
import 'qr_codec.dart';
import 'session_store.dart';
import 'session_identifiers.dart';

/// Rute yang harus dibuka UI setelah hasil scan diproses.
enum ScanImportRoute {
  /// QR sah dan belum ada attempt: buka pre-exam.
  preExam,

  /// Sudah ada attempt tersimpan (aktif/terkunci/recoveryPending):
  /// arahkan ke status tersimpan, bukan pre-exam baru.
  storedAttempt,

  /// Attempt sebelumnya berakhir: pengulangan perlu dikonfirmasi pengawas.
  endedNeedsConfirmation,
}

/// Hasil mulai attempt.
class StartAttemptResult {
  const StartAttemptResult({required this.started, this.reason});
  final bool started;
  final String? reason;
}

/// Hasil pendaftaran pelanggaran, untuk overlay/lock UI.
class ViolationResult {
  const ViolationResult({
    required this.outcome,
    required this.violationCount,
    required this.reason,
  });
  final ViolationOutcome outcome;
  final int violationCount;
  final String reason;
}

/// Hasil kesiapan perangkat sebelum mulai (FR04). Baris ini yang ditampilkan
/// PreExamScreen; tombol mulai hanya aktif bila [allMandatoryPassed].
class ReadinessReport {
  const ReadinessReport({
    required this.qrValid,
    required this.urlValid,
    required this.storageWritable,
    required this.screenProtectionReady,
    required this.notificationControlReady,
  });

  final bool qrValid;
  final bool urlValid;
  final bool storageWritable;
  final bool screenProtectionReady;
  final bool notificationControlReady;

  bool get allMandatoryPassed =>
      qrValid &&
      urlValid &&
      storageWritable &&
      screenProtectionReady &&
      notificationControlReady;
}

/// Composition root alur ujian lokal: menyatukan store, state machine, dan
/// proteksi native. Satu instance per aplikasi; dibuat di
/// widget tingkat atas tanpa framework state-management.
class ExamSessionController {
  ExamSessionController({
    required SessionStore store,
    required DateTime Function() now,
  }) : _store = store,
       _now = now;

  final SessionStore _store;
  final DateTime Function() _now;

  /// Proteksi native (ticket 05). Di produksi diisi ExamProtection yang
  /// membungkus MethodChannel; di test di-stub lewat attachProtectionStub.
  ExamProtectionBridge? _protection;
  bool _startingStudentAttempt = false;

  /// Polling verifikasi screen pin. Dialog persetujuan sistem bersifat
  /// asinkron sehingga satu cek langsung tidak cukup. Field (bukan const)
  /// agar test bisa mempersingkat tanpa menunggu waktu produksi.
  Duration pinPollInterval = const Duration(seconds: 1);
  int pinPollAttempts = 20;

  ExamProtectionBridge? get protection => _protection;

  /// Ikat ExamProtection native (dipanggil composition root sekali).
  void attachProtection(ExamProtectionBridge protection) {
    _protection = protection;
  }

  /// Stub proteksi untuk test; [restoreSucceeds] mensimulasikan kegagalan
  /// pemulihan pengaturan (retry di UI harus jujur melaporkannya).
  void attachProtectionStub({
    required bool screenProtectionReady,
    required bool notificationControlReady,
    bool restoreSucceeds = true,
  }) {
    _protection = _StubProtection(
      screenProtectionReady,
      notificationControlReady,
      restoreSucceeds,
    );
  }

  // ---- Mode guru ----

  /// Membuat sesi ujian baru dengan kode sesi dan QR publik. Sesi disimpan di
  /// SQLite. Membuat sesi baru selalu ID baru; menampilkan ulang QR tidak
  /// memanggil method ini.
  Future<TeacherSessionCreation> createTeacherSession({
    required String examName,
    required Uri formUrl,
  }) async {
    await _requireTeacherMutationAvailable();
    final name = examName.trim();
    if (name.isEmpty ||
        name.length > 200 ||
        formUrl.toString().length > 2048 ||
        !isAllowedGoogleFormUrl(formUrl)) {
      throw const FormatException(
        'Nama ujian atau tautan Google Forms tidak valid.',
      );
    }
    final session = ExamSession(
      schemaVersion: kSessionQrSchemaVersion,
      sessionId: SessionIdentifiers.id(),
      sessionCode: SessionIdentifiers.code(name),
      examName: name,
      formUrl: formUrl,
      createdAt: _now(),
    );
    try {
      await _requireTeacherMutationAvailable();
      await _store.saveSession(session);
    } catch (_) {
      throw StorageFailure(
        'Sesi belum diterbitkan. Periksa ruang penyimpanan lalu coba lagi.',
      );
    }
    return TeacherSessionCreation(session: session);
  }

  Future<void> _requireTeacherModeAvailable() async {
    return;
  }

  Future<void> _requireTeacherMutationAvailable() async {
    if (await _store.loadCurrentAttempt() != null) {
      throw StorageFailure(
        'Perubahan sesi dan kesiapan Form ditahan selama percobaan siswa berlangsung.',
      );
    }
  }

  Future<T> _withTeacherModeAccess<T>(Future<T> Function() operation) async {
    await _requireTeacherModeAvailable();
    final result = await operation();
    await _requireTeacherModeAvailable();
    return result;
  }

  /// Daftar Mode Guru: HANYA sesi buatan lokal. Sesi hasil scan di HP
  /// siswa disembunyikan agar tidak bisa ditampilkan QR-nya ulang atau
  /// dihapus (menghapus = menghilangkan riwayat pelanggarannya sendiri).
  Future<List<ExamSession>> listTeacherSessions() =>
      _withTeacherModeAccess(() async {
        final sessions = await _store.listLocalSessions();
        return sessions;
      });

  /// Hapus sesi guru beserta riwayat attempt lokalnya. Attempt siswa yang
  /// belum selesai menahan penghapusan; attempt berakhir tidak, sehingga
  /// penanda pembatasan pengulangan lokal ikut hilang dan UI wajib
  /// memperingatkannya lebih dulu (PRD FR07/FR12).
  Future<SessionDeletionResult> deleteTeacherSession(ExamSession session) =>
      _withTeacherModeAccess(() async {
        try {
          await _requireTeacherMutationAvailable();
          await _store.deleteSession(session.sessionId);
          return const SessionDeletionResult(deleted: true);
        } on StorageFailure catch (e) {
          return SessionDeletionResult(deleted: false, error: e.message);
        } catch (_) {
          return const SessionDeletionResult(
            deleted: false,
            error:
                'Sesi belum dapat dihapus. Periksa ruang penyimpanan lalu coba lagi.',
          );
        }
      });

  String encodeQr(ExamSession session) => encodeSessionQr(session);

  ({ExamSession? session, String? error}) scanPayload(String payload) =>
      decodeScan([payload]);

  // ---- Mode siswa: scan & import ----

  /// Proses payload QR hasil scan. Menyimpan sesi bila valid; scan saat
  /// attempt aktif/terkunci tidak pernah menimpa data sesi (FR02).
  Future<({ScanImportRoute? route, String? error})> importScannedSession(
    ExamSession scanned,
  ) async {
    final validation = decodeScan([encodeQr(scanned)]);
    if (validation.error != null) return (route: null, error: validation.error);
    final initialAttempt = await _store.loadCurrentAttempt();
    if (initialAttempt != null &&
        initialAttempt.sessionId != scanned.sessionId) {
      return (
        route: null,
        error:
            'Masih ada ujian yang belum selesai di perangkat ini. Selesaikan dengan pengawas terlebih dahulu.',
      );
    }
    // Coba muat attempt tersimpan untuk sesi yang sama.
    final existingAttempts = await _store.loadAttemptsFor(scanned.sessionId);

    // Invarian data: ID sama dengan bahan berbeda ditolak.
    if (existingAttempts.isNotEmpty) {
      final stored = await _store.loadSession(scanned.sessionId);
      if (stored == null || !stored.sameIdentityAs(scanned)) {
        return (
          route: null,
          error:
              'Data sesi berbeda dengan yang tersimpan di perangkat ini. Minta QR sesi dari guru.',
        );
      }
    } else {
      final stored = await _store.loadSession(scanned.sessionId);
      if (stored != null && !stored.sameIdentityAs(scanned)) {
        return (
          route: null,
          error:
              'Data sesi berbeda dengan yang tersimpan di perangkat ini. Minta QR sesi dari guru.',
        );
      }
      await _store.saveSession(scanned, fromScan: true);
    }

    // Ada attempt menahan (aktif/terkunci/recoveryPending)?
    final current = await _store.loadCurrentAttempt();
    if (current != null && current.sessionId == scanned.sessionId) {
      return (route: ScanImportRoute.storedAttempt, error: null);
    }
    if (current != null) {
      // Attempt sesi lain sedang menahan: tidak boleh diganti diam-diam.
      return (
        route: null,
        error:
            'Masih ada attempt ujian yang belum selesai di perangkat ini. Selesaikan dengan pengawas terlebih dahulu.',
      );
    }

    // Attempt berakhir untuk sesi ini? Pengulangan perlu konfirmasi pengawas.
    final ended = (await _store.loadAttemptsFor(
      scanned.sessionId,
    )).any((a) => a.state == AttemptState.ended);
    if (ended) {
      return (route: ScanImportRoute.endedNeedsConfirmation, error: null);
    }

    return (route: ScanImportRoute.preExam, error: null);
  }

  // ---- Readiness & mulai attempt ----

  /// Pemeriksaan kesiapan nyata: QR/URL tervalidasi, penyimpanan dapat
  /// menulis, proteksi layar dan pengendalian notifikasi siap (native).
  Future<ReadinessReport> assessReadiness(ExamSession session) async {
    final decoded = decodeScan([encodeQr(session)]);
    final qrValid = decoded.session != null;
    final urlValid = qrValid && decoded.session!.formUrl == session.formUrl;

    var storageWritable = false;
    try {
      final stored = await _store.loadSession(session.sessionId);
      if (qrValid && stored != null && stored.sameIdentityAs(session)) {
        await _store.saveSession(session, fromScan: true);
        storageWritable = true;
      }
    } on StorageFailure {
      storageWritable = false;
    }

    final protection = _protection;
    var protectionReady = false;
    try {
      protectionReady = protection != null && await protection.isReady();
    } catch (_) {
      protectionReady = false;
    }

    return ReadinessReport(
      qrValid: qrValid,
      urlValid: urlValid,
      storageWritable: storageWritable,
      screenProtectionReady:
          protectionReady && (protection?.screenProtectionReady ?? false),
      notificationControlReady:
          protectionReady && (protection?.notificationControlReady ?? false),
    );
  }

  /// Mulai attempt siswa: hanya bila semua kesiapan wajib lolos.
  /// Urutan: aktifkan proteksi → persist attempt active → kembalikan rute.
  Future<StartAttemptResult> startStudentAttempt(ExamSession session) async {
    if (_startingStudentAttempt) {
      return const StartAttemptResult(
        started: false,
        reason: 'Pemeriksaan mulai masih berlangsung.',
      );
    }
    _startingStudentAttempt = true;
    ExamProtectionBridge? protection;
    var preparedProtection = false;
    try {
      final readiness = await assessReadiness(session);
      if (!readiness.allMandatoryPassed) {
        return const StartAttemptResult(
          started: false,
          reason:
              'Perangkat belum siap. Minta bantuan pengawas atau gunakan ujian alternatif.',
        );
      }
      protection = _protection;
      if (protection == null) {
        return const StartAttemptResult(
          started: false,
          reason:
              'Proteksi perangkat tidak tersedia. Ujian tidak dapat dimulai.',
        );
      }
      if (await _store.loadCurrentAttempt() != null) {
        return const StartAttemptResult(
          started: false,
          reason: 'Masih ada attempt ujian yang belum selesai.',
        );
      }
      await _store.prepareProtectionActivation(session);
      preparedProtection = true;
      if (!await protection.activate()) {
        await _cancelPreparedProtection(session, protection);
        return const StartAttemptResult(
          started: false,
          reason:
              'Proteksi perangkat gagal diaktifkan. Ujian tidak dapat dimulai.',
        );
      }
      final history = await _store.loadAttemptsFor(session.sessionId);
      final attemptNumber = history.length + 1;
      final attemptId = await _store.startProtectedAttempt(
        session,
        attemptNumber: attemptNumber,
        secureWindowActive: true,
        notificationProtectionActive: true,
        notificationAccessGranted: protection.notificationControlReady,
      );
      // Nyalakan observasi native. Best-effort: kegagalan guard tidak
      // menggagalkan ujian — proteksi keras (FLAG_SECURE/DND) sudah
      // terverifikasi di atas, guard hanya melengkapi catatan sinyal.
      await _startGuardBestEffort(protection);
      // Kunci layar TERAKHIR dan terverifikasi: dialog persetujuan sistem
      // muncul di titik ini (ExamScreen belum mounted sehingga tidak ada
      // hitungan palsu). Penolakan = tolak mulai + rollback penuh
      // termasuk menghapus attempt yatim agar tidak ada attempt aktif
      // yang menahan tanpa jalan keluar yang sah.
      if (!await _pinAndVerify(protection)) {
        await _cancelPreparedProtection(session, protection);
        await _store.deleteAttempt(attemptId);
        return const StartAttemptResult(
          started: false,
          reason:
              'Kunci layar ditolak atau dibatalkan. Ujian tidak dapat dimulai. Minta bantuan pengawas atau gunakan ujian alternatif.',
        );
      }
      return const StartAttemptResult(started: true);
    } on StorageFailure catch (e) {
      // Persist gagal: jangan beri akses soal; coba lepas proteksi.
      if (preparedProtection && protection != null) {
        await _cancelPreparedProtection(session, protection);
      }
      return StartAttemptResult(started: false, reason: e.toString());
    } catch (_) {
      if (preparedProtection && protection != null) {
        await _cancelPreparedProtection(session, protection);
      }
      return const StartAttemptResult(
        started: false,
        reason: 'Pemeriksaan kesiapan gagal. Ujian tidak dapat dimulai.',
      );
    } finally {
      _startingStudentAttempt = false;
    }
  }

  Future<void> _cancelPreparedProtection(
    ExamSession session,
    ExamProtectionBridge protection,
  ) async {
    try {
      await _stopGuardBestEffort(protection);
      await _stopPinBestEffort(protection);
      if (await protection.deactivate()) {
        await _store.clearPreparedProtectionActivation(session.sessionId);
      }
    } catch (_) {
      // Penanda tetap tersimpan agar boot dapat mencoba pemulihan lagi.
    }
  }

  /// Nyalakan ExamGuard tanpa pernah melempar: observasi gagal bukan
  /// alasan menggagalkan ujian yang proteksi kerasnya sudah aktif.
  Future<void> _startGuardBestEffort(ExamProtectionBridge protection) async {
    try {
      await protection.startExamGuard();
    } catch (_) {
      // Diabaikan: sinyal native hanya pelengkap catatan ambigu.
    }
  }

  /// Matikan ExamGuard tanpa pernah melempar.
  Future<void> _stopGuardBestEffort(ExamProtectionBridge protection) async {
    try {
      await protection.stopExamGuard();
    } catch (_) {
      // Diabaikan: yang penting proteksi keras dipulihkan pemanggil.
    }
  }

  /// Minta kunci layar lalu verifikasi lewat polling. True hanya bila
  /// [isScreenPinned] terkonfirmasi. Penolakan/pembatalan dialog sistem
  /// oleh pengguna menghasilkan false (bukan exception) — pemanggil
  /// memutuskan: tolak mulai ujian + tawarkan ujian alternatif.
  Future<bool> _pinAndVerify(ExamProtectionBridge protection) async {
    try {
      await protection.requestScreenPin();
    } catch (_) {
      return false;
    }
    for (var i = 0; i < pinPollAttempts; i++) {
      try {
        if (await protection.isScreenPinned()) return true;
      } catch (_) {
        return false;
      }
      await Future<void>.delayed(pinPollInterval);
    }
    return false;
  }

  /// Lepas kunci layar tanpa pernah melempar. Aman dipanggil walau tidak
  /// ter-pin (no-op di native).
  Future<void> _stopPinBestEffort(ExamProtectionBridge protection) async {
    try {
      await protection.stopScreenPin();
    } catch (_) {
      // Diabaikan: pin bukan proteksi data, hanya kunci navigasi.
    }
  }

  Future<StoredAttempt?> loadCurrentAttempt() => _store.loadCurrentAttempt();

  Future<StoredAttempt?> loadLastEndedAttempt() async {
    // Attempt berakhir terbaru untuk sesi yang menahan; dipakai layar
    // pengulangan.
    final rows = await _store.loadAttemptsFor(
      (await _lastSessionIdWithEnded()) ?? '',
    );
    if (rows.isEmpty) return null;
    return rows.lastWhere(
      (a) => a.state == AttemptState.ended,
      orElse: () => rows.last,
    );
  }

  Future<StoredAttempt?> loadLastEndedAttemptFor(ExamSession session) async {
    final attempts = await _store.loadAttemptsFor(session.sessionId);
    for (final attempt in attempts.reversed) {
      if (attempt.state == AttemptState.ended) return attempt;
    }
    return null;
  }

  Future<String?> _lastSessionIdWithEnded() async {
    final sessions = await _store.listSessions();
    for (final session in sessions) {
      final attempts = await _store.loadAttemptsFor(session.sessionId);
      if (attempts.any((a) => a.state == AttemptState.ended)) {
        return session.sessionId;
      }
    }
    return null;
  }

  // ---- Pelanggaran & event ----

  /// Daftarkan pelanggaran terbukti dari matriks pemicu. Persist counter
  /// dan state SEBELUM UI berpindah (peringatan/lock).
  Future<ViolationResult> registerViolation(String triggerType) async {
    final current = await _store.loadCurrentAttempt();
    if (current == null) {
      throw StateError('Tidak ada attempt aktif.');
    }
    // FR05: pelanggaran hanya relevan saat attempt aktif. Tanpa penjagaan
    // ini, lifecycle dari layar yang sudah tertutup (Offstage) atau balapan
    // dengan penguncian bisa menggelembungkan counter yang sudah terkunci.
    if (current.state != AttemptState.active) {
      throw StateError('Pelanggaran hanya relevan pada attempt aktif.');
    }
    if (!AttemptStateMachine.countedViolationTriggers.contains(triggerType)) {
      throw ArgumentError.value(
        triggerType,
        'triggerType',
        'Pemicu tidak terverifikasi.',
      );
    }
    final correlationId = 'corr-${_now().millisecondsSinceEpoch}';
    final machine = AttemptStateMachine.restored(
      state: current.state,
      initialViolationCount: AttemptStateMachine.initialViolationLimit,
      violationCount: current.violationCount,
    );
    final outcome = machine.registerViolation(reason: triggerType);
    final newState = machine.state;

    await _store.recordViolation(
      attemptId: current.attemptId,
      eventType: triggerType,
      counterAfter: machine.violationCount,
      state: newState,
      correlationId: correlationId,
    );

    return ViolationResult(
      outcome: outcome,
      violationCount: machine.violationCount,
      reason: AttemptStateMachine.describeTrigger(triggerType),
    );
  }

  /// Daftarkan pelanggaran BERAT (matriks v4, mis. unpin paksa): langsung
  /// mengunci ujian dari hitungan berapa pun. Counter dilompatkan ke
  /// ambang agar setelah dilanjutkan pengawas, pelanggaran berikutnya
  /// langsung mengunci lagi. Persist SEBELUM UI berpindah, seperti jalur
  /// normal. Selalu menghasilkan [ViolationOutcome.locked].
  Future<ViolationResult> registerSevereViolation(String triggerType) async {
    final current = await _store.loadCurrentAttempt();
    if (current == null) {
      throw StateError('Tidak ada attempt aktif.');
    }
    if (current.state != AttemptState.active) {
      throw StateError('Pelanggaran hanya relevan pada attempt aktif.');
    }
    if (!AttemptStateMachine.severeViolationTriggers.contains(triggerType)) {
      throw ArgumentError.value(
        triggerType,
        'triggerType',
        'Pemicu berat tidak terverifikasi.',
      );
    }
    final correlationId = 'corr-${_now().millisecondsSinceEpoch}';
    final counterAfter = AttemptStateMachine.severeCounterAfter(
      current.violationCount,
    );

    await _store.recordViolation(
      attemptId: current.attemptId,
      eventType: triggerType,
      counterAfter: counterAfter,
      state: AttemptState.locked,
      correlationId: correlationId,
    );

    return ViolationResult(
      outcome: ViolationOutcome.locked,
      violationCount: counterAfter,
      reason: AttemptStateMachine.describeTrigger(triggerType),
    );
  }

  /// Catat event ambigu (panggilan, jaringan putus, fokus hilang, dsb):
  /// tersimpan sebagai catatan operasional tanpa menambah counter.
  /// Mengembalikan true bila event tercatat.
  Future<bool> recordAmbiguousEvent(String eventType) async {
    final current = await _store.loadCurrentAttempt();
    if (current == null) return false;
    await _store.recordEvent(
      attemptId: current.attemptId,
      eventType: eventType,
      countedAsViolation: false,
      counterAfter: current.violationCount,
    );
    return true;
  }

  /// Pengawas melanjutkan attempt terkunci atau pemulihan setelah memilih
  /// tindakan di layar perangkat siswa.
  Future<bool> continueLockedAttempt() async {
    final current = await _store.loadCurrentAttempt();
    if (current == null ||
        (current.state != AttemptState.locked &&
            current.state != AttemptState.recoveryPending)) {
      return false;
    }
    return _continueWithProtection(current);
  }

  Future<bool> _continueWithProtection(StoredAttempt current) async {
    final session = current.session;
    final protection = _protection;
    if (session == null ||
        protection == null ||
        (current.state != AttemptState.locked &&
            current.state != AttemptState.recoveryPending)) {
      return false;
    }

    var prepared = false;
    try {
      await _store.prepareProtectionActivation(session);
      prepared = true;
      if (!await protection.activate()) {
        await _cancelPreparedProtection(session, protection);
        return false;
      }
      await _startGuardBestEffort(protection);
      await _store.saveProtectionState(
        attemptId: current.attemptId,
        secureWindowActive: true,
        notificationProtectionActive: true,
        notificationAccessGranted: protection.notificationControlReady,
        restorePending: true,
        restoreData: const {'owned': 'examseal'},
      );
      await _store.setAttemptState(
        current.attemptId,
        AttemptState.active,
        violationCount: current.violationCount,
      );
      await _store.recordSupervisorAction(
        attemptId: current.attemptId,
        actionType: 'continue',
        result: 'resumed',
      );
      await _store.clearPreparedProtectionActivation(session.sessionId);
      // Kunci layar ulang: pin tidak selamat dari process death, dan
      // ujian tidak boleh berjalan tanpa pin. Gagal = kembalikan state
      // semula agar tidak ada attempt aktif yang tak terkunci.
      if (!await _pinAndVerify(protection)) {
        await _store.setAttemptState(
          current.attemptId,
          current.state,
          violationCount: current.violationCount,
        );
        await _cancelPreparedProtection(session, protection);
        return false;
      }
      return true;
    } catch (_) {
      if (prepared) await _cancelPreparedProtection(session, protection);
      return false;
    }
  }

  /// Selesaikan aksi Akhiri setelah konfirmasi pengawas: persist berakhir
  /// dulu, lalu pulihkan proteksi, lalu laporkan hasil nyata.
  Future<bool> finishCurrentAttempt({required String reason}) async {
    final current = await _store.loadCurrentAttempt();
    if (current == null) return false;

    await _store.endAttemptWithSupervisorAction(
      attemptId: current.attemptId,
      violationCount: current.violationCount,
      reason: reason,
    );

    var restored = false;
    final protection = _protection;
    if (protection != null) {
      // Hentikan observasi dulu: tidak ada lagi sinyal yang relevan
      // setelah attempt berakhir.
      await _stopGuardBestEffort(protection);
      // Lepas pin agar HP kembali normal untuk pengawas/siswa. Best-effort:
      // kegagalannya tidak membatalkan status berakhir yang sudah persist.
      await _stopPinBestEffort(protection);
      try {
        restored = await protection.restore();
      } catch (_) {
        restored = false;
      }
      if (restored) await _store.clearPendingRestore(current.attemptId);
    }
    return restored;
  }

  /// Pulihkan proteksi tertunda (dipanggil EndedScreen retry).
  Future<bool> retryRestoreSettings() async {
    final protection = _protection;
    if (protection == null) return false;
    final ok = await protection.restore();
    final pendingId = await _store.loadPendingRestoreAttemptId();
    if (ok && pendingId != null) {
      await _store.clearPendingRestore(pendingId);
    }
    return ok;
  }

  /// Buat attempt baru setelah konfirmasi pengawas. Kesiapan dan proteksi
  /// selalu diperiksa ulang oleh [startStudentAttempt].
  Future<StartAttemptResult> repeatStudentAttempt(ExamSession session) async {
    final previous = await loadLastEndedAttemptFor(session);
    if (previous == null || await _store.loadCurrentAttempt() != null) {
      return const StartAttemptResult(
        started: false,
        reason:
            'Status sesi berubah. Scan ulang untuk memeriksa status terbaru.',
      );
    }
    final result = await startStudentAttempt(session);
    if (result.started) {
      await _store.recordSupervisorAction(
        attemptId: previous.attemptId,
        actionType: 'repeat',
        result: 'new_attempt',
      );
    }
    return result;
  }

  // ---- Pemulihan & retensi ----

  /// Proses mati pada attempt aktif: tandai recoveryPending tanpa
  /// menambah pelanggaran (dipanggil saat boot menemukan attempt active).
  Future<bool> markProcessDeath() async {
    final current = await _store.loadCurrentAttempt();
    if (current == null) return false;
    if (current.state != AttemptState.active) return false;
    await _store.recordEvent(
      attemptId: current.attemptId,
      eventType: 'processDeath',
      countedAsViolation: false,
      counterAfter: current.violationCount,
    );
    await _store.setAttemptState(
      current.attemptId,
      AttemptState.recoveryPending,
      violationCount: current.violationCount,
    );
    return true;
  }

  /// Boot: selesaikan pelepasan proteksi/perubahan OS milik aplikasi yang
  /// tertunda setelah sesi berakhir — state berakhir tidak boleh membuat
  /// pemulihan yang belum selesai diabaikan (PRD FR12).
  Future<bool> resolvePendingRestores() async {
    final preparedSessionId = await _store.loadPreparedProtectionSessionId();
    if (preparedSessionId != null) {
      final protection = _protection;
      if (protection == null || !await protection.restore()) return false;
      await _store.clearPreparedProtectionActivation(preparedSessionId);
    }
    final pendingId = await _store.loadPendingRestoreAttemptId();
    if (pendingId == null) return true;
    final protection = _protection;
    if (protection == null) return false;
    final ok = await protection.restore();
    if (ok) {
      await _store.clearPendingRestore(pendingId);
    }
    return ok;
  }

  Future<List<String>> runRetention() => _store.runRetention(now: _now());
}

class TeacherSessionCreation {
  const TeacherSessionCreation({required this.session});
  final ExamSession session;
}

/// Hasil penghapusan sesi guru. [error] terisi bila sesi masih ditahan
/// attempt siswa yang belum selesai atau penyimpanan gagal.
class SessionDeletionResult {
  const SessionDeletionResult({required this.deleted, this.error});
  final bool deleted;
  final String? error;
}

/// Jembatan proteksi yang dipakai controller. Implementasi native ada di
/// ticket 05 (ExamProtection via MethodChannel).
abstract class ExamProtectionBridge {
  Future<bool> isReady();
  Future<bool> activate();
  Future<bool> deactivate();
  Future<bool> restore();
  bool get screenProtectionReady;
  bool get notificationControlReady;

  /// Monitoring lifecycle native (observasi saja). Implementasi default
  /// true agar stub test lama tetap berperilaku seperti guard menyala.
  Future<bool> startExamGuard() => Future.value(true);

  /// Matikan monitoring. Implementasi default aman untuk stub.
  Future<bool> stopExamGuard() => Future.value(true);

  /// Minta kunci layar (screen pinning). Default terkirim agar stub lama
  /// tidak mengubah hasil test yang sudah ada.
  Future<bool> requestScreenPin() => Future.value(true);

  /// Lepas kunci layar. Default aman untuk stub.
  Future<bool> stopScreenPin() => Future.value(true);

  /// Status pin terverifikasi. Default true agar stub lama lolos.
  Future<bool> isScreenPinned() => Future.value(true);
}

class _StubProtection implements ExamProtectionBridge {
  _StubProtection(
    this.screenProtectionReady,
    this.notificationControlReady,
    this._restoreSucceeds,
  );

  @override
  final bool screenProtectionReady;

  @override
  final bool notificationControlReady;

  final bool _restoreSucceeds;

  @override
  Future<bool> isReady() async =>
      screenProtectionReady && notificationControlReady;

  @override
  Future<bool> activate() async => true;

  @override
  Future<bool> deactivate() async => _restoreSucceeds;

  @override
  Future<bool> restore() async => _restoreSucceeds;

  @override
  Future<bool> startExamGuard() async => true;

  @override
  Future<bool> stopExamGuard() async => true;

  @override
  Future<bool> requestScreenPin() async => true;

  @override
  Future<bool> stopScreenPin() async => true;

  @override
  Future<bool> isScreenPinned() async => true;
}
