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
}
