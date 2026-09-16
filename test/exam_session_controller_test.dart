import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/services/attempt_state_machine.dart';
import 'package:examseal/services/exam_session_controller.dart';
import 'package:examseal/services/session_store.dart';
import 'package:examseal/services/teacher_session_secrets.dart';

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  final openDbs = <Database>[];

  tearDown(() async {
    for (final db in openDbs) {
      if (db.isOpen) await db.close();
    }
    openDbs.clear();
  });

  Future<ExamSessionController> newController() async {
    final db = await factory.openDatabase(inMemoryDatabasePath);
    openDbs.add(db);
    final store = await SessionStore.open(db);
    return ExamSessionController(
      store: store,
      secrets: TeacherSessionSecrets.inMemory(),
      now: () => DateTime.now(),
    );
  }

  test(
    'teacher flow: create session persists PIN material and the QR stays identical',
    () async {
      final controller = await newController();

      final created = await controller.createTeacherSession(
        examName: 'Matematika Kelas XI',
        formUrl: Uri.parse('https://docs.google.com/forms/d/e/abc/viewform'),
      );
      expect(
        created.session.sessionCode,
        matches(RegExp(r'^[A-Z0-9]{3}-[A-Z0-9]{4}$')),
      );
      expect(created.session.pinSalt, isNotNull);
      expect(created.session.pinVerifier, isNotNull);

      // PIN lima digit diketahui guru dan tidak pernah masuk QR.
      expect(created.pin, matches(RegExp(r'^\d{5}$')));
      expect(
        controller.encodeQr(created.session),
        isNot(contains(created.pin)),
      );

      // Verifikasi PIN bekerja untuk aksi pengawas.
      expect(
        await controller.verifySupervisorPin(created.pin, created.session),
        isTrue,
      );
      expect(
        await controller.verifySupervisorPin('00000', created.session),
        isFalse,
      );

      // Tampilkan ulang: sesi sama dari daftar, QR identik, tanpa sesi baru.
      final sessions = await controller.listTeacherSessions();
      expect(sessions.length, 1);
      expect(sessions.first.sessionId, created.session.sessionId);
      expect(
        controller.encodeQr(sessions.first),
        controller.encodeQr(created.session),
      );

      // PIN dapat dibaca ulang di HP pembuat untuk keperluan tampilan guru.
      expect(
        await controller.readTeacherPin(created.session.sessionId),
        created.pin,
      );
    },
  );

  test(
    'student scan: valid payload is stored; conflicting payload never overwrites',
    () async {
      final controller = await newController();

      // Guru (HP lain) membuat sesi; siswa menerima payload QR.
      final created = await controller.createTeacherSession(
        examName: 'Matematika Kelas XI',
        formUrl: Uri.parse('https://docs.google.com/forms/d/e/abc/viewform'),
      );
      final scanned = controller.scanPayload(
        controller.encodeQr(created.session),
      );
      expect(scanned.error, isNull);

      // Scan pertama: siswa menyimpan sesi.
      final import1 = await controller.importScannedSession(scanned.session!);
      expect(import1.error, isNull);
      expect(import1.route, ScanImportRoute.preExam);

      // Scan ulang sesi identik saat belum ada attempt: tetap pre-exam,
      // tidak membuat sesi ganda.
      final import2 = await controller.importScannedSession(scanned.session!);
      expect(import2.error, isNull);
      expect(import2.route, ScanImportRoute.preExam);
      expect((await controller.listTeacherSessions()).length, 1);

      // Payload jahat: ID sama, verifier berbeda -> ditolak, data lokal tetap.
      final tampered = ExamSession(
        schemaVersion: 2,
        sessionId: scanned.session!.sessionId,
        sessionCode: scanned.session!.sessionCode,
        examName: scanned.session!.examName,
        formUrl: Uri.parse('https://docs.google.com/forms/d/e/abc/viewform'),
        pinSalt: scanned.session!.pinSalt,
        pinVerifier: 'b3RoZXJfdmVyaWZpZXI=',
      );
      final conflict = await controller.importScannedSession(tampered);
      expect(conflict.error, isNotNull);
      expect(conflict.route, isNull);
    },
  );

  test(
    'scan while an attempt is active or locked routes to the stored state',
    () async {
      final controller = await newController();
      final created = await controller.createTeacherSession(
        examName: 'Matematika Kelas XI',
        formUrl: Uri.parse('https://docs.google.com/forms/d/e/abc/viewform'),
      );

      controller.attachProtectionStub(
        screenProtectionReady: true,
        notificationControlReady: true,
      );
      await controller.startStudentAttempt(created.session);
      var current = await controller.loadCurrentAttempt();
      expect(current!.state, AttemptState.active);

      // Scan ulang saat aktif: bukan pre-exam, melainkan status tersimpan.
      final rescan = await controller.importScannedSession(created.session);
      expect(rescan.route, ScanImportRoute.storedAttempt);

      // Kunci, lalu scan ulang lagi: tetap terkunci.
      await controller.registerViolation('appLeftWhileActive');
      await controller.registerViolation('appLeftWhileActive');
      await controller.registerViolation('appLeftWhileActive');
      current = await controller.loadCurrentAttempt();
      expect(current!.state, AttemptState.locked);

      final rescanLocked = await controller.importScannedSession(
        created.session,
      );
      expect(rescanLocked.route, ScanImportRoute.storedAttempt);
      expect(
        (await controller.loadCurrentAttempt())!.state,
        AttemptState.locked,
      );
    },
  );

  test(
    'readiness: storage and QR/URL checks pass before start; button gating works',
    () async {
      final controller = await newController();
      final created = await controller.createTeacherSession(
        examName: 'Matematika Kelas XI',
        formUrl: Uri.parse('https://docs.google.com/forms/d/e/abc/viewform'),
      );

      final readiness = await controller.assessReadiness(created.session);
      expect(readiness.qrValid, isTrue);
      expect(readiness.urlValid, isTrue);
      expect(readiness.storageWritable, isTrue);
      // Proteksi native belum terpasang di controller test: harus false.
      expect(readiness.screenProtectionReady, isFalse);
      expect(readiness.notificationControlReady, isFalse);
      expect(readiness.allMandatoryPassed, isFalse);

      // Attempt hanya boleh mulai setelah proteksi native true; di test
      // native bridge di-stub.
      final stub = await newController();
      final created2 = await stub.createTeacherSession(
        examName: 'Fisika Kelas XI',
        formUrl: Uri.parse('https://docs.google.com/forms/d/e/xyz/viewform'),
      );
      stub.attachProtectionStub(
        screenProtectionReady: true,
        notificationControlReady: true,
      );
      final ready2 = await stub.assessReadiness(created2.session);
      expect(ready2.allMandatoryPassed, isTrue);

      await stub.startStudentAttempt(created2.session);
      final attempt = await stub.loadCurrentAttempt();
      expect(attempt!.state, AttemptState.active);
      expect(attempt.session!.sessionId, created2.session.sessionId);
    },
  );

  test('attempt fails to start without passing mandatory readiness', () async {
    final controller = await newController();
    final created = await controller.createTeacherSession(
      examName: 'Matematika Kelas XI',
      formUrl: Uri.parse('https://docs.google.com/forms/d/e/abc/viewform'),
    );

    final result = await controller.startStudentAttempt(created.session);
    expect(result.started, isFalse);
    expect(result.reason, isNotNull);
    expect(await controller.loadCurrentAttempt(), isNull);
  });

  test(
    'violations persist through controller; third locks; supervisor actions recorded',
    () async {
      final controller = await newController();
      final created = await controller.createTeacherSession(
        examName: 'Matematika Kelas XI',
        formUrl: Uri.parse('https://docs.google.com/forms/d/e/abc/viewform'),
      );
      controller.attachProtectionStub(
        screenProtectionReady: true,
        notificationControlReady: true,
      );
      await controller.startStudentAttempt(created.session);

      final first = await controller.registerViolation('appLeftWhileActive');
      expect(first.outcome, ViolationOutcome.warned);
      final second = await controller.registerViolation('appLeftWhileActive');
      expect(second.outcome, ViolationOutcome.warned);
      final third = await controller.registerViolation('appLeftWhileActive');
      expect(third.outcome, ViolationOutcome.locked);

      // Event ambigu tidak menambah counter meski attempt terkunci.
      final callEvent = await controller.recordAmbiguousEvent('incomingCall');
      expect(callEvent, isTrue); // tercatat
      expect((await controller.loadCurrentAttempt())!.violationCount, 3);

      // Pengawas melanjutkan: PIN benar.
      final continued = await controller.supervisorContinue(created.pin);
      expect(continued.authorized, isTrue);
      expect(
        (await controller.loadCurrentAttempt())!.state,
        AttemptState.active,
      );

      // Setelah lanjut, pelanggaran berikutnya langsung mengunci lagi.
      final fourth = await controller.registerViolation('appLeftWhileActive');
      expect(fourth.outcome, ViolationOutcome.locked);

      // Pengawas mengakhiri dengan PIN; proteksi dilepas.
      final ended = await controller.supervisorEnd(
        created.pin,
        reason: 'Diakhiri pengawas setelah pemeriksaan.',
      );
      expect(ended.authorization.authorized, isTrue);
      expect((await controller.loadCurrentAttempt()), isNull);
      expect(
        (await controller.loadLastEndedAttempt())!.state,
        AttemptState.ended,
      );

      // Pengulangan attempt berakhir butuh PIN; attempt baru counter nol.
      final repeated = await controller.supervisorRepeat(created.pin);
      expect(repeated.authorized, isTrue);
      final newAttempt = await controller.loadCurrentAttempt();
      expect(newAttempt!.violationCount, 0);
      expect(newAttempt.attemptNumber, 2);
    },
  );

  test('gagal mencatat pelanggaran tidak mengubah attempt atau log', () async {
    final db = await factory.openDatabase(inMemoryDatabasePath);
    openDbs.add(db);
    final store = await SessionStore.open(db);
    final controller = ExamSessionController(
      store: store,
      secrets: TeacherSessionSecrets.inMemory(),
      now: DateTime.now,
    );
    final created = await controller.createTeacherSession(
      examName: 'Matematika Kelas XI',
      formUrl: Uri.parse('https://docs.google.com/forms/d/e/abc/viewform'),
    );
    controller.attachProtectionStub(
      screenProtectionReady: true,
      notificationControlReady: true,
    );
    await controller.startStudentAttempt(created.session);
    await db.execute('''
      CREATE TRIGGER reject_violation_update
      BEFORE UPDATE ON attempts
      WHEN NEW.violation_count > OLD.violation_count
      BEGIN SELECT RAISE(FAIL, 'simulasi gagal simpan'); END
    ''');

    await expectLater(
      controller.registerViolation('appLeftWhileActive'),
      throwsA(isA<StorageFailure>()),
    );

    final current = await controller.loadCurrentAttempt();
    expect(current!.state, AttemptState.active);
    expect(current.violationCount, 0);
    expect(
      current.events.where((event) => event.eventType == 'appLeftWhileActive'),
      isEmpty,
    );
  });

  test(
    'lanjut mengonsumsi satu otorisasi PIN pada attempt yang sama',
    () async {
      final controller = await newController();
      final created = await controller.createTeacherSession(
        examName: 'Matematika Kelas XI',
        formUrl: Uri.parse('https://docs.google.com/forms/d/e/abc/viewform'),
      );
      controller.attachProtectionStub(
        screenProtectionReady: true,
        notificationControlReady: true,
      );
      await controller.startStudentAttempt(created.session);
      for (var count = 0; count < 3; count++) {
        await controller.registerViolation('appLeftWhileActive');
      }

      expect(await controller.confirmContinueAfterPin(), isFalse);
      expect(
        await controller.verifySupervisorPin(created.pin, created.session),
        isTrue,
      );
      expect(await controller.confirmContinueAfterPin(), isTrue);
      final resumed = await controller.loadCurrentAttempt();
      expect(resumed!.state, AttemptState.active);
      expect(resumed.violationCount, 3);
      expect(await controller.confirmContinueAfterPin(), isFalse);
    },
  );

  test(
    'pengulangan membutuhkan PIN sesi berakhir sebelum attempt baru',
    () async {
      final controller = await newController();
      final created = await controller.createTeacherSession(
        examName: 'Matematika Kelas XI',
        formUrl: Uri.parse('https://docs.google.com/forms/d/e/abc/viewform'),
      );
      controller.attachProtectionStub(
        screenProtectionReady: true,
        notificationControlReady: true,
      );
      expect(
        (await controller.startStudentAttempt(created.session)).started,
        isTrue,
      );
      await controller.supervisorEnd(
        created.pin,
        reason: 'Pengawas mengakhiri sesi.',
      );

      expect(
        (await controller.repeatStudentAttempt(created.session)).started,
        isFalse,
      );
      expect(
        await controller.verifyRepeatSupervisorPin(
          created.pin,
          created.session,
        ),
        isTrue,
      );
      expect(
        (await controller.repeatStudentAttempt(created.session)).started,
        isTrue,
      );
      final repeated = await controller.loadCurrentAttempt();
      expect(repeated!.attemptNumber, 2);
      expect(repeated.violationCount, 0);
      expect((await controller.loadLastEndedAttempt())!.attemptNumber, 1);
    },
  );

  test('PIN sesi lain tidak dapat melanjutkan attempt terkunci', () async {
    final controller = await newController();
    final first = await controller.createTeacherSession(
      examName: 'Matematika Kelas XI',
      formUrl: Uri.parse('https://docs.google.com/forms/d/e/first/viewform'),
    );
    final second = await controller.createTeacherSession(
      examName: 'Fisika Kelas XI',
      formUrl: Uri.parse('https://docs.google.com/forms/d/e/second/viewform'),
    );
    controller.attachProtectionStub(
      screenProtectionReady: true,
      notificationControlReady: true,
    );
    await controller.startStudentAttempt(first.session);
    for (var count = 0; count < 3; count++) {
      await controller.registerViolation('appLeftWhileActive');
    }

    expect(
      await controller.verifySupervisorPin(second.pin, second.session),
      isFalse,
    );
    expect(await controller.confirmContinueAfterPin(), isFalse);
    expect((await controller.loadCurrentAttempt())!.state, AttemptState.locked);
  });

  test('pengulangan memeriksa kesiapan kembali sebelum attempt baru', () async {
    final controller = await newController();
    final created = await controller.createTeacherSession(
      examName: 'Matematika Kelas XI',
      formUrl: Uri.parse('https://docs.google.com/forms/d/e/abc/viewform'),
    );
    controller.attachProtectionStub(
      screenProtectionReady: true,
      notificationControlReady: true,
    );
    expect(
      (await controller.startStudentAttempt(created.session)).started,
      isTrue,
    );
    await controller.supervisorEnd(
      created.pin,
      reason: 'Pengawas mengakhiri sesi.',
    );
    controller.attachProtectionStub(
      screenProtectionReady: false,
      notificationControlReady: false,
    );

    expect(
      await controller.verifyRepeatSupervisorPin(created.pin, created.session),
      isTrue,
    );
    expect(
      (await controller.repeatStudentAttempt(created.session)).started,
      isFalse,
    );
    expect(await controller.loadCurrentAttempt(), isNull);
    expect((await controller.loadLastEndedAttempt())!.attemptNumber, 1);
  });

  test('PIN cooldown persists across controller restarts', () async {
    final db = await factory.openDatabase(inMemoryDatabasePath);
    openDbs.add(db);
    final store = await SessionStore.open(db);
    final secrets = TeacherSessionSecrets.inMemory();
    final a = ExamSessionController(
      store: store,
      secrets: secrets,
      now: () => DateTime.now(),
    );

    final created = await a.createTeacherSession(
      examName: 'Matematika Kelas XI',
      formUrl: Uri.parse('https://docs.google.com/forms/d/e/abc/viewform'),
    );
    a.attachProtectionStub(
      screenProtectionReady: true,
      notificationControlReady: true,
    );
    await a.startStudentAttempt(created.session);

    // Lima PIN salah berturut-turut.
    for (var i = 0; i < 5; i++) {
      expect(await a.verifySupervisorPin('00000', created.session), isFalse);
    }
    // Percobaan berikutnya ditolak karena cooldown.
    final locked = await a.verifySupervisorPin(created.pin, created.session);
    expect(locked, isFalse);

    // Restart: controller baru dari store yang sama.
    final b = ExamSessionController(
      store: store,
      secrets: secrets,
      now: () => DateTime.now(),
    );
    final stillLocked = await b.verifySupervisorPin(
      created.pin,
      created.session,
    );
    expect(stillLocked, isFalse);

    // Setelah cooldown lewat (disimulasikan dengan jam maju), PIN benar.
    final clock = DateTime.now();
    final c = ExamSessionController(
      store: store,
      secrets: secrets,
      now: () => clock.add(const Duration(seconds: 31)),
    );
    final accepted = await c.verifySupervisorPin(created.pin, created.session);
    expect(accepted, isTrue);
  });

  test(
    'process death on active attempt leads to recoveryPending without new violations',
    () async {
      final controller = await newController();
      final created = await controller.createTeacherSession(
        examName: 'Matematika Kelas XI',
        formUrl: Uri.parse('https://docs.google.com/forms/d/e/abc/viewform'),
      );
      controller.attachProtectionStub(
        screenProtectionReady: true,
        notificationControlReady: true,
      );
      await controller.startStudentAttempt(created.session);
      await controller.registerViolation('appLeftWhileActive');

      await controller.markProcessDeath();

      final current = await controller.loadCurrentAttempt();
      expect(current!.state, AttemptState.recoveryPending);
      expect(current.violationCount, 1);

      // Recovery tidak bisa langsung lanjut tanpa PIN.
      final resumed = await controller.supervisorContinue('wrong');
      expect(resumed.authorized, isFalse);
      expect(
        (await controller.loadCurrentAttempt())!.state,
        AttemptState.recoveryPending,
      );

      final ok = await controller.supervisorContinue(created.pin);
      expect(ok.authorized, isTrue);
      expect(
        (await controller.loadCurrentAttempt())!.state,
        AttemptState.active,
      );
      expect((await controller.loadCurrentAttempt())!.violationCount, 1);
    },
  );

  test(
    'retention runs through controller and never deletes active attempts',
    () async {
      final controller = await newController();
      final created = await controller.createTeacherSession(
        examName: 'Matematika Kelas XI',
        formUrl: Uri.parse('https://docs.google.com/forms/d/e/abc/viewform'),
      );
      controller.attachProtectionStub(
        screenProtectionReady: true,
        notificationControlReady: true,
      );
      await controller.startStudentAttempt(created.session);

      final deleted = await controller.runRetention();
      expect(deleted, isEmpty);
      expect(await controller.loadCurrentAttempt(), isNotNull);
    },
  );

  test(
    'boot resolves a pending protection restore left by a killed process',
    () async {
      final db = await factory.openDatabase(inMemoryDatabasePath);
      openDbs.add(db);
      final store = await SessionStore.open(db);
      final secrets = TeacherSessionSecrets.inMemory();
      final a = ExamSessionController(
        store: store,
        secrets: secrets,
        now: () => DateTime.now(),
      );

      final created = await a.createTeacherSession(
        examName: 'Matematika Kelas XI',
        formUrl: Uri.parse('https://docs.google.com/forms/d/e/abc/viewform'),
      );
      // Restore gagal (mis. DND vendor menolak): pemulihan tetap pending
      // setelah state berakhir tersimpan — proses bisa mati di titik ini.
      a.attachProtectionStub(
        screenProtectionReady: true,
        notificationControlReady: true,
        restoreSucceeds: false,
      );
      await a.startStudentAttempt(created.session);

      final ended = await a.supervisorEnd(
        created.pin,
        reason: 'Diakhiri pengawas setelah pemeriksaan pengiriman jawaban.',
      );
      expect(ended.authorization.authorized, isTrue);
      // Kegagalan pemulihan dilaporkan jujur.
      expect(ended.settingsRestored, isFalse);
      expect(await store.hasPendingRestore(), isTrue);

      // Restart yang juga gagal tetap menahan penanda pemulihan.
      final b = ExamSessionController(
        store: store,
        secrets: secrets,
        now: () => DateTime.now(),
      );
      b.attachProtectionStub(
        screenProtectionReady: true,
        notificationControlReady: true,
        restoreSucceeds: false,
      );
      expect(await b.resolvePendingRestores(), isFalse);
      expect(await store.hasPendingRestore(), isTrue);

      // Boot berikutnya dengan proteksi sehat: pemulihan tertunda selesai.
      final c = ExamSessionController(
        store: store,
        secrets: secrets,
        now: () => DateTime.now(),
      );
      c.attachProtectionStub(
        screenProtectionReady: true,
        notificationControlReady: true,
      );
      expect(await c.resolvePendingRestores(), isTrue);
      expect(await store.hasPendingRestore(), isFalse);

      await db.close();
    },
  );
}
