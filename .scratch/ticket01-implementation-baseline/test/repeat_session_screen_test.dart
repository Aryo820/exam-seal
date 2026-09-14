import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/screens/repeat_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('S11 creates a new attempt only after PIN and confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool? approved;
    var repeated = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  approved = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => RepeatSessionScreen(
                        session: ExamSession(
                          schemaVersion: 2,
                          sessionId: 's',
                          sessionCode: 'MTH-7K2P',
                          examName: 'Matematika Kelas XI',
                          formUrl: Uri.parse(
                            'https://docs.google.com/forms/d/e/example/viewform',
                          ),
                          pinSalt: 'c2FsdA==',
                          pinVerifier: 'dmVyaWZpZXI=',
                        ),
                        previousViolationCount: 2,
                        verifySupervisorPin: (pin) => pin == '01234',
                        onRepeatApproved: () async => repeated++,
                      ),
                    ),
                  );
                },
                child: const Text('Buka S11'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka S11'));
    await tester.pumpAndSettle();
    expect(find.text('Sesi ini sudah diakhiri'), findsOneWidget);
    expect(find.text('Pelanggaran: 2'), findsOneWidget);
    expect(approved, isNull);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PIN Pengawas').hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '01234');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.tap(find.text('Verifikasi PIN'));
    await tester.pumpAndSettle();

    expect(find.text('Buat attempt baru?'), findsOneWidget);
    expect(approved, isNull);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Sesi ini sudah diakhiri'), findsOneWidget);
    expect(approved, isNull);

    await tester.tap(find.text('PIN Pengawas').hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '01234');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.tap(find.text('Verifikasi PIN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat Attempt Baru'));
    await tester.pumpAndSettle();

    expect(approved, isTrue);
    expect(repeated, 1);
    expect(tester.takeException(), isNull);
  });
}
