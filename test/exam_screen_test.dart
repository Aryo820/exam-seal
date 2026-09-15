import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/screens/exam_screen.dart';
import 'package:examseal/services/attempt_state_machine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ExamSession session() => ExamSession(
    schemaVersion: 2,
    sessionId: 's',
    sessionCode: 'MTH-7K2P',
    examName: 'Matematika Kelas XI',
    formUrl: Uri.parse('https://docs.google.com/forms/d/e/example/viewform'),
    pinSalt: 'c2FsdA==',
    pinVerifier: 'dmVyaWZpZXI=',
  );

  testWidgets('S04 keeps the exam visible until supervisor approval', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 884);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final protectionNotice = ValueNotifier<String?>(null);
    addTearDown(protectionNotice.dispose);

    var ended = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ExamScreen(
          session: session(),
          violationCount: 0,
          violationReason: null,
          verifySupervisorPin: (pin) => pin == '01234',
          cancelEndAuthorization: () {},
          registerViolation: (trigger) async => const ViolationResultMsg(
            outcome: ViolationOutcome.warned,
            violationCount: 1,
            reason: 'trigger',
          ),
          recordAmbiguousEvent: (_) async {},
          onViolationLock: () async {},
          endAttemptWithAuthorization: () async {
            ended = true;
            return true;
          },
          retryRestoreSettings: () => true,
          onReturnHome: () {},
          formContent: const ColoredBox(
            color: Colors.white,
            child: Center(child: Text('Google Forms')),
          ),
          protectionNotice: protectionNotice,
        ),
      ),
    );

    expect(find.text('Matematika Kelas XI'), findsOneWidget);
    expect(find.text('MTH-7K2P'), findsOneWidget);
    expect(find.text('Pelanggaran: 0'), findsOneWidget);
    expect(find.text('Google Forms'), findsOneWidget);
    protectionNotice.value =
        'Proteksi perangkat tidak lagi aktif. Minta pengawas menangani perangkat ini.';
    await tester.pump();
    expect(
      find.textContaining('Proteksi perangkat tidak lagi aktif'),
      findsOneWidget,
    );

    await tester.tap(find.text('Minta Persetujuan Selesai'));
    await tester.pumpAndSettle();

    expect(find.text('Tetap di tempat dan angkat tangan.'), findsOneWidget);
    expect(
      find.textContaining('ExamSeal tidak dapat memastikan'),
      findsOneWidget,
    );
    expect(ended, isFalse);

    await tester.tap(find.text('Kembali ke Ujian'));
    await tester.pumpAndSettle();
    expect(find.text('Google Forms'), findsOneWidget);
    expect(ended, isFalse);

    await tester.tap(find.text('Minta Persetujuan Selesai'));
    await tester.pumpAndSettle();
    final pinButton = find.widgetWithText(FilledButton, 'PIN Pengawas');
    await tester.dragUntilVisible(
      pinButton,
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    await tester.tap(pinButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '01234');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.ensureVisible(find.text('Verifikasi PIN'));
    await tester.tap(find.text('Verifikasi PIN'));
    await tester.pumpAndSettle();

    expect(find.text('Akhiri ujian?'), findsOneWidget);
    expect(ended, isFalse);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Persetujuan Selesai'), findsOneWidget);
    expect(ended, isFalse);

    await tester.tap(pinButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '01234');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.ensureVisible(find.text('Verifikasi PIN'));
    await tester.tap(find.text('Verifikasi PIN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akhiri Ujian'));
    await tester.pumpAndSettle();
    expect(ended, isTrue);
    expect(find.text('Sesi ujian berakhir'), findsOneWidget);
    expect(
      find.text('Pengaturan perangkat berhasil dipulihkan.'),
      findsOneWidget,
    );
    expect(find.text('Google Forms'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('S05 blocks the exam until the warning is acknowledged', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 884);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ExamScreen(
          session: session(),
          violationCount: 1,
          violationReason: 'Anda meninggalkan layar ujian.',
          verifySupervisorPin: (_) => false,
          cancelEndAuthorization: () {},
          registerViolation: (trigger) async => const ViolationResultMsg(
            outcome: ViolationOutcome.warned,
            violationCount: 1,
            reason: 'trigger',
          ),
          recordAmbiguousEvent: (_) async {},
          onViolationLock: () async {},
          endAttemptWithAuthorization: () async => true,
          retryRestoreSettings: () => true,
          onReturnHome: () {},
          formContent: const ColoredBox(
            color: Colors.white,
            child: Center(child: Text('Google Forms')),
          ),
        ),
      ),
    );

    expect(find.text('Peringatan pertama'), findsOneWidget);
    expect(find.text('Pelanggaran: 1'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Peringatan pertama'), findsOneWidget);

    await tester.tap(find.text('Kembali ke Ujian'));
    await tester.pumpAndSettle();
    expect(find.text('Peringatan pertama'), findsNothing);
    expect(find.text('Google Forms'), findsOneWidget);
    expect(find.text('Pelanggaran: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('third violation hides the exam and calls the lock route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 884);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var locked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ExamScreen(
          session: session(),
          violationCount: 0,
          violationReason: null,
          verifySupervisorPin: (_) => false,
          cancelEndAuthorization: () {},
          registerViolation: (trigger) async => const ViolationResultMsg(
            outcome: ViolationOutcome.locked,
            violationCount: 3,
            reason: 'appLeftWhileActive',
          ),
          recordAmbiguousEvent: (_) async {},
          onViolationLock: () async {
            locked = true;
          },
          endAttemptWithAuthorization: () async => true,
          retryRestoreSettings: () => true,
          onReturnHome: () {},
          formContent: const ColoredBox(
            color: Colors.white,
            child: Center(child: Text('Google Forms')),
          ),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    expect(locked, isTrue);
    expect(tester.takeException(), isNull);
  });
}
