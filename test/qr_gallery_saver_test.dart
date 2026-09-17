import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/services/qr_gallery_saver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gal/gal.dart';

void main() {
  final session = ExamSession(
    schemaVersion: 3,
    sessionId: 's',
    sessionCode: 'MTH-7K2P',
    examName: 'Matematika Kelas XI',
    formUrl: Uri.parse('https://docs.google.com/forms/d/e/example/viewform'),
  );

  test('nama berkas QR memakai kode sesi tanpa ekstensi', () {
    expect(sessionQrFileName(session), 'qr-MTH-7K2P');
    expect(sessionQrFileName(session), isNot(contains('.png')));
  });

  test('setiap jenis kegagalan gal punya pesan sendiri', () {
    final messages = {
      for (final type in GalExceptionType.values)
        type: describeQrSaveFailure(type),
    };

    expect(messages.values.toSet(), hasLength(GalExceptionType.values.length));
    for (final message in messages.values) {
      expect(message.trim(), isNotEmpty);
      // Galeri bukan satu-satunya jalur; UI wajib menyebut alternatifnya.
      expect(message, contains('Bagikan Gambar QR'));
    }
    expect(
      messages[GalExceptionType.accessDenied],
      contains('Izin menyimpan ke Galeri'),
    );
    expect(messages[GalExceptionType.notEnoughSpace], contains('Ruang'));
  });
}
