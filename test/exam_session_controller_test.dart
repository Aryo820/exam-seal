import 'dart:convert';

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
}
