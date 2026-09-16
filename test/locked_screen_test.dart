import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/screens/locked_screen.dart';
import 'package:examseal/screens/supervisor_pin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('S06 hides the exam and exposes only supervisor PIN action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LockedScreen(
          session: ExamSession(
            schemaVersion: 1,
            sessionId: 's',
            sessionCode: 'MTH-7K2P',
            examName: 'Matematika Kelas XI',
            formUrl: Uri.parse(
              'https://docs.google.com/forms/d/e/example/viewform',
            ),
          ),
          violationCount: 3,
          violationReason:
              'Batas pelanggaran tercapai. Ujian hanya dapat dibuka oleh pengawas.',
          verifySupervisorPin: (pin) => pin == '01234',
          onContinueExam: () => continued = true,
          onEndExam: () {},
        ),
      ),
    );

    expect(find.text('Ujian dikunci'), findsOneWidget);
    expect(find.text('Pelanggaran: 3'), findsOneWidget);
    expect(find.text('Matematika Kelas XI'), findsOneWidget);
    expect(find.textContaining('MTH-7K2P'), findsOneWidget);
    expect(find.text('Google Forms'), findsNothing);
    expect(find.byType(BackButton), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PIN Pengawas').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Periksa ujian terkunci'), findsOneWidget);

    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '01234');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.ensureVisible(find.text('Verifikasi PIN'));
    await tester.tap(find.text('Verifikasi PIN'));
    await tester.pumpAndSettle();
    expect(find.text('Tentukan penanganan'), findsOneWidget);
    expect(find.text('Jumlah pelanggaran'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    final continueButton = find.widgetWithText(FilledButton, 'Lanjutkan Ujian');
    await tester.dragUntilVisible(
      continueButton,
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    await tester.ensureVisible(continueButton);
    await tester.pump();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(continued, isTrue);
    expect(find.text('Ujian dikunci'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Ujian dikunci'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PIN blocks verification for 30 seconds after five failures', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SupervisorPinScreen(verifyPin: (_) => false)),
    );

    for (var attempt = 0; attempt < 5; attempt++) {
      await tester.enterText(find.byType(TextField), '11111');
      tester.testTextInput.hide();
      await tester.pump();
      await tester.ensureVisible(find.text('Verifikasi PIN'));
      await tester.tap(find.text('Verifikasi PIN'));
      await tester.pump();
    }

    expect(find.textContaining('Terlalu banyak percobaan'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

    await tester.pump(const Duration(seconds: 30));
    expect(find.textContaining('Terlalu banyak percobaan'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back dari keputusan membatalkan otorisasi pengawas', (
    tester,
  ) async {
    var authorizationCancelled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LockedScreen(
          session: ExamSession(
            schemaVersion: 1,
            sessionId: 's',
            sessionCode: 'MTH-7K2P',
            examName: 'Matematika Kelas XI',
            formUrl: Uri.parse(
              'https://docs.google.com/forms/d/e/example/viewform',
            ),
          ),
          violationCount: 3,
          violationReason: 'Batas pelanggaran tercapai.',
          verifySupervisorPin: (pin) => pin == '01234',
          onContinueExam: () {},
          onEndExam: () {},
          onAuthorizationCancelled: () => authorizationCancelled = true,
        ),
      ),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PIN Pengawas').hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '01234');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.tap(find.text('Verifikasi PIN'));
    await tester.pumpAndSettle();
    expect(find.text('Tentukan penanganan'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Ujian dikunci'), findsOneWidget);
    expect(authorizationCancelled, isTrue);
  });
}
