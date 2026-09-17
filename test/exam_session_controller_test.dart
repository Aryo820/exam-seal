import 'dart:convert';

import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/services/attempt_state_machine.dart';
import 'package:examseal/services/exam_session_controller.dart';
import 'package:examseal/services/qr_codec.dart';
import 'package:examseal/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('guru membuat sesi lalu QR publik tanpa PIN atau uji Form', () async {
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
    );
    addTearDown(db.close);
    final controller = ExamSessionController(
      store: await SessionStore.open(db),
      now: DateTime.now,
    );

    final created = await controller.createTeacherSession(
      examName: 'Matematika Kelas XI',
      formUrl: Uri.parse('https://docs.google.com/forms/d/e/example/viewform'),
    );
    final payload =
        jsonDecode(encodeSessionQr(created.session)) as Map<String, dynamic>;

    expect(payload['schemaVersion'], kSessionQrSchemaVersion);
    expect(payload, isNot(contains('pinSalt')));
    expect(payload, isNot(contains('pinVerifier')));
    expect(await controller.listTeacherSessions(), hasLength(1));
  });

  test('hapus sesi guru ditahan selama attempt siswa belum selesai', () async {
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
    );
    addTearDown(db.close);
    final controller = ExamSessionController(
      store: await SessionStore.open(db),
      now: DateTime.now,
    )..attachProtectionStub(
      screenProtectionReady: true,
      notificationControlReady: true,
    );

    final created = await controller.createTeacherSession(
      examName: 'Matematika Kelas XI',
      formUrl: Uri.parse('https://docs.google.com/forms/d/e/example/viewform'),
    );
    expect(
      (await controller.startStudentAttempt(created.session)).started,
      isTrue,
    );

    final blocked = await controller.deleteTeacherSession(created.session);
    expect(blocked.deleted, isFalse);
    expect(blocked.error, isNotNull);
    expect(await controller.listTeacherSessions(), hasLength(1));

    await controller.finishCurrentAttempt(reason: 'Diakhiri pengawas.');

    final deleted = await controller.deleteTeacherSession(created.session);
    expect(deleted.deleted, isTrue);
    expect(deleted.error, isNull);
    expect(await controller.listTeacherSessions(), isEmpty);
  });

  test('exam guard native menyala saat mulai dan mati saat selesai', () async {
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
    );
    addTearDown(db.close);
    final guard = _RecordingProtection();
    final controller = ExamSessionController(
      store: await SessionStore.open(db),
      now: DateTime.now,
    )..attachProtection(guard);

    final created = await controller.createTeacherSession(
      examName: 'Matematika Kelas XI',
      formUrl: Uri.parse('https://docs.google.com/forms/d/e/example/viewform'),
    );
    expect(
      (await controller.startStudentAttempt(created.session)).started,
      isTrue,
    );
    expect(guard.starts, 1);

    await controller.finishCurrentAttempt(reason: 'Diakhiri pengawas.');
    expect(guard.stops, 1);
  });

  test('kegagalan guard native tidak menggagalkan mulai ujian', () async {
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
    );
    addTearDown(db.close);
    final controller = ExamSessionController(
      store: await SessionStore.open(db),
      now: DateTime.now,
    )..attachProtection(_FailingGuardProtection());

    final created = await controller.createTeacherSession(
      examName: 'Matematika Kelas XI',
      formUrl: Uri.parse('https://docs.google.com/forms/d/e/example/viewform'),
    );
    // Guard melempar, tetapi proteksi keras (stub) lolos sehingga ujian
    // tetap mulai: observasi gagal bukan alasan menggagalkan ujian.
    expect(
      (await controller.startStudentAttempt(created.session)).started,
      isTrue,
    );
  });

  test('pin ditolak membatalkan mulai dan me-rollback proteksi', () async {
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
    );
    addTearDown(db.close);
    final pin = _PinDenyingProtection();
    final controller = ExamSessionController(
      store: await SessionStore.open(db),
      now: DateTime.now,
    )..attachProtection(pin);
    // Persingkat polling agar test cepat; logika verifikasi tetap sama.
    controller.pinPollInterval = Duration.zero;
    controller.pinPollAttempts = 2;

    final created = await controller.createTeacherSession(
      examName: 'Matematika Kelas XI',
      formUrl: Uri.parse('https://docs.google.com/forms/d/e/example/viewform'),
    );
    final result = await controller.startStudentAttempt(created.session);

    expect(result.started, isFalse);
    expect(result.reason, contains('Kunci layar'));
    // Rollback penuh: pin dilepas, guard dimatikan, FLAG/DND dipulihkan,
    // dan tidak ada attempt yang tersimpan.
    expect(pin.stopPinCalls, 1);
    expect(pin.stopGuardCalls, 1);
    expect(pin.deactivateCalls, 1);
    expect(await controller.loadCurrentAttempt(), isNull);
  });

  test('unpin paksa langsung mengunci dari hitungan nol', () async {
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
    );
    addTearDown(db.close);
    final controller = ExamSessionController(
      store: await SessionStore.open(db),
      now: DateTime.now,
    )..attachProtection(_RecordingProtection());

    final created = await controller.createTeacherSession(
      examName: 'Matematika Kelas XI',
      formUrl: Uri.parse('https://docs.google.com/forms/d/e/example/viewform'),
    );
    expect(
      (await controller.startStudentAttempt(created.session)).started,
      isTrue,
    );

    final result = await controller.registerSevereViolation('screenUnpinned');

    expect(result.outcome, ViolationOutcome.locked);
    // Counter dilompatkan ke ambang agar invariant relock terjaga.
    expect(result.violationCount, AttemptStateMachine.initialViolationLimit);
    expect(result.reason, 'Anda melepas kunci layar ujian.');
    final current = await controller.loadCurrentAttempt();
    expect(current!.state, AttemptState.locked);
    expect(current.violationCount, AttemptStateMachine.initialViolationLimit);
    // Riwayat tercatat sebagai pelanggaran terhitung.
    expect(
      current.events.where(
        (e) => e.eventType == 'screenUnpinned' && e.countedAsViolation,
      ),
      hasLength(1),
    );
  });

  test('jalur berat menolak pemicu tak dikenal dan state tak aktif', () async {
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
    );
    addTearDown(db.close);
    final controller = ExamSessionController(
      store: await SessionStore.open(db),
      now: DateTime.now,
    )..attachProtection(_RecordingProtection());

    // Tanpa attempt: StateError.
    expect(
      () => controller.registerSevereViolation('screenUnpinned'),
      throwsStateError,
    );
    // Pemicu normal tidak bisa lewat jalur berat: ArgumentError.
    final created = await controller.createTeacherSession(
      examName: 'Matematika Kelas XI',
      formUrl: Uri.parse('https://docs.google.com/forms/d/e/example/viewform'),
    );
    expect(
      (await controller.startStudentAttempt(created.session)).started,
      isTrue,
    );
    expect(
      () => controller.registerSevereViolation('appLeftWhileActive'),
      throwsArgumentError,
    );
  });

  test('sesi hasil scan disembunyikan dari Mode Guru', () async {
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
    );
    addTearDown(db.close);
    final controller = ExamSessionController(
      store: await SessionStore.open(db),
      now: DateTime.now,
    );

    final local = await controller.createTeacherSession(
      examName: 'Matematika Kelas XI',
      formUrl: Uri.parse('https://docs.google.com/forms/d/e/example/viewform'),
    );
    final scanned = ExamSession(
      schemaVersion: kSessionQrSchemaVersion,
      sessionId: 'hasil-scan-1',
      sessionCode: 'BIO-3X8Q',
      examName: 'Biologi Kelas X',
      formUrl: Uri.parse('https://forms.gle/contoh'),
    );
    final imported = await controller.importScannedSession(scanned);
    expect(imported.error, isNull);
    expect(imported.route, ScanImportRoute.preExam);

    // Mode Guru hanya menampilkan buatan lokal; data scan tetap ada
    // untuk keterkaitan attempt.
    final teacherList = await controller.listTeacherSessions();
    expect(teacherList, hasLength(1));
    expect(teacherList.single.sessionId, local.session.sessionId);
  });

  test('pin sukses meloloskan mulai ujian', () async {
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
    );
    addTearDown(db.close);
    final controller = ExamSessionController(
      store: await SessionStore.open(db),
      now: DateTime.now,
    )..attachProtection(_RecordingProtection());

    final created = await controller.createTeacherSession(
      examName: 'Matematika Kelas XI',
      formUrl: Uri.parse('https://docs.google.com/forms/d/e/example/viewform'),
    );
    expect(
      (await controller.startStudentAttempt(created.session)).started,
      isTrue,
    );
  });
}

/// Bridge pencatat untuk memverifikasi siklus hidup ExamGuard.
class _RecordingProtection implements ExamProtectionBridge {
  int starts = 0;
  int stops = 0;

  @override
  bool get screenProtectionReady => true;

  @override
  bool get notificationControlReady => true;

  @override
  Future<bool> isReady() async => true;

  @override
  Future<bool> activate() async => true;

  @override
  Future<bool> deactivate() async => true;

  @override
  Future<bool> restore() async => true;

  @override
  Future<bool> startExamGuard() async {
    starts++;
    return true;
  }

  @override
  Future<bool> stopExamGuard() async {
    stops++;
    return true;
  }

  @override
  Future<bool> requestScreenPin() async => true;

  @override
  Future<bool> stopScreenPin() async => true;

  @override
  Future<bool> isScreenPinned() async => true;
}

/// Bridge yang selalu menolak pin: request terkirim tetapi verifikasi
/// tidak pernah terkonfirmasi (simulasi dialog sistem ditolak).
class _PinDenyingProtection implements ExamProtectionBridge {
  int stopPinCalls = 0;
  int stopGuardCalls = 0;
  int deactivateCalls = 0;

  @override
  bool get screenProtectionReady => true;

  @override
  bool get notificationControlReady => true;

  @override
  Future<bool> isReady() async => true;

  @override
  Future<bool> activate() async => true;

  @override
  Future<bool> deactivate() async {
    deactivateCalls++;
    return true;
  }

  @override
  Future<bool> restore() async => true;

  @override
  Future<bool> startExamGuard() async => true;

  @override
  Future<bool> stopExamGuard() async {
    stopGuardCalls++;
    return true;
  }

  @override
  Future<bool> requestScreenPin() async => true;

  @override
  Future<bool> stopScreenPin() async {
    stopPinCalls++;
    return true;
  }

  @override
  Future<bool> isScreenPinned() async => false;
}

/// Bridge yang guard-nya selalu melempar untuk menguji best-effort.
class _FailingGuardProtection implements ExamProtectionBridge {
  @override
  bool get screenProtectionReady => true;

  @override
  bool get notificationControlReady => true;

  @override
  Future<bool> isReady() async => true;

  @override
  Future<bool> activate() async => true;

  @override
  Future<bool> deactivate() async => true;

  @override
  Future<bool> restore() async => true;

  @override
  Future<bool> startExamGuard() async {
    throw StateError('guard mati');
  }

  @override
  Future<bool> stopExamGuard() async {
    throw StateError('guard mati');
  }

  @override
  Future<bool> requestScreenPin() async => true;

  @override
  Future<bool> stopScreenPin() async => true;

  @override
  Future<bool> isScreenPinned() async => true;
}
