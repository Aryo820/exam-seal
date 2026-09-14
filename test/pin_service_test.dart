import 'package:flutter_test/flutter_test.dart';

import 'package:examseal/services/pin_service.dart';

void main() {
  test('generated supervisor PINs are five digits from a secure source', () {
    for (var i = 0; i < 50; i++) {
      final pin = PinService.generateSupervisorPin();
      expect(pin, hasLength(5));
      expect(RegExp(r'^\d{5}$').hasMatch(pin), isTrue);
    }
  });

  test('two generated PINs differ overwhelmingly (Random.secure)', () {
    final pins = {for (var i = 0; i < 20; i++) PinService.generateSupervisorPin()};
    expect(pins.length, greaterThan(1));
  });

  test('session codes are short, uppercase, and unique enough to compare visually', () {
    final codes = <String>{};
    for (var i = 0; i < 20; i++) {
      final code = PinService.generateSessionCode(seedName: 'Matematika Kelas XI');
      expect(code, matches(RegExp(r'^[A-Z0-9]{3}-[A-Z0-9]{4}$')));
      codes.add(code);
    }
    expect(codes.length, greaterThan(15));
  });

  test('PBKDF2 verifier matches the PIN while the raw PIN never leaves the service', () async {
    final material = await PinService.createVerificationMaterial('13579');

    expect(material.salt, isNotEmpty);
    expect(material.verifier, isNotEmpty);
    expect(material.salt, isNot(contains('13579')));
    expect(material.verifier, isNot(contains('13579')));

    expect(await PinService.verifyPin('13579', material), isTrue);
    expect(await PinService.verifyPin('13578', material), isFalse);
    expect(await PinService.verifyPin('24680', material), isFalse);
  });

  test('different sessions produce different salts and verifiers', () async {
    final a = await PinService.createVerificationMaterial('11111');
    final b = await PinService.createVerificationMaterial('11111');
    expect(a.salt, isNot(b.salt));
    expect(a.verifier, isNot(b.verifier));
  });

  test('five consecutive wrong PINs trigger a 30-second cooldown, then reset', () {
    final state = PinAttemptState.initial();

    for (var i = 1; i <= 4; i++) {
      final outcome = state.onWrongAttempt(now: DateTime.utc(2026, 9, 13, 8));
      expect(outcome, isFalse);
      expect(state.failedAttempts, i);
    }

    final lockedAt = DateTime.utc(2026, 9, 13, 8, 0, 5);
    final locked = state.onWrongAttempt(now: lockedAt);
    expect(locked, isTrue);
    expect(state.failedAttempts, 5);
    expect(state.lockedUntil, lockedAt.add(const Duration(seconds: 30)));

    // Saat cooldown aktif, verifikasi ditolak tanpa mengecek PIN.
    expect(state.isLocked(now: lockedAt.add(const Duration(seconds: 10))), isTrue);

    // Setelah 30 detik, percobaan diizinkan lagi dan counter reset.
    expect(state.isLocked(now: lockedAt.add(const Duration(seconds: 31))), isFalse);
    state.onCorrectAttempt();
    expect(state.failedAttempts, 0);
  });

  test('cooldown status round-trips for persistence across restarts', () {
    final state = PinAttemptState(
      failedAttempts: 5,
      lockedUntil: DateTime.utc(2026, 9, 13, 8, 0, 30),
    );

    final restored = PinAttemptState.fromJson(state.toJson());

    expect(restored.failedAttempts, 5);
    expect(restored.lockedUntil, state.lockedUntil);
  });

  test('restored cooldown still gates attempts until it expires', () {
    final state = PinAttemptState(
      failedAttempts: 5,
      lockedUntil: DateTime.utc(2026, 9, 13, 8, 0, 30),
    );
    expect(state.isLocked(now: DateTime.utc(2026, 9, 13, 8, 0, 29)), isTrue);
    expect(state.isLocked(now: DateTime.utc(2026, 9, 13, 8, 0, 30)), isFalse);
  });
}
