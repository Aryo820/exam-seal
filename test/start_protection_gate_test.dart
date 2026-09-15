import 'dart:async';

import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/services/attempt_state_machine.dart';
import 'package:examseal/services/exam_session_controller.dart';
import 'package:examseal/services/session_store.dart';
import 'package:examseal/services/teacher_session_secrets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late SessionStore store;
  late ExamSessionController controller;

  setUp(() async {
    db = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    store = await SessionStore.open(db);
    controller = ExamSessionController(
      store: store,
      secrets: TeacherSessionSecrets.inMemory(),
      now: DateTime.now,
    );
  });
  tearDown(() async {
    if (db.isOpen) await db.close();
  });

  Future<ExamSession> session() async => (await controller.createTeacherSession(
    examName: 'Fisika',
    formUrl: Uri.parse('https://docs.google.com/forms/d/e/pilot/viewform'),
  )).session;

  test('aktivasi gagal tidak menyimpan attempt atau membuka gerbang', () async {
    final protection = _Protection(activationSucceeds: false);
    controller.attachProtection(protection);
    final current = await session();

    final result = await controller.startStudentAttempt(current);

    expect(result.started, isFalse);
    expect(await controller.loadCurrentAttempt(), isNull);
    expect(await store.loadPreparedProtectionSessionId(), isNull);
  });

  test(
    'start serentak membuat tepat satu attempt dengan status pemulihan',
    () async {
      final activation = Completer<bool>();
      final protection = _Protection(activation: activation.future);
      controller.attachProtection(protection);
      final current = await session();

      final first = controller.startStudentAttempt(current);
      final second = controller.startStudentAttempt(current);
      activation.complete(true);

      expect((await first).started, isTrue);
      expect((await second).started, isFalse);
      expect(await controller.loadCurrentAttempt(), isNotNull);
      expect(await store.loadPreparedProtectionSessionId(), isNull);
      final state = (await db.query('protection_states')).single;
      expect(state['secure_window_state'], 'active');
      expect(state['notification_protection_state'], 'active');
      expect(state['restore_pending'], 1);
    },
  );

  test(
    'penanda sebelum aktivasi dipulihkan pada boot bila proses mati',
    () async {
      final protection = _Protection();
      controller.attachProtection(protection);
      final current = await session();
      await store.prepareProtectionActivation(current);

      expect(await controller.resolvePendingRestores(), isTrue);
      expect(protection.restoreCalls, 1);
      expect(await store.loadPreparedProtectionSessionId(), isNull);
    },
  );

  test(
    'gagal menyimpan status proteksi membatalkan attempt dan memulihkan native',
    () async {
      final protection = _Protection();
      controller.attachProtection(protection);
      final current = await session();
      await db.execute('''
        CREATE TRIGGER reject_protection_state
        BEFORE INSERT ON protection_states
        BEGIN SELECT RAISE(FAIL, 'simulasi gagal simpan'); END
      ''');

      final result = await controller.startStudentAttempt(current);

      expect(result.started, isFalse);
      expect(await controller.loadCurrentAttempt(), isNull);
      expect(protection.deactivateCalls, 1);
      expect(await store.loadPreparedProtectionSessionId(), isNull);
    },
  );

  test(
    'attempt yang sudah aktif tidak mengaktifkan native untuk kedua kali',
    () async {
      final protection = _Protection();
      controller.attachProtection(protection);
      final current = await session();

      expect((await controller.startStudentAttempt(current)).started, isTrue);
      expect((await controller.startStudentAttempt(current)).started, isFalse);
      expect(protection.activateCalls, 1);
    },
  );

  test(
    'lanjut setelah pemulihan mengaktifkan proteksi lagi sebelum aktif',
    () async {
      final protection = _Protection();
      controller.attachProtection(protection);
      final current = await session();
      expect((await controller.startStudentAttempt(current)).started, isTrue);
      await controller.markProcessDeath();

      expect(await controller.confirmContinueAfterPin(), isTrue);
      expect(protection.activateCalls, 2);
      expect(
        (await controller.loadCurrentAttempt())!.state,
        AttemptState.active,
      );
    },
  );

  test(
    'kegagalan proteksi saat lanjut mempertahankan attempt pemulihan',
    () async {
      final protection = _Protection();
      controller.attachProtection(protection);
      final current = await session();
      expect((await controller.startStudentAttempt(current)).started, isTrue);
      await controller.markProcessDeath();
      final failingProtection = _Protection(activationSucceeds: false);
      controller.attachProtection(failingProtection);

      expect(await controller.confirmContinueAfterPin(), isFalse);
      expect(failingProtection.activateCalls, 1);
      expect(
        (await controller.loadCurrentAttempt())!.state,
        AttemptState.recoveryPending,
      );
    },
  );
}

class _Protection implements ExamProtectionBridge {
  _Protection({this.activationSucceeds = true, Future<bool>? activation})
    : _activation = activation;

  final bool activationSucceeds;
  final Future<bool>? _activation;
  int restoreCalls = 0;
  int deactivateCalls = 0;
  int activateCalls = 0;

  @override
  bool get notificationControlReady => true;

  @override
  bool get screenProtectionReady => true;

  @override
  Future<bool> activate() {
    activateCalls++;
    return _activation ?? Future.value(activationSucceeds);
  }

  @override
  Future<bool> deactivate() async {
    deactivateCalls++;
    return true;
  }

  @override
  Future<bool> isReady() async => true;

  @override
  Future<bool> restore() async {
    restoreCalls++;
    return true;
  }
}
