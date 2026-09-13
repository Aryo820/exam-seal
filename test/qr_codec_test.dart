import 'package:examseal/services/qr_codec.dart';
import 'package:examseal/models/exam_sessions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Scan rejects invalid input and decodes one supported ExamSeal session', () {
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
        '{"sessionId":"s","sessionCode":"c","examName":"Ujian","formUrl":"https://docs.google.com.evil/forms/d/e","schemaVersion":1}';
    expect(scanFeedback([invalidHost]), contains('tidak valid'));

    const candidate =
        '{"sessionId":"s","sessionCode":"MTH-7K2P","examName":"Matematika Kelas XI","formUrl":"https://docs.google.com/forms/d/e/example/viewform","schemaVersion":1}';
    final result = decodeScan([candidate, candidate]);
    expect(result.error, isNull);
    expect(result.session?.examName, 'Matematika Kelas XI');
    expect(result.session?.sessionCode, 'MTH-7K2P');

    final session = ExamSession(
      schemaVersion: 1,
      sessionId: 's',
      sessionCode: 'MTH-7K2P',
      examName: 'Matematika Kelas XI',
      formUrl: Uri.parse('https://docs.google.com/forms/d/e/example/viewform'),
    );
    final encoded = encodeSessionQr(session);
    expect(encodeSessionQr(session), encoded);
    expect(encoded.toLowerCase(), isNot(contains('pin')));
    expect(decodeScan([encoded]).session?.sessionId, 's');
  });
}
