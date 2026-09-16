import 'package:examseal/core/exam_app.dart';
import 'package:examseal/screens/process_recovery_screen.dart';
import 'package:examseal/services/attempt_state_machine.dart';
import 'package:examseal/services/exam_session_controller.dart';
import 'package:examseal/services/session_store.dart';
import 'package:examseal/services/teacher_session_secrets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  Future<ExamSessionController> seededController(
    Database db, {
    bool restoreSucceeds = true,
  }) async {
    final store = await SessionStore.open(db);
    final controller = ExamSessionController(
      store: store,
      secrets: TeacherSessionSecrets.inMemory(),
      now: () => DateTime.now(),
    );
    controller.attachProtectionStub(
      screenProtectionReady: true,
      notificationControlReady: true,
      restoreSucceeds: restoreSucceeds,
    );
    return controller;
  }

  testWidgets('restart with an active attempt opens recovery, not the exam', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
    );
    addTearDown(db.close);

    // Sesi dibuat dan attempt aktif "sebelum proses mati".
    final a = await seededController(db);
    final created = (await tester.runAsync(
      () => a.createTeacherSession(
        examName: 'Matematika Kelas XI',
        formUrl: Uri.parse('https://docs.google.com/forms/d/e/abc/viewform'),
      ),
    ))!;
    await a.startStudentAttempt(created.session);
    await a.registerViolation('appLeftWhileActive');
    expect((await a.loadCurrentAttempt())!.state, AttemptState.active);

    // Boot ulang: attempt aktif → recoveryPending, bukan Google Forms.
    final b = await seededController(db);
    await tester.pumpWidget(ExamApp(controller: b));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(ProcessRecoveryScreen), findsOneWidget);
    // Counter dipertahankan tanpa pelanggaran baru.
    final attempt = await b.loadCurrentAttempt();
    expect(attempt!.state, AttemptState.recoveryPending);
    expect(attempt.violationCount, 1);

    await db.close();
  });

  testWidgets('restart with a locked attempt stays locked', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
    );
    addTearDown(db.close);

    final a = await seededController(db);
    final created = (await tester.runAsync(
      () => a.createTeacherSession(
        examName: 'Matematika Kelas XI',
        formUrl: Uri.parse('https://docs.google.com/forms/d/e/abc/viewform'),
      ),
    ))!;
    await a.startStudentAttempt(created.session);
    for (var i = 0; i < 3; i++) {
      await a.registerViolation('appLeftWhileActive');
    }
    expect((await a.loadCurrentAttempt())!.state, AttemptState.locked);

    final b = await seededController(db);
    await tester.pumpWidget(
      ExamApp(controller: b, formContent: const SizedBox()),
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Ujian dikunci'), findsOneWidget);
    final attempt = await b.loadCurrentAttempt();
    expect(attempt!.state, AttemptState.locked);
    expect(attempt.violationCount, 3);

    await db.close();
  });

  testWidgets('restart with no attempt opens home mode selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
    );
    final controller = await seededController(db);

    await tester.pumpWidget(ExamApp(controller: controller));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Pilih mode'), findsOneWidget);
    await db.close();
  });

  testWidgets('pemulihan proteksi gagal menahan akses sebelum soal tampil', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
    );
    addTearDown(db.close);
    final a = await seededController(db);
    final created = (await tester.runAsync(
      () => a.createTeacherSession(
        examName: 'Matematika Kelas XI',
        formUrl: Uri.parse('https://docs.google.com/forms/d/e/abc/viewform'),
      ),
    ))!;
    expect((await a.startStudentAttempt(created.session)).started, isTrue);

    final b = await seededController(db, restoreSucceeds: false);
    await tester.pumpWidget(ExamApp(controller: b));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Pemulihan proteksi perangkat diperlukan'),
      findsOneWidget,
    );
    expect(find.text('Pilih mode'), findsNothing);
    expect(find.byType(ProcessRecoveryScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('state attempt rusak menahan beranda untuk penanganan pengawas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
    );
    addTearDown(db.close);
    final a = await seededController(db);
    final created = (await tester.runAsync(
      () => a.createTeacherSession(
        examName: 'Matematika Kelas XI',
        formUrl: Uri.parse('https://docs.google.com/forms/d/e/abc/viewform'),
      ),
    ))!;
    await a.startStudentAttempt(created.session);
    final attempt = await a.loadCurrentAttempt();
    await db.update(
      'attempts',
      {'state': 'tidak_dikenal'},
      where: 'attempt_id = ?',
      whereArgs: [attempt!.attemptId],
    );

    final b = await seededController(db);
    await tester.pumpWidget(ExamApp(controller: b));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Data percobaan tidak dapat dibaca'),
      findsOneWidget,
    );
    expect(find.text('Pilih mode'), findsNothing);
  });
}
