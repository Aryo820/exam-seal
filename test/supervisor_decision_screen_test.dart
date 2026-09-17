import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/screens/supervisor_decision_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('S07 tanpa PIN: hanya Lanjutkan dan Akhiri, tanpa Mode Guru', (
    tester,
  ) async {
    SupervisorDecision? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.of(context).push<SupervisorDecision>(
                MaterialPageRoute<SupervisorDecision>(
                  builder: (_) => SupervisorDecisionScreen(
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
                    latestViolationReason: 'Batas pelanggaran tercapai.',
                  ),
                ),
              );
            },
            child: const Text('Buka keputusan'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka keputusan'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.text('Lanjutkan Ujian').hitTestable(), findsOneWidget);
    expect(find.text('Akhiri Ujian').hitTestable(), findsOneWidget);
    expect(find.text('Buka Mode Guru'), findsNothing);
    expect(result, isNull);
  });

  testWidgets('S07 requires confirmation before ending the exam', (
    tester,
  ) async {
    SupervisorDecision? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await Navigator.of(context).push<SupervisorDecision>(
                  MaterialPageRoute<SupervisorDecision>(
                    builder: (_) => SupervisorDecisionScreen(
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
                      latestViolationReason: 'Batas pelanggaran tercapai.',
                    ),
                  ),
                );
              },
              child: const Text('Buka keputusan'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka keputusan'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akhiri Ujian').hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Akhiri ujian?'), findsOneWidget);
    expect(result, isNull);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Tentukan penanganan'), findsOneWidget);
    expect(result, isNull);

    await tester.tap(find.text('Akhiri Ujian').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akhiri Ujian').last);
    await tester.pumpAndSettle();

    expect(result, SupervisorDecision.endExam);
    expect(tester.takeException(), isNull);
  });
}
