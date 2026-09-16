import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/screens/supervisor_pin_access_screen.dart';
import 'package:examseal/services/local_auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:local_auth/local_auth.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('perangkat mendukung kunci layar untuk akses PIN', (
    tester,
  ) async {
    expect(
      await LocalAuthentication().isDeviceSupported(),
      isTrue,
      reason:
          'Atur PIN, pola, atau sandi layar HP sebelum membuka PIN pengawas.',
    );
  });

  testWidgets('kunci layar perangkat membuka PIN pengawas', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SupervisorPinAccessScreen(
          session: ExamSession(
            schemaVersion: 2,
            sessionId: 'local-auth-device-test',
            sessionCode: 'AUTH-TEST',
            examName: 'Uji autentikasi perangkat',
            formUrl: Uri.parse('https://forms.gle/test'),
          ),
          authenticateDevice: LocalAuthGate.authenticate,
          readPin: () => '12345',
        ),
      ),
    );

    await tester.tap(find.text('Autentikasi Kunci Layar HP'));
    final deadline = DateTime.now().add(const Duration(minutes: 3));
    while (DateTime.now().isBefore(deadline) &&
        find.text('1 2 3 4 5').evaluate().isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await tester.pump();
    }

    expect(find.text('1 2 3 4 5'), findsOneWidget);
  });
}
