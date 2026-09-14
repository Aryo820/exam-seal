import 'package:examseal/core/exam_app.dart';
import 'package:examseal/screens/form_test_screen.dart';
import 'package:examseal/screens/session_qr_screen.dart';
import 'package:examseal/services/exam_session_controller.dart';
import 'package:examseal/services/session_store.dart';
import 'package:examseal/services/teacher_session_secrets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late SessionStore store;
  late TeacherSessionSecrets secrets;
  late ExamSessionController controller;
  setUp(() async {
    db = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    store = await SessionStore.open(db);
    secrets = TeacherSessionSecrets.inMemory();
    controller = ExamSessionController(
      store: store,
      secrets: secrets,
      now: DateTime.now,
    );
  });
  tearDown(() async {
    if (db.isOpen) await db.close();
  });

  test(
    'konfirmasi manual bertahan setelah dibuka ulang dan dibatalkan saat uji ulang',
    () async {
      final session = (await controller.createTeacherSession(
        examName: 'Uji',
        formUrl: Uri.parse('https://forms.gle/pilot'),
      )).session;
      expect(await controller.isFormConfirmed(session), isFalse);
      await expectLater(
        controller.confirmFormReady(session),
        throwsA(isA<StorageFailure>()),
      );
      await controller.beginFormTest(session);
      await controller.recordFormNavigationBlocked(session);
      expect(await controller.isFormConfirmed(session), isFalse);
      await controller.confirmFormReady(session);
      final reopened = ExamSessionController(
        store: await SessionStore.open(db),
        secrets: secrets,
        now: DateTime.now,
      );
      expect(await reopened.isFormConfirmed(session), isTrue);
      final record = (await db.query('form_checks')).single;
      expect(record['blocked_navigations'], 1);
      expect(record['checked_at'], isA<int>());
      await reopened.beginFormTest(session);
      expect(await reopened.isFormConfirmed(session), isFalse);
      final student = ExamSessionController(
        store: store,
        secrets: TeacherSessionSecrets.inMemory(),
        now: DateTime.now,
      );
      await expectLater(
        student.confirmFormReady(session),
        throwsA(isA<StorageFailure>()),
      );
      await db.close();
      await expectLater(
        reopened.confirmFormReady(session),
        throwsA(isA<StorageFailure>()),
      );
    },
  );

  testWidgets(
    'daftar guru menahan QR sampai konfirmasi tersimpan, lalu sesi yang sama bisa dibuka ulang',
    (tester) async {
      final created = (await tester.runAsync(
        () => controller.createTeacherSession(
          examName: 'Uji',
          formUrl: Uri.parse('https://forms.gle/pilot'),
        ),
      ))!;
      await tester.pumpWidget(ExamApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guru'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tampilkan QR'));
      await tester.tap(find.text('Tampilkan QR'));
      await tester.pumpAndSettle();
      expect(find.byType(FormTestScreen), findsOneWidget);
      expect(find.byType(SessionQrScreen), findsNothing);
      expect(find.text('Akses PIN Pengawas'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await controller.beginFormTest(created.session);
      await controller.confirmFormReady(created.session);
      await tester.tap(find.text('Tampilkan QR'));
      await tester.pumpAndSettle();
      expect(find.byType(SessionQrScreen), findsOneWidget);
      expect(
        tester
            .widget<SessionQrScreen>(find.byType(SessionQrScreen))
            .session
            .sessionId,
        created.session.sessionId,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
