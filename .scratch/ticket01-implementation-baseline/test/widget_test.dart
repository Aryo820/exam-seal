import 'package:examseal/core/exam_app.dart';
import 'package:examseal/main.dart' show ExamSealRoot;
import 'package:examseal/services/exam_session_controller.dart';
import 'package:examseal/services/session_store.dart';
import 'package:examseal/services/teacher_session_secrets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('Splash matches Stitch and fits large text on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final db = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    final store = await SessionStore.open(db);
    final controller = ExamSessionController(
      store: store,
      secrets: TeacherSessionSecrets.inMemory(),
      now: () => DateTime.now(),
    );
    controller.attachProtectionStub(
      screenProtectionReady: false,
      notificationControlReady: false,
    );

    await tester.pumpWidget(ExamSealRoot(controller: controller));

    final wordmark = find.text('ExamSeal');
    expect(wordmark, findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
      Colors.white,
    );
    expect(tester.takeException(), isNull);
    // Boot selesai â†’ beranda.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Pilih mode'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Siswa').hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Siswa'));
    await tester.pumpAndSettle();
    expect(find.text('Scan QR Ujian'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Guru').hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Guru'));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Sesi Guru'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Belum ada sesi ujian'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Belum ada sesi ujian'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await db.close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('ExamApp exposes scan route from home for students', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    final store = await SessionStore.open(db);
    final controller = ExamSessionController(
      store: store,
      secrets: TeacherSessionSecrets.inMemory(),
      now: () => DateTime.now(),
    );

    await tester.pumpWidget(ExamApp(controller: controller));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Pilih mode'), findsOneWidget);

    await db.close();
  });
}
