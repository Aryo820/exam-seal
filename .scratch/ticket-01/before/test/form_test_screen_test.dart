import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/screens/form_test_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('T03 enables QR only after test and manual confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var testRuns = 0;
    var readySaves = 0;
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => FormTestScreen(
                        session: ExamSession(
                          schemaVersion: 1,
                          sessionId: 's',
                          sessionCode: 'MTH-7K2P',
                          examName: 'Matematika Kelas XI',
                          formUrl: Uri.parse(
                            'https://docs.google.com/forms/d/e/example/viewform',
                          ),
                        ),
                        runFormTest: () {
                          testRuns++;
                          return true;
                        },
                        confirmFormReady: () {
                          readySaves++;
                          return true;
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Buka T03'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka T03'));
    await tester.pumpAndSettle();
    final confirmButton = find.widgetWithText(
      FilledButton,
      'Konfirmasi Form Siap',
    );
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

    await tester.ensureVisible(find.text('Buka Uji Form'));
    await tester.tap(find.text('Buka Uji Form'));
    await tester.pump();
    expect(testRuns, 1);

    for (var index = 0; index < 6; index++) {
      final checkbox = find.byType(Checkbox).at(index);
      await tester.ensureVisible(checkbox);
      await tester.pump();
      await tester.tap(checkbox);
      await tester.pump();
    }

    await tester.ensureVisible(confirmButton);
    await tester.pump();
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(readySaves, 1);
    expect(result, isTrue);
    expect(tester.takeException(), isNull);
  });
}
