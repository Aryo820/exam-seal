import 'package:flutter_test/flutter_test.dart';

import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/services/attempt_state_machine.dart';

void main() {
  final session = ExamSession(
    schemaVersion: 2,
    sessionId: 'session-1',
    sessionCode: 'MTK-7K2P',
    examName: 'Matematika Kelas XI',
    formUrl: Uri.parse('https://docs.google.com/forms/d/e/abc/viewform'),
    pinSalt: 'c2FsdA==',
    pinVerifier: 'dmVyaWZpZXI=',
  );

  test('attempt starts in preExam and can be activated once', () {
    final machine = AttemptStateMachine(initialViolationCount: 0);
    expect(machine.state, AttemptState.preExam);

    final result = machine.start();
    expect(result, isTrue);
    expect(machine.state, AttemptState.active);
    expect(machine.violationCount, 0);

    // preExam hanya sekali: setelah aktif, start tidak valid lagi.
    expect(machine.start(), isFalse);
    expect(machine.state, AttemptState.active);
  });

  test('first and second violations warn; third locks and persists first', () {
    final machine = AttemptStateMachine(initialViolationCount: 0);
    machine.start();

    final first = machine.registerViolation(reason: 'Aplikasi ditinggalkan');
    expect(first, ViolationOutcome.warned);
    expect(machine.violationCount, 1);
    expect(machine.state, AttemptState.active);

    final second = machine.registerViolation(reason: 'Aplikasi ditinggalkan');
    expect(second, ViolationOutcome.warned);
    expect(machine.violationCount, 2);
    expect(machine.state, AttemptState.active);

    final third = machine.registerViolation(reason: 'Aplikasi ditinggalkan');
    expect(third, ViolationOutcome.locked);
    expect(machine.violationCount, 3);
    expect(machine.state, AttemptState.locked);
  });

  test('violation on locked attempt re-locks immediately without a new grant of chances', () {
    final machine = AttemptStateMachine(initialViolationCount: 3);
    machine.restore(AttemptState.locked);
    machine.continueBySupervisor();

    expect(machine.state, AttemptState.active);
    expect(machine.violationCount, 3);

    final next = machine.registerViolation(reason: 'Aplikasi ditinggalkan');
    expect(next, ViolationOutcome.locked);
    expect(machine.violationCount, 4);
    expect(machine.state, AttemptState.locked);
  });

  test('supervisor can continue or end a locked attempt; counter and history stay', () {
    final machine = AttemptStateMachine(initialViolationCount: 3);
    machine.restore(AttemptState.locked);

    expect(machine.continueBySupervisor(), isTrue);
    expect(machine.state, AttemptState.active);
    expect(machine.violationCount, 3);

    // Ulang: kunci lagi lalu akhiri.
    machine.registerViolation(reason: 'Aplikasi ditinggalkan');
    expect(machine.endBySupervisor(reason: 'Dihentikan pengawas'), isTrue);
    expect(machine.state, AttemptState.ended);
  });

  test('active attempt cannot be overwritten by a new scan; ended can only be repeated by supervisor', () {
    final machine = AttemptStateMachine(initialViolationCount: 0);
    machine.start();

    // Scan baru saat aktif: tidak boleh menimpa.
    expect(machine.start(), isFalse);
    expect(machine.state, AttemptState.active);

    machine.endBySupervisor(reason: 'Selesai diperiksa pengawas');
    expect(machine.state, AttemptState.ended);

    // Ended hanya bisa diulang oleh pengawas.
    expect(machine.repeatBySupervisor(), isTrue);
    expect(machine.state, AttemptState.active);
    expect(machine.violationCount, 0);
  });

  test('ambiguous events never increase the counter', () {
    final machine = AttemptStateMachine(initialViolationCount: 0);
    machine.start();

    expect(machine.recordEvent(type: 'incomingCall'), isFalse);
    expect(machine.recordEvent(type: 'networkLost'), isFalse);
    expect(machine.recordEvent(type: 'focusLost'), isFalse);
    expect(machine.violationCount, 0);
    expect(machine.state, AttemptState.active);
  });

  test('process death on an active attempt moves to recoveryPending, not back into the exam', () {
    final machine = AttemptStateMachine(initialViolationCount: 0);
    machine.start();
    machine.registerViolation(reason: 'Aplikasi ditinggalkan');

    expect(machine.markProcessDeath(), isTrue);
    expect(machine.state, AttemptState.recoveryPending);
    // Tidak ada pelanggaran baru karena pemulihan.
    expect(machine.violationCount, 1);

    // Dari recovery, hanya pengawas yang bisa melanjutkan/mengakhiri.
    expect(machine.start(), isFalse);
    expect(machine.continueBySupervisor(), isTrue);
    expect(machine.state, AttemptState.active);
    expect(machine.violationCount, 1);
  });

  test('session identity mismatch is rejected so a new scan cannot swap active session data', () {
    final machine = AttemptStateMachine(initialViolationCount: 0);
    machine.bindSession(session);
    machine.start();

    final otherSession = ExamSession(
      schemaVersion: 2,
      sessionId: 'session-2',
      sessionCode: 'FIS-9X1Q',
      examName: 'Fisika Kelas XI',
      formUrl: Uri.parse('https://docs.google.com/forms/d/e/xyz/viewform'),
      pinSalt: 'c2FsdEI=',
      pinVerifier: 'dmVyaWZpZXJC',
    );
    expect(() => machine.bindSession(otherSession), throwsStateError);
    expect(machine.sessionId, 'session-1');
  });
}
