import 'package:examseal/services/exam_session_controller.dart';
import 'package:examseal/services/session_store.dart';
import 'package:examseal/services/teacher_session_secrets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'akhir ujian memerlukan otorisasi sekali pakai dan hilang saat restart',
    () async {
      final db = await databaseFactoryFfiNoIsolate.openDatabase(
        inMemoryDatabasePath,
      );
      addTearDown(db.close);
      final store = await SessionStore.open(db);
      final secrets = TeacherSessionSecrets.inMemory();
      final controller = ExamSessionController(
        store: store,
        secrets: secrets,
        now: DateTime.now,
      );
      controller.attachProtectionStub(
        screenProtectionReady: true,
        notificationControlReady: true,
      );
      final created = await controller.createTeacherSession(
        examName: 'Fisika',
        formUrl: Uri.parse('https://docs.google.com/forms/d/e/pilot/viewform'),
      );
      await controller.startStudentAttempt(created.session);

      expect(
        await controller.finishAttemptAfterPin(reason: 'Tanpa otorisasi'),
        isFalse,
      );
      expect(await controller.authorizeEnd('00000', created.session), isFalse);
      expect(
        await controller.authorizeEnd(created.pin, created.session),
        isTrue,
      );

      final restarted = ExamSessionController(
        store: store,
        secrets: secrets,
        now: DateTime.now,
      );
      restarted.attachProtectionStub(
        screenProtectionReady: true,
        notificationControlReady: true,
      );
      expect(
        await restarted.finishAttemptAfterPin(reason: 'Otorisasi restart'),
        isFalse,
      );
      expect(
        await controller.finishAttemptAfterPin(reason: 'Diakhiri pengawas'),
        isTrue,
      );
      expect(await controller.loadCurrentAttempt(), isNull);
    },
  );
}
