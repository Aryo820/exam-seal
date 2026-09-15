import 'package:examseal/services/exam_protection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('examseal/protection');

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test(
    'preflight tidak menuntut FLAG_SECURE sebelum Mulai lalu memverifikasi aktivasi',
    () async {
      final statuses = <Map<String, Object?>>[
        _status(secure: false, dnd: false),
        _status(secure: false, dnd: false),
        _status(secure: true, dnd: true),
      ];
      var activateCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'checkStatus') return statuses.removeAt(0);
            if (call.method == 'activate') return activateCalls++ == 0;
            fail('Panggilan tak terduga: ${call.method}');
          });
      final protection = ExamProtection();

      expect(await protection.isReady(), isTrue);
      expect(protection.screenProtectionReady, isTrue);
      expect(await protection.activate(), isTrue);
    },
  );

  test(
    'aktivasi yang tidak terbukti memulihkan native dan tetap gagal',
    () async {
      final statuses = <Map<String, Object?>>[
        _status(secure: false, dnd: false),
        _status(secure: false, dnd: false),
        _status(secure: false, dnd: false),
      ];
      var restoreCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'checkStatus') return statuses.removeAt(0);
            if (call.method == 'activate') return true;
            if (call.method == 'restore') {
              restoreCalls++;
              return true;
            }
            fail('Panggilan tak terduga: ${call.method}');
          });

      expect(await ExamProtection().activate(), isFalse);
      expect(restoreCalls, 1);
    },
  );

  test('pemulihan gagal bila FLAG_SECURE masih terpasang', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'restore') {
            return true;
          }
          if (call.method == 'checkStatus') {
            return _status(secure: true, dnd: true);
          }
          fail('Panggilan tak terduga: ${call.method}');
        });

    expect(await ExamProtection().restore(), isFalse);
  });
}

Map<String, Object?> _status({required bool secure, required bool dnd}) => {
  'supported': true,
  'secureWindowActive': secure,
  'notificationAccessGranted': true,
  'notificationProtectionActive': dnd,
};
