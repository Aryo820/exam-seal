import '../models/exam_sessions.dart';
import 'attempt_state_machine.dart';
import 'form_url_policy.dart';
import 'pin_service.dart';
import 'qr_codec.dart';
import 'session_store.dart';
import 'teacher_session_secrets.dart';

/// Rute yang harus dibuka UI setelah hasil scan diproses.
enum ScanImportRoute {
  /// QR sah dan belum ada attempt: buka pre-exam.
  preExam,

  /// Sudah ada attempt tersimpan (aktif/terkunci/recoveryPending):
  /// arahkan ke status tersimpan, bukan pre-exam baru.
  storedAttempt,

  /// Attempt sebelumnya berakhir: pengulangan butuh PIN pengawas.
  endedNeedsPin,
}

/// Hasil verifikasi PIN pengawas untuk satu aksi.
class AuthorizationResult {
  const AuthorizationResult({
    required this.authorized,
    this.cooldownActive = false,
    this.wrongPin = false,
  });

  final bool authorized;
  final bool cooldownActive;
  final bool wrongPin;
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

/// Composition root alur ujian lokal: menyatukan store, PIN service, state
/// machine, dan proteksi native. Satu instance per aplikasi; dibuat di
/// widget tingkat atas tanpa framework state-management.
class ExamSessionController {
  ExamSessionController({
    required SessionStore store,
    required TeacherSessionSecrets secrets,
    required DateTime Function() now,
  }) : _store = store,
       _secrets = secrets,
       _now = now;

  final SessionStore _store;
  final TeacherSessionSecrets _secrets;
  final DateTime Function() _now;

  /// Proteksi native (ticket 05). Di produksi diisi ExamProtection yang
  /// membungkus MethodChannel; di test di-stub lewat attachProtectionStub.
  ExamProtectionBridge? _protection;
  bool _startingStudentAttempt = false;
  String? _endAuthorizationAttemptId;
  String? _verifiedPinAttemptId;

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

  /// Membuat sesi ujian baru lengkap dengan PIN lima digit, kode sesi, dan
  /// bahan verifikasi. PIN disimpan terlindungi di HP pembuat; sesi di
  /// SQLite. Membuat sesi baru selalu ID baru — menampilkan ulang QR
  /// tidak memanggil method ini.
  Future<TeacherSessionCreation> createTeacherSession({
    required String examName,
    required Uri formUrl,
  }) async {
    await _requireTeacherModeAvailable();
    final name = examName.trim();
    if (name.isEmpty ||
        name.length > 200 ||
        formUrl.toString().length > 2048 ||
        !isAllowedGoogleFormUrl(formUrl)) {
      throw const FormatException(
        'Nama ujian atau tautan Google Forms tidak valid.',
      );
    }
    final pin = PinService.generateSupervisorPin();
    final material = await PinService.createVerificationMaterial(pin);
    final session = ExamSession(
      schemaVersion: kSessionQrSchemaVersion,
      sessionId: PinService.generateSessionId(),
      sessionCode: PinService.generateSessionCode(seedName: name),
      examName: name,
      formUrl: formUrl,
      pinSalt: material.salt,
      pinVerifier: material.verifier,
      createdAt: _now(),
    );
    try {
      await _secrets.savePin(session.sessionId, pin);
      await _requireTeacherModeAvailable();
      await _store.saveSession(session);
    } catch (_) {
      try {
        await _secrets.deletePin(session.sessionId);
      } catch (_) {
        throw StorageFailure(
          'Sesi belum diterbitkan. Penyimpanan PIN perlu diperiksa sebelum mencoba lagi.',
        );
      }
      throw StorageFailure(
        'Sesi belum diterbitkan. Periksa ruang penyimpanan dan kunci layar HP, lalu coba lagi.',
      );
    }
    return TeacherSessionCreation(session: session, pin: pin);
  }

  Future<void> _requireTeacherModeAvailable() async {
    if (await _store.loadCurrentAttempt() != null) {
      throw StorageFailure(
        'Selesaikan percobaan siswa dengan pengawas sebelum membuka mode guru.',
      );
    }
  }

  Future<List<ExamSession>> listTeacherSessions() async {
    await _requireTeacherModeAvailable();
    final sessions = await _store.listSessions();
    final owned = <ExamSession>[];
    try {
      for (final session in sessions) {
        if (await _secrets.hasPin(session.sessionId)) owned.add(session);
      }
    } catch (_) {
      throw StorageFailure(
        'Daftar sesi tidak dapat dibaca. Periksa penyimpanan terlindungi lalu coba lagi.',
      );
    }
    return owned;
  }

  /// PIN untuk ditampilkan guru di HP pembuat setelah local_auth.
  Future<String?> readTeacherPin(String sessionId) async {
    await _requireTeacherModeAvailable();
    return _secrets.readPin(sessionId);
  }

  String encodeQr(ExamSession session) => encodeSessionQr(session);

  Future<void> _requireOwnedSession(ExamSession session) async {
    await _requireTeacherModeAvailable();
    final stored = await _store.loadSession(session.sessionId);
    if (stored == null ||
        !stored.sameIdentityAs(session) ||
        !await _secrets.hasPin(session.sessionId)) {
      throw StorageFailure(
        'Pemeriksaan Form hanya tersedia di HP pembuat sesi.',
      );
    }
  }

  Future<bool> isFormConfirmed(ExamSession session) async {
    await _requireOwnedSession(session);
    return _store.isFormConfirmed(session);
  }

  Future<void> beginFormTest(ExamSession session) async {
    await _requireOwnedSession(session);
    await _store.beginFormTest(session, _now());
  }

  Future<void> recordFormNavigationBlocked(ExamSession session) async {
    await _requireOwnedSession(session);
    await _store.recordFormNavigationBlocked(session);
  }

  Future<bool> confirmFormReady(ExamSession session) async {
    await _requireOwnedSession(session);
    await _store.confirmFormReady(session, _now());
    return true;
  }

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

    // Attempt berakhir untuk sesi ini? Pengulangan butuh PIN.
    final ended = (await _store.loadAttemptsFor(
      scanned.sessionId,
    )).any((a) => a.state == AttemptState.ended);
    if (ended) {
      return (route: ScanImportRoute.endedNeedsPin, error: null);
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
      await _store.startProtectedAttempt(
        session,
        attemptNumber: attemptNumber,
        secureWindowActive: true,
        notificationProtectionActive: true,
        notificationAccessGranted: protection.notificationControlReady,
      );
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
      if (await protection.deactivate()) {
        await _store.clearPreparedProtectionActivation(session.sessionId);
      }
    } catch (_) {
      // Penanda tetap tersimpan agar boot dapat mencoba pemulihan lagi.
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
    final machine = AttemptStateMachine.restored(
      state: current.state,
      initialViolationCount: AttemptStateMachine.initialViolationLimit,
      violationCount: current.violationCount,
    );
    final outcome = machine.registerViolation(reason: triggerType);
    final newState = machine.state;

    await _store.recordEvent(
      attemptId: current.attemptId,
      eventType: triggerType,
      countedAsViolation: true,
      counterAfter: machine.violationCount,
      correlationId: 'corr-${_now().millisecondsSinceEpoch}',
    );
    await _store.setAttemptState(
      current.attemptId,
      newState,
      violationCount: machine.violationCount,
    );

    return ViolationResult(
      outcome: outcome,
      violationCount: machine.violationCount,
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

  // ---- Otorisasi pengawas ----

  /// Verifikasi PIN untuk satu aksi pada attempt/sesi yang menahan.
  /// Cooldown lima kegagalan/30 detik persisten di store.
  Future<bool> verifySupervisorPin(String pin, ExamSession session) async {
    final current = await _store.loadCurrentAttempt();
    final scopeId = current?.attemptId ?? session.sessionId;
    final verified = await _verifyPinInScope(pin, session, scopeId);
    if (verified && current != null) _verifiedPinAttemptId = current.attemptId;
    return verified;
  }

  /// Otorisasi khusus untuk mengakhiri attempt aktif. Hanya berlaku sekali
  /// dalam proses aplikasi ini; restart tidak dapat memulihkan otorisasi.
  Future<bool> authorizeEnd(String pin, ExamSession session) async {
    final current = await _store.loadCurrentAttempt();
    final storedSession = current?.session;
    if (current == null ||
        storedSession == null ||
        current.sessionId != session.sessionId)
      return false;
    if (!await _verifyPinInScope(pin, storedSession, current.attemptId))
      return false;
    _endAuthorizationAttemptId = current.attemptId;
    return true;
  }

  /// Dipakai sesudah layar keputusan yang sudah memverifikasi PIN untuk
  /// attempt aktif. Token tetap hanya berlaku satu kali dan tidak persisten.
  Future<bool> authorizeEndAfterVerifiedPin() async {
    final current = await _store.loadCurrentAttempt();
    if (current == null || _verifiedPinAttemptId != current.attemptId)
      return false;
    _verifiedPinAttemptId = null;
    _endAuthorizationAttemptId = current.attemptId;
    return true;
  }

  void cancelEndAuthorization() => _endAuthorizationAttemptId = null;

  Future<bool> _verifyPinInScope(
    String pin,
    ExamSession session,
    String scopeId,
  ) async {
    final status = await _store.loadPinAttemptStatus(scopeId);
    final state = PinAttemptState(
      failedAttempts: status.failedAttempts,
      lockedUntil: status.lockedUntil,
    );
    if (state.isLocked(now: _now())) {
      await _store.savePinAttemptStatus(
        attemptId: scopeId,
        failedAttempts: state.failedAttempts,
        lockedUntil: state.lockedUntil,
      );
      return false;
    }

    final material = PinVerificationMaterial.fromSessionParts(
      session.pinSalt ?? '',
      session.pinVerifier ?? '',
    );
    final ok = await PinService.verifyPin(pin, material);
    if (ok) {
      state.onCorrectAttempt();
    } else {
      state.onWrongAttempt(now: _now());
    }
    await _store.savePinAttemptStatus(
      attemptId: scopeId,
      failedAttempts: state.failedAttempts,
      lockedUntil: state.lockedUntil,
    );
    return ok;
  }

  /// Pengawas melanjutkan attempt terkunci/recoveryPending. Satu PIN,
  /// satu aksi (PRD FR06/FR07).
  Future<AuthorizationResult> supervisorContinue(String pin) async {
    final current = await _store.loadCurrentAttempt();
    if (current == null) {
      return const AuthorizationResult(authorized: false);
    }
    final session = current.session;
    if (session == null) {
      return const AuthorizationResult(authorized: false);
    }
    final status = await _store.loadPinAttemptStatus(current.attemptId);
    final state = PinAttemptState(
      failedAttempts: status.failedAttempts,
      lockedUntil: status.lockedUntil,
    );
    if (state.isLocked(now: _now())) {
      return const AuthorizationResult(authorized: false, cooldownActive: true);
    }
    final ok = await _verifyPinInScope(pin, session, current.attemptId);
    if (!ok) {
      return const AuthorizationResult(authorized: false, wrongPin: true);
    }
    return AuthorizationResult(
      authorized: await _continueWithProtection(current),
    );
  }

  /// Selesaikan aksi Lanjutkan SETELAH layar PIN mengotorisasi: state
  /// active pada attempt yang sama, counter tetap. Dipisah dari
  /// [supervisorContinue] karena layar PIN sudah memverifikasi PIN.
  Future<bool> confirmContinueAfterPin() async {
    final current = await _store.loadCurrentAttempt();
    if (current == null) return false;
    return _continueWithProtection(current);
  }

  Future<bool> _continueWithProtection(StoredAttempt current) async {
    final session = current.session;
    final protection = _protection;
    if (session == null || protection == null) return false;

    var prepared = false;
    try {
      await _store.prepareProtectionActivation(session);
      prepared = true;
      if (!await protection.activate()) {
        await _cancelPreparedProtection(session, protection);
        return false;
      }
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
      return true;
    } catch (_) {
      if (prepared) await _cancelPreparedProtection(session, protection);
      return false;
    }
  }

  /// Selesaikan aksi Akhiri SETELAH layar PIN mengotorisasi: persist
  /// berakhir dulu, lalu pulihkan proteksi, lalu laporkan hasil nyata.
  Future<bool> finishAttemptAfterPin({required String reason}) async {
    final current = await _store.loadCurrentAttempt();
    if (current == null) return false;
    if (_endAuthorizationAttemptId != current.attemptId) return false;
    _endAuthorizationAttemptId = null;

    await _store.endAttemptWithSupervisorAction(
      attemptId: current.attemptId,
      violationCount: current.violationCount,
      reason: reason,
    );

    var restored = false;
    final protection = _protection;
    if (protection != null) {
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

  /// Pengawas mengakhiri attempt: persist berakhir → pulihkan proteksi →
  /// laporkan hasil pemulihan sebenarnya.
  Future<({AuthorizationResult authorization, bool settingsRestored})>
  supervisorEnd(String pin, {required String reason}) async {
    final current = await _store.loadCurrentAttempt();
    if (current == null) {
      return (
        authorization: const AuthorizationResult(authorized: false),
        settingsRestored: false,
      );
    }
    final session = current.session;
    if (session == null) {
      return (
        authorization: const AuthorizationResult(authorized: false),
        settingsRestored: false,
      );
    }
    final ok = await _verifyPinInScope(pin, session, current.attemptId);
    if (!ok) {
      return (
        authorization: const AuthorizationResult(
          authorized: false,
          wrongPin: true,
        ),
        settingsRestored: false,
      );
    }

    // Persist berakhir SEBELUM melepas proteksi.
    await _store.endAttemptWithSupervisorAction(
      attemptId: current.attemptId,
      violationCount: current.violationCount,
      reason: reason,
    );

    // Pulihkan pengaturan; kegagalan dilaporkan jujur.
    var restored = false;
    final protection = _protection;
    if (protection != null) {
      try {
        restored = await protection.restore();
      } catch (_) {
        restored = false;
      }
      if (restored) await _store.clearPendingRestore(current.attemptId);
    }
    return (
      authorization: const AuthorizationResult(authorized: true),
      settingsRestored: restored,
    );
  }

  /// Pengawas mengizinkan attempt baru setelah attempt berakhir.
  /// Otorisasi PIN lalu membuat attempt baru dengan counter nol.
  Future<AuthorizationResult> supervisorRepeat(String pin) async {
    final endedSessionId = await _lastSessionIdWithEnded();
    if (endedSessionId == null) {
      return const AuthorizationResult(authorized: false);
    }
    final session = await _store.loadSession(endedSessionId);
    if (session == null) {
      return const AuthorizationResult(authorized: false);
    }
    final history = await _store.loadAttemptsFor(endedSessionId);
    if (history.isEmpty) {
      return const AuthorizationResult(authorized: false);
    }
    final lastEnded = history.lastWhere(
      (a) => a.state == AttemptState.ended,
      orElse: () => history.last,
    );

    final ok = await _verifyPinInScope(pin, session, lastEnded.attemptId);
    if (!ok) {
      return const AuthorizationResult(authorized: false, wrongPin: true);
    }
    await _store.recordSupervisorAction(
      attemptId: lastEnded.attemptId,
      actionType: 'repeat',
      result: 'new_attempt',
    );

    // Attempt baru counter nol (PRD FR07); riwayat lama tetap.
    final attemptId = await _store.startAttempt(
      session,
      attemptNumber: history.length + 1,
    );
    await _store.saveProtectionState(
      attemptId: attemptId,
      secureWindowActive: true,
      notificationProtectionActive: true,
      notificationAccessGranted: _protection?.notificationControlReady ?? false,
      restorePending: true,
      restoreData: const {'owned': 'examseal'},
    );
    return const AuthorizationResult(authorized: true);
  }

  /// Buat attempt baru setelah otorisasi pengulangan (dipanggil UI setelah
  /// supervisorRepeat sukses dan user mengonfirmasi).
  Future<StartAttemptResult> repeatStudentAttempt(ExamSession session) =>
      startStudentAttempt(session);

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
  const TeacherSessionCreation({required this.session, required this.pin});
  final ExamSession session;
  final String pin;
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
}
