import 'package:examseal/services/exam_protection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'bridge native membaca status dan memulihkan layar pada Android',
    (tester) async {
      final protection = ExamProtection();

      final status = await protection.checkStatus();

      expect(status.supported, isTrue);
      expect(status.secureWindowActive, isFalse);
      expect(status.notificationAccessGranted, isFalse);
      expect(await protection.isReady(), isFalse);
      expect(await protection.activate(), isFalse);
      expect((await protection.checkStatus()).secureWindowActive, isFalse);
      expect(await protection.restore(), isTrue);
      expect((await protection.checkStatus()).secureWindowActive, isFalse);
    },
  );
}
