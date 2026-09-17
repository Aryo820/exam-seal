import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/screens/pre_exam_screen.dart';
import 'package:examseal/services/exam_session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ExamSession session() => ExamSession(
    schemaVersion: 2,
    sessionId: 's',
    sessionCode: 'MTH-7K2P',
    examName: 'Matematika Kelas XI',
    formUrl: Uri.parse('https://docs.google.com/forms/d/e/example/viewform'),
  );

  Widget screen({
    required Future<ReadinessReport> Function() readiness,
    required Future<bool> Function() onStart,
    Future<void> Function()? onOpenNotificationSettings,
  }) => MaterialApp(
    home: PreExamScreen(
      session: session(),
      loadReadiness: readiness,
      onOpenNotificationSettings: onOpenNotificationSettings ?? () async {},
      onStart: onStart,
    ),
  );

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
        screen(
          readiness: () async => const ReadinessReport(
            qrValid: true,
            urlValid: true,
            storageWritable: true,
            screenProtectionReady: false,
            notificationControlReady: false,
          ),
          onStart: () async => true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Matematika Kelas XI'), findsOneWidget);
      expect(find.text('MTH-7K2P'), findsOneWidget);

      // Readiness nyata: proteksi belum tersedia â†’ tombol nonaktif.
      await tester.scrollUntilVisible(
        find.text('Akses belum diberikan'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Akses belum diberikan'), findsOneWidget);
      expect(find.text('Belum tersedia'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Mulai Ujian'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Mulai Ujian'),
      );
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('start button enables and starts once every check passes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var started = 0;
    await tester.pumpWidget(
      screen(
        readiness: () async => const ReadinessReport(
          qrValid: true,
          urlValid: true,
          storageWritable: true,
          screenProtectionReady: true,
          notificationControlReady: true,
        ),
        onStart: () async {
          started++;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Mulai Ujian'), 300);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Mulai Ujian'),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.text('Mulai Ujian'));
    await tester.pumpAndSettle();
    expect(started, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed start surfaces an actionable message and no retry loop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      screen(
        readiness: () async => const ReadinessReport(
          qrValid: true,
          urlValid: true,
          storageWritable: true,
          screenProtectionReady: true,
          notificationControlReady: true,
        ),
        onStart: () async => false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Mulai Ujian'), 300);
    await tester.tap(find.text('Mulai Ujian'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Perangkat belum siap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kembali dari pengaturan memeriksa ulang akses notifikasi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var notificationAccessGranted = false;
    Future<ReadinessReport> readiness() async => ReadinessReport(
      qrValid: true,
      urlValid: true,
      storageWritable: true,
      screenProtectionReady: true,
      notificationControlReady: notificationAccessGranted,
    );

    await tester.pumpWidget(
      screen(
        readiness: readiness,
        onStart: () async => true,
        onOpenNotificationSettings: () async {
          notificationAccessGranted = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Buka Pengaturan'), 300);
    await tester.tap(find.text('Buka Pengaturan'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Akses diberikan; diuji lagi saat mulai'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Mulai Ujian'), 300);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Mulai Ujian'),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
