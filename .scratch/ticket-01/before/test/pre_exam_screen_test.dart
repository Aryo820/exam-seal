import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/screens/pre_exam_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'S03 identifies the session and blocks start while protection is unavailable',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        MaterialApp(
          home: PreExamScreen(
            session: ExamSession(
              schemaVersion: 1,
              sessionId: 's',
              sessionCode: 'MTH-7K2P',
              examName: 'Matematika Kelas XI',
              formUrl: Uri.parse(
                'https://docs.google.com/forms/d/e/example/viewform',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Matematika Kelas XI'), findsOneWidget);
      expect(find.text('MTH-7K2P'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Mulai Ujian'), 300);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Mulai Ujian'),
      );
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
