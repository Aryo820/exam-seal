import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/screens/locked_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('locked exam opens supervisor decision without PIN', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LockedScreen(
          session: ExamSession(
            schemaVersion: 3,
            sessionId: 's',
            sessionCode: 'MTH-7K2P',
            examName: 'Matematika Kelas XI',
            formUrl: Uri.parse(
              'https://docs.google.com/forms/d/e/example/viewform',
            ),
          ),
          violationCount: 3,
          violationReason: 'Batas pelanggaran tercapai.',
          onContinueExam: () {},
          onEndExam: () {},
        ),
      ),
    );

    expect(find.text('Ujian dikunci'), findsOneWidget);
    await tester.tap(find.text('Panggil Pengawas'));
    await tester.pumpAndSettle();
    expect(find.text('Tentukan penanganan'), findsOneWidget);
  });
}
