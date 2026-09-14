import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/screens/ended_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('S09 blocks home until pending settings are restored', (
    tester,
  ) async {
    var returnedHome = false;
    await tester.pumpWidget(
      MaterialApp(
        home: EndedScreen(
          session: ExamSession(
            schemaVersion: 1,
            sessionId: 's',
            sessionCode: 'MTH-7K2P',
            examName: 'Matematika Kelas XI',
            formUrl: Uri.parse(
              'https://docs.google.com/forms/d/e/example/viewform',
            ),
          ),
          endReason: 'Diakhiri pengawas.',
          settingsRestored: false,
          retryRestoreSettings: () => true,
          onReturnHome: () => returnedHome = true,
        ),
      ),
    );

    expect(
      find.text('Pengaturan perangkat belum selesai dipulihkan.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Kembali ke Beranda'),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Coba Pulihkan Lagi'));
    await tester.pumpAndSettle();
    expect(
      find.text('Pengaturan perangkat berhasil dipulihkan.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Kembali ke Beranda'));
    expect(returnedHome, isTrue);
    expect(tester.takeException(), isNull);
  });
}
