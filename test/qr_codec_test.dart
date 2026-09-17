import 'dart:convert';
import 'dart:typed_data';

import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/services/qr_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final session = ExamSession(
    schemaVersion: kSessionQrSchemaVersion,
    sessionId: 'session-1',
    sessionCode: 'MTH-7K2P',
    examName: 'Matematika Kelas XI',
    formUrl: Uri.parse('https://docs.google.com/forms/d/e/example/viewform'),
  );

  test('QR publik hanya memuat data sesi dan Form', () {
    final encoded = encodeSessionQr(session);
    final data = jsonDecode(encoded) as Map<String, dynamic>;

    expect(data['schemaVersion'], 3);
    expect(data, isNot(contains('pinSalt')));
    expect(data, isNot(contains('pinVerifier')));
    expect(decodeScan([encoded]).session?.sameIdentityAs(session), isTrue);
  });

  testWidgets('gambar QR dibuat sebagai PNG publik', (tester) async {
    Uint8List? png;
    await tester.runAsync(() async {
      png = await renderSessionQrPng(session);
    });

    expect(png, hasLength(greaterThan(8)));
    expect(png!.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
  });

  test('scan menolak QR lama, data asing, dan URL tidak valid', () {
    expect(scanFeedback([]), contains('tidak ditemukan'));
    expect(scanFeedback(['a', 'b']), contains('beberapa QR'));
    expect(
      scanFeedback(['https://forms.gle/example']),
      contains('tautan saja'),
    );
    expect(scanFeedback(['x' * 8193]), contains('terlalu besar'));

    final old = jsonEncode({
      'schemaVersion': 2,
      'sessionId': 's',
      'sessionCode': 'MTH-7K2P',
      'examName': 'Matematika',
      'formUrl': 'https://forms.gle/example',
      'securityPolicyVersion': 1,
    });
    expect(scanFeedback([old]), contains('Versi QR tidak didukung'));

    final invalidUrl = jsonEncode({
      'schemaVersion': 3,
      'sessionId': 's',
      'sessionCode': 'MTH-7K2P',
      'examName': 'Matematika',
      'formUrl': 'https://docs.google.com.evil/forms/d/e/example',
      'securityPolicyVersion': 1,
    });
    expect(scanFeedback([invalidUrl]), contains('tidak valid'));
  });
}
