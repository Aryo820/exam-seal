import 'dart:convert';

import 'package:examseal/services/pin_service.dart';
import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/services/qr_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ExamSession> sessionWithPin() async {
    final material = await PinService.createVerificationMaterial('13579');
    return ExamSession(
      schemaVersion: 2,
      sessionId: 'session-1',
      sessionCode: 'MTH-7K2P',
      examName: 'Matematika Kelas XI',
      formUrl: Uri.parse('https://docs.google.com/forms/d/e/example/viewform'),
      pinSalt: material.salt,
      pinVerifier: material.verifier,
      createdAt: DateTime.utc(2026, 9, 13, 8),
    );
  }

  test('scan rejects invalid input and decodes one supported ExamSeal session', () {
    expect(scanFeedback([]), contains('tidak ditemukan'));
    expect(scanFeedback(['a', 'b']), contains('beberapa QR'));
    expect(
      scanFeedback(['https://forms.gle/example']),
      contains('tautan saja'),
    );
    expect(scanFeedback(['broken']), contains('tidak dikenali'));
    expect(scanFeedback(['{}']), contains('tidak didukung'));
    expect(scanFeedback(['x' * 8193]), contains('terlalu besar'));

    const invalidHost =
        '{"sessionId":"s","sessionCode":"c","examName":"Ujian","formUrl":"https://docs.google.com.evil/forms/d/e","schemaVersion":2,"pinSalt":"c2FsdA==","pinVerifier":"dg=="}';
    expect(scanFeedback([invalidHost]), contains('tidak valid'));
  });

  test('QR v2 round-trips session and verifier material; raw PIN never appears', () async {
    final session = await sessionWithPin();
    final encoded = encodeSessionQr(session);

    expect(encoded.toLowerCase(), isNot(contains('pin":')));
    expect(encoded, isNot(contains('13579')));

    final decoded = decodeScan([encoded]);
    expect(decoded.error, isNull);
    expect(decoded.session!.sessionId, 'session-1');
    expect(decoded.session!.sessionCode, 'MTH-7K2P');
    expect(decoded.session!.examName, 'Matematika Kelas XI');
    expect(decoded.session!.pinSalt, session.pinSalt);
    expect(decoded.session!.pinVerifier, session.pinVerifier);

    // Verifikasi PIN tetap mungkin di HP siswa dengan bahan dari QR.
    final material = PinVerificationMaterial(
      salt: decoded.session!.pinSalt!,
      verifier: decoded.session!.pinVerifier!,
    );
    expect(await PinService.verifyPin('13579', material), isTrue);
    expect(await PinService.verifyPin('54321', material), isFalse);

    // Scan ganda dari beberapa frame tidak membuat dua sesi.
    final again = decodeScan([encoded, encoded]);
    expect(again.error, isNull);
    expect(again.session!.sessionId, 'session-1');
  });

  test('QR schema 1 without verifier material is rejected as old format', () {
    const oldQr =
        '{"sessionId":"s","sessionCode":"MTH-7K2P","examName":"Matematika Kelas XI","formUrl":"https://docs.google.com/forms/d/e/example/viewform","schemaVersion":1}';
    final result = decodeScan([oldQr]);
    expect(result.session, isNull);
    expect(result.error, contains('Versi QR tidak didukung'));
  });

  test('QR v2 without verifier material is rejected as incomplete', () {
    const noMaterial =
        '{"sessionId":"s","sessionCode":"MTH-7K2P","examName":"Matematika Kelas XI","formUrl":"https://docs.google.com/forms/d/e/example/viewform","schemaVersion":2}';
    final result = decodeScan([noMaterial]);
    expect(result.session, isNull);
    expect(result.error, contains('Data QR tidak lengkap'));
  });

  test('QR payload with same id but different verifier is flagged as a conflict', () async {
    final session = await sessionWithPin();
    final encoded = jsonEncode(jsonDecode(encodeSessionQr(session))
        as Map<String, dynamic>
      ..['pinVerifier'] = 'b3RoZXJfdmVyaWZpZXI=');

    final conflict = decodeScan([encoded]);
    expect(conflict.session, isNotNull);

    final sameIdDifferentMaterial = conflict.session!;
    expect(session.sameIdentityAs(sameIdDifferentMaterial), isFalse);
    expect(session.sessionId == sameIdDifferentMaterial.sessionId, isTrue);
  });
}
