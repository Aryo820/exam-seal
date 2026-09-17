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
    final approveButton = find.widgetWithText(FilledButton, 'Setujui Selesai');
    await tester.dragUntilVisible(
      approveButton,
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    await tester.tap(approveButton);
    await tester.pumpAndSettle();
    expect(find.text('Akhiri ujian?'), findsOneWidget);
    expect(ended, isFalse);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Persetujuan Selesai'), findsOneWidget);
    expect(ended, isFalse);
    await tester.tap(approveButton);
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
  testWidgets('lifecycle ambigu tidak menghitung pelanggaran atau mengunci', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 884);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var locked = false;
    var registered = 0;
    var ambiguousEvents = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ExamScreen(
          session: session(),
          violationCount: 0,
          violationReason: null,
          registerViolation: (trigger) async {
            registered++;
            return const ViolationResultMsg(
              outcome: ViolationOutcome.locked,
              violationCount: 3,
              reason: 'appLeftWhileActive',
            );
          },
          recordAmbiguousEvent: (_) async {
            ambiguousEvents++;
          },
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
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pumpAndSettle();
    expect(locked, isFalse);
    expect(registered, 0);
    expect(ambiguousEvents, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'status attempt baru memperbarui layar tanpa membuat ulang Form',
    (tester) async {
      var formInitializations = 0;
      Widget screen(int violationCount) => MaterialApp(
        home: ExamScreen(
          key: const ValueKey('exam'),
          session: session(),
          violationCount: violationCount,
          violationReason: 'Aplikasi ditinggalkan.',
          registerViolation: (_) async => const ViolationResultMsg(
            outcome: ViolationOutcome.warned,
            violationCount: 1,
            reason: 'appLeftWhileActive',
          ),
          recordAmbiguousEvent: (_) async {},
          onViolationLock: () async {},
          endAttemptWithAuthorization: () async => true,
          retryRestoreSettings: () => true,
          onReturnHome: () {},
          formContent: _StatefulForm(onInit: () => formInitializations++),
        ),
      );
      await tester.pumpWidget(screen(2));
      expect(formInitializations, 1);
      expect(find.text('Pelanggaran: 2'), findsOneWidget);
      await tester.pumpWidget(screen(3));
      expect(formInitializations, 1);
      expect(find.text('Pelanggaran: 3'), findsOneWidget);
    },
  );
  testWidgets('header ujian aktif tidak membuka mode guru', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExamScreen(
          session: session(),
          violationCount: 0,
          violationReason: null,
          registerViolation: (_) async => const ViolationResultMsg(
            outcome: ViolationOutcome.warned,
            violationCount: 1,
            reason: 'appLeftWhileActive',
          ),
          recordAmbiguousEvent: (_) async {},
          onViolationLock: () async {},
          endAttemptWithAuthorization: () async => true,
          retryRestoreSettings: () => true,
          onReturnHome: () {},
          formContent: const Text('Google Forms'),
        ),
      ),
    );
    expect(find.byTooltip('Mode Guru'), findsNothing);
    expect(find.text('Pelanggaran: 0'), findsOneWidget);
  });
  testWidgets('kepergian lama dihitung sekali dan memicu alert native', (
    tester,
  ) async {
    var now = DateTime(2026, 1, 1);
    var registered = 0;
    var alerts = 0;
    var ambiguousEvents = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ExamScreen(
          session: session(),
          violationCount: 0,
          violationReason: null,
          clock: () => now,
          departureGrace: const Duration(seconds: 2),
          registerViolation: (_) async {
            registered++;
            return ViolationResultMsg(
              outcome: ViolationOutcome.warned,
              violationCount: registered,
              reason: 'appLeftWhileActive',
            );
          },
          recordAmbiguousEvent: (_) async {
            ambiguousEvents++;
          },
          onViolationLock: () async {},
          onWarningAlert: () async {
            alerts++;
          },
          endAttemptWithAuthorization: () async => true,
          retryRestoreSettings: () => true,
          onReturnHome: () {},
          formContent: const Text('Google Forms'),
        ),
      ),
    );
    // Satu kepergian memancarkan beberapa callback: tetap satu hitungan.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    now = now.add(const Duration(seconds: 5));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(registered, 1);
    expect(alerts, 1);
    expect(ambiguousEvents, greaterThanOrEqualTo(1));
    expect(find.text('Peringatan pertama'), findsOneWidget);
    expect(find.text('Pelanggaran: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('kepergian singkat hanya ambigu tanpa hitungan dan alert', (
    tester,
  ) async {
    var now = DateTime(2026, 1, 1);
    var registered = 0;
    var alerts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ExamScreen(
          session: session(),
          violationCount: 0,
          violationReason: null,
          clock: () => now,
          departureGrace: const Duration(seconds: 2),
          registerViolation: (_) async {
            registered++;
            return const ViolationResultMsg(
              outcome: ViolationOutcome.warned,
              violationCount: 1,
              reason: 'appLeftWhileActive',
            );
          },
          recordAmbiguousEvent: (_) async {},
          onViolationLock: () async {},
          onWarningAlert: () async {
            alerts++;
          },
          endAttemptWithAuthorization: () async => true,
          retryRestoreSettings: () => true,
          onReturnHome: () {},
          formContent: const Text('Google Forms'),
        ),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(registered, 0);
    expect(alerts, 0);
    expect(find.text('Pelanggaran: 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('pelanggaran ketiga dari lifecycle memanggil kunci + alert', (
    tester,
  ) async {
    var now = DateTime(2026, 1, 1);
    var locked = false;
    var alerts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ExamScreen(
          session: session(),
          violationCount: 2,
          violationReason: 'Anda meninggalkan layar ujian.',
          clock: () => now,
          departureGrace: const Duration(seconds: 2),
          registerViolation: (_) async => const ViolationResultMsg(
            outcome: ViolationOutcome.locked,
            violationCount: 3,
            reason: 'appLeftWhileActive',
          ),
          recordAmbiguousEvent: (_) async {},
          onViolationLock: () async {
            locked = true;
          },
          onWarningAlert: () async {
            alerts++;
          },
          endAttemptWithAuthorization: () async => true,
          retryRestoreSettings: () => true,
          onReturnHome: () {},
          formContent: const Text('Google Forms'),
        ),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 5));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(locked, isTrue);
    expect(alerts, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('lifecycle tidak dihitung bila attempt sudah tidak aktif', (
    tester,
  ) async {
    var now = DateTime(2026, 1, 1);
    var registered = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ExamScreen(
          session: session(),
          violationCount: 0,
          violationReason: null,
          attemptActive: false,
          clock: () => now,
          departureGrace: const Duration(seconds: 2),
          registerViolation: (_) async {
            registered++;
            return const ViolationResultMsg(
              outcome: ViolationOutcome.warned,
              violationCount: 1,
              reason: 'appLeftWhileActive',
            );
          },
          recordAmbiguousEvent: (_) async {},
          onViolationLock: () async {},
          endAttemptWithAuthorization: () async => true,
          retryRestoreSettings: () => true,
          onReturnHome: () {},
          formContent: const Text('Google Forms'),
        ),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 5));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(registered, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('keluar disengaja dihitung walau kembali dengan cepat', (
    tester,
  ) async {
    var now = DateTime(2026, 1, 1);
    var registered = 0;
    var alerts = 0;
    final exitSignal = ValueNotifier<int>(0);
    addTearDown(exitSignal.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ExamScreen(
          session: session(),
          violationCount: 0,
          violationReason: null,
          clock: () => now,
          departureGrace: const Duration(seconds: 2),
          userExitSignal: exitSignal,
          registerViolation: (_) async {
            registered++;
            return ViolationResultMsg(
              outcome: ViolationOutcome.warned,
              violationCount: registered,
              reason: 'appLeftWhileActive',
            );
          },
          recordAmbiguousEvent: (_) async {},
          onViolationLock: () async {},
          onWarningAlert: () async {
            alerts++;
          },
          endAttemptWithAuthorization: () async => true,
          retryRestoreSettings: () => true,
          onReturnHome: () {},
          formContent: const Text('Google Forms'),
        ),
      ),
    );
    // Sinyal native tiba dulu (urutan asinkron versi 1) ...
    exitSignal.value++;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    // ... kembali sebelum ambang 2 detik: tetap dihitung karena disengaja.
    now = now.add(const Duration(milliseconds: 500));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(registered, 1);
    expect(alerts, 1);
    expect(find.text('Peringatan pertama'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('sinyal di tengah kepergian tetap mengonfirmasi hitungan', (
    tester,
  ) async {
    var now = DateTime(2026, 1, 1);
    var registered = 0;
    final exitSignal = ValueNotifier<int>(0);
    addTearDown(exitSignal.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ExamScreen(
          session: session(),
          violationCount: 0,
          violationReason: null,
          clock: () => now,
          departureGrace: const Duration(seconds: 2),
          userExitSignal: exitSignal,
          registerViolation: (_) async {
            registered++;
            return ViolationResultMsg(
              outcome: ViolationOutcome.warned,
              violationCount: registered,
              reason: 'appLeftWhileActive',
            );
          },
          recordAmbiguousEvent: (_) async {},
          onViolationLock: () async {},
          endAttemptWithAuthorization: () async => true,
          retryRestoreSettings: () => true,
          onReturnHome: () {},
          formContent: const Text('Google Forms'),
        ),
      ),
    );
    // Urutan asinkron versi 2: lifecycle dulu, sinyal menyusul.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    exitSignal.value++;
    now = now.add(const Duration(milliseconds: 500));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(registered, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unpin paksa dihitung walau kembali dengan cepat', (
    tester,
  ) async {
    var now = DateTime(2026, 1, 1);
    var registered = 0;
    var alerts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ExamScreen(
          session: session(),
          violationCount: 0,
          violationReason: null,
          clock: () => now,
          departureGrace: const Duration(seconds: 2),
          isScreenPinned: () async => false,
          registerViolation: (_) async {
            registered++;
            return ViolationResultMsg(
              outcome: ViolationOutcome.warned,
              violationCount: registered,
              reason: 'appLeftWhileActive',
            );
          },
          recordAmbiguousEvent: (_) async {},
          onViolationLock: () async {},
          onWarningAlert: () async {
            alerts++;
          },
          endAttemptWithAuthorization: () async => true,
          retryRestoreSettings: () => true,
          onReturnHome: () {},
          formContent: const Text('Google Forms'),
        ),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(milliseconds: 500));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(registered, 1);
    expect(alerts, 1);
    expect(find.text('Peringatan pertama'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unpin paksa langsung mengunci tanpa jalur normal', (
    tester,
  ) async {
    var now = DateTime(2026, 1, 1);
    var normalRegistered = 0;
    var severeRegistered = 0;
    var locked = false;
    var alerts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ExamScreen(
          session: session(),
          violationCount: 0,
          violationReason: null,
          clock: () => now,
          departureGrace: const Duration(seconds: 2),
          isScreenPinned: () async => false,
          registerViolation: (_) async {
            normalRegistered++;
            return ViolationResultMsg(
              outcome: ViolationOutcome.warned,
              violationCount: normalRegistered,
              reason: 'appLeftWhileActive',
            );
          },
          registerSevereViolation: (_) async {
            severeRegistered++;
            return const ViolationResultMsg(
              outcome: ViolationOutcome.locked,
              violationCount: 3,
              reason: 'Anda melepas kunci layar ujian.',
            );
          },
          recordAmbiguousEvent: (_) async {},
          onViolationLock: () async {
            locked = true;
          },
          onWarningAlert: () async {
            alerts++;
          },
          endAttemptWithAuthorization: () async => true,
          retryRestoreSettings: () => true,
          onReturnHome: () {},
          formContent: const Text('Google Forms'),
        ),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(milliseconds: 500));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(severeRegistered, 1);
    expect(normalRegistered, 0);
    expect(locked, isTrue);
    expect(alerts, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('pin utuh dan singkat tetap ambigu tanpa hitungan', (
    tester,
  ) async {
    var now = DateTime(2026, 1, 1);
    var registered = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ExamScreen(
          session: session(),
          violationCount: 0,
          violationReason: null,
          clock: () => now,
          departureGrace: const Duration(seconds: 2),
          isScreenPinned: () async => true,
          registerViolation: (_) async {
            registered++;
            return const ViolationResultMsg(
              outcome: ViolationOutcome.warned,
              violationCount: 1,
              reason: 'appLeftWhileActive',
            );
          },
          recordAmbiguousEvent: (_) async {},
          onViolationLock: () async {},
          endAttemptWithAuthorization: () async => true,
          retryRestoreSettings: () => true,
          onReturnHome: () {},
          formContent: const Text('Google Forms'),
        ),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(milliseconds: 500));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(registered, 0);
    expect(find.text('Pelanggaran: 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('dua kepergian disengaja dihitung dua kali', (tester) async {
    var now = DateTime(2026, 1, 1);
    var registered = 0;
    final exitSignal = ValueNotifier<int>(0);
    addTearDown(exitSignal.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ExamScreen(
          session: session(),
          violationCount: 0,
          violationReason: null,
          clock: () => now,
          departureGrace: const Duration(seconds: 2),
          userExitSignal: exitSignal,
          registerViolation: (_) async {
            registered++;
            return ViolationResultMsg(
              outcome: ViolationOutcome.warned,
              violationCount: registered,
              reason: 'appLeftWhileActive',
            );
          },
          recordAmbiguousEvent: (_) async {},
          onViolationLock: () async {},
          endAttemptWithAuthorization: () async => true,
          retryRestoreSettings: () => true,
          onReturnHome: () {},
          formContent: const Text('Google Forms'),
        ),
      ),
    );
    for (var i = 0; i < 2; i++) {
      exitSignal.value++;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(const Duration(milliseconds: 500));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kembali ke Ujian'));
      await tester.pumpAndSettle();
    }

    expect(registered, 2);
    expect(find.text('Pelanggaran: 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _StatefulForm extends StatefulWidget {
  const _StatefulForm({required this.onInit});
  final VoidCallback onInit;
  @override
  State<_StatefulForm> createState() => _StatefulFormState();
}

class _StatefulFormState extends State<_StatefulForm> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const Text('Google Forms');
}
