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

  test('exam guard start/stop diteruskan ke native apa adanya', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return true;
        });
    final protection = ExamProtection();

    expect(await protection.startExamGuard(), isTrue);
    expect(await protection.stopExamGuard(), isTrue);
    expect(await protection.isExamGuardActive(), isTrue);
    expect(calls, ['startExamGuard', 'stopExamGuard', 'isExamGuardActive']);
  });

  test('peringatan native dijepit ke batas FR10 dan gagal dengan aman', () async {
    Object? lastArgs;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'vibrateWarning' ||
              call.method == 'playWarningSound') {
            lastArgs = call.arguments;
            return true;
          }
          if (call.method == 'stopWarningSound') return true;
          fail('Panggilan tak terduga: ${call.method}');
        });
    final protection = ExamProtection();

    // Melebihi 3000ms harus dijepit, bukan diteruskan mentah.
    expect(await protection.vibrateWarning(durationMs: 5000), isTrue);
    expect((lastArgs as Map)['durationMs'], ExamProtection.maxAlertMs);
    expect(await protection.playWarningSound(durationMs: 5000), isTrue);
    expect((lastArgs as Map)['durationMs'], ExamProtection.maxAlertMs);
    expect(await protection.stopWarningSound(), isTrue);
  });

  test('peringatan native false bila bridge tidak tersedia', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    final protection = ExamProtection();

    expect(await protection.startExamGuard(), isFalse);
    expect(await protection.vibrateWarning(), isFalse);
    expect(await protection.playWarningSound(), isFalse);
  });

  test('screen pin diteruskan ke native apa adanya', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return true;
        });
    final protection = ExamProtection();

    expect(await protection.requestScreenPin(), isTrue);
    expect(await protection.stopScreenPin(), isTrue);
    expect(await protection.isScreenPinned(), isTrue);
    expect(calls, ['requestScreenPin', 'stopScreenPin', 'isScreenPinned']);
  });

  test('screen pin false bila bridge tidak tersedia', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    final protection = ExamProtection();

    expect(await protection.requestScreenPin(), isFalse);
    expect(await protection.stopScreenPin(), isFalse);
    expect(await protection.isScreenPinned(), isFalse);
  });

  test('GuardEvent hanya menerima payload event yang dikenal', () {
    final valid = GuardEvent.fromMap({
      'type': 'appBackgrounded',
      'atMillis': 123,
      'detail': 'activity paused',
    });
    expect(valid, isNotNull);
    expect(valid!.type, 'appBackgrounded');
    expect(valid.atMillis, 123);
    expect(valid.detail, 'activity paused');

    expect(GuardEvent.fromMap(null), isNull);
    expect(GuardEvent.fromMap('bukan map'), isNull);
    expect(GuardEvent.fromMap({'type': '', 'atMillis': 1}), isNull);
    expect(GuardEvent.fromMap({'type': 'x'}), isNull);
    expect(
      GuardEvent.fromMap({'type': 'x', 'atMillis': 'bukan int'}),
      isNull,
    );
  });
}

Map<String, Object?> _status({required bool secure, required bool dnd}) => {
  'supported': true,
  'secureWindowActive': secure,
  'notificationAccessGranted': true,
  'notificationProtectionActive': dnd,
};
