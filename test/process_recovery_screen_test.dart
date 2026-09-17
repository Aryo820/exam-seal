import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/screens/process_recovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('S10 requires supervisor decision without adding a violation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ProcessRecoveryScreen(
          session: ExamSession(
            schemaVersion: 1,
            sessionId: 's',
            sessionCode: 'MTH-7K2P',
            examName: 'Matematika Kelas XI',
            formUrl: Uri.parse(
              'https://docs.google.com/forms/d/e/example/viewform',
            ),
          ),
          violationCount: 2,
          onContinueExam: () => continued = true,
          onEndExam: () {},
        ),
      ),
    );

    expect(find.text('Ujian perlu pemeriksaan pengawas'), findsOneWidget);
    expect(find.text('Pelanggaran tersimpan: 2'), findsOneWidget);
    expect(
      find.text('Pemulihan ini tidak menambah pelanggaran baru.'),
      findsOneWidget,
    );
    expect(find.byType(BackButton), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    final supervisorButton = find.text('Panggil Pengawas').hitTestable();
    await tester.ensureVisible(supervisorButton);
    await tester.tap(supervisorButton);
    await tester.pumpAndSettle();

    expect(find.text('Menunggu pemeriksaan'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
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
    expect(find.text('Pelanggaran tersimpan: 2'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Ujian perlu pemeriksaan pengawas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
