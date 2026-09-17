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

      await tester.tap(find.text('Buat QR Ujian'));
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

  final session = ExamSession(
    schemaVersion: 3,
    sessionId: 's',
    sessionCode: 'MTH-7K2P',
    examName: 'Matematika Kelas XI',
    formUrl: Uri.parse('https://docs.google.com/forms/d/e/example/viewform'),
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    required Future<String?> Function(ExamSession) onDeleteSession,
  }) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: TeacherSessionsScreen(
          sessions: [session],
          onDeleteSession: onDeleteSession,
        ),
      ),
    );
    await tester.ensureVisible(find.text('Hapus Sesi'));
    await tester.pump();
  }

  testWidgets('T02 menghapus sesi hanya setelah konfirmasi', (tester) async {
    final deleted = <ExamSession>[];
    await pumpScreen(
      tester,
      onDeleteSession: (value) async {
        deleted.add(value);
        return null;
      },
    );

    await tester.tap(find.text('Hapus Sesi'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus sesi ini?'), findsOneWidget);
    expect(find.textContaining('pembatasan pengulangan lokal'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(deleted, isEmpty);
    expect(find.text('Matematika Kelas XI'), findsOneWidget);

    await tester.tap(find.text('Hapus Sesi'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus Sesi'));
    await tester.pumpAndSettle();

    expect(deleted.single, same(session));
    expect(find.text('Matematika Kelas XI'), findsNothing);
    expect(find.text('Belum ada sesi ujian'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kegagalan hapus ditampilkan tanpa menyembunyikan daftar', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      onDeleteSession: (_) async =>
          'Sesi ini masih menahan percobaan siswa yang belum selesai.',
    );

    await tester.tap(find.text('Hapus Sesi'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus Sesi'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sesi ini masih menahan percobaan siswa yang belum selesai.'),
      findsOneWidget,
    );
    expect(find.text('Matematika Kelas XI'), findsOneWidget);
    expect(find.text('Belum ada sesi ujian'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hapus sesi ditahan selama percobaan siswa berlangsung', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var deleteRequested = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TeacherSessionsScreen(
          sessions: [session],
          canCreateSession: false,
          canDeleteSession: false,
          onDeleteSession: (_) async {
            deleteRequested = true;
            return null;
          },
        ),
      ),
    );
    await tester.ensureVisible(find.text('Hapus Sesi'));
    await tester.pump();

    await tester.tap(find.text('Hapus Sesi'));
    await tester.pumpAndSettle();

    expect(deleteRequested, isFalse);
    expect(find.text('Hapus sesi ini?'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
