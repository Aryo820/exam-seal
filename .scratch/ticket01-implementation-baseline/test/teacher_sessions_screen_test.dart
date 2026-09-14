import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/screens/teacher_sessions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'T01 lists local sessions and exposes create and same-QR actions',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var createRequested = false;
      ExamSession? qrSession;
      final session = ExamSession(
        schemaVersion: 1,
        sessionId: 's',
        sessionCode: 'MTH-7K2P',
        examName: 'Matematika Kelas XI',
        formUrl: Uri.parse(
          'https://docs.google.com/forms/d/e/example/viewform',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TeacherSessionsScreen(
            sessions: [session],
            onCreateSession: () => createRequested = true,
            onShowQr: (value) => qrSession = value,
          ),
        ),
      );

      expect(find.text('Matematika Kelas XI'), findsOneWidget);
      expect(find.text('Kode sesi: MTH-7K2P'), findsOneWidget);
      expect(find.textContaining('pemantauan siswa'), findsOneWidget);
      expect(find.textContaining('siswa online'), findsNothing);

      await tester.tap(find.text('Buat Sesi Baru'));
      expect(createRequested, isTrue);

    await tester.scrollUntilVisible(
      find.text('Tampilkan QR'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Tampilkan QR'));
    await tester.pump();
    await tester.tap(find.text('Tampilkan QR'));
      expect(qrSession, same(session));
      expect(tester.takeException(), isNull);
    },
  );
}
