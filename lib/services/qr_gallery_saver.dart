import 'dart:typed_data';

import 'package:gal/gal.dart';

import '../models/exam_sessions.dart';

/// Album Galeri tempat QR sesi disimpan agar guru mudah menemukannya di
/// aplikasi Galeri/Foto perangkat.
const String kSessionQrAlbum = 'ExamSeal';

/// Nama berkas QR tanpa ekstensi; `gal` menambahkan ekstensinya sendiri.
String sessionQrFileName(ExamSession session) => 'qr-${session.sessionCode}';

const String _accessDeniedMessage =
    'Izin menyimpan ke Galeri tidak diberikan. Aktifkan izin penyimpanan untuk ExamSeal lalu coba lagi, atau gunakan Bagikan Gambar QR.';

const String _unexpectedMessage =
    'QR tidak dapat disimpan ke Galeri pada perangkat ini. Gunakan Bagikan Gambar QR atau tampilkan QR langsung kepada siswa.';

/// Kegagalan menyimpan QR ke Galeri. [message] sudah siap dibaca guru dan
/// selalu menyebut jalur alternatif Bagikan Gambar QR.
class QrSaveFailure implements Exception {
  QrSaveFailure(this.message);
  final String message;

  @override
  String toString() => 'QrSaveFailure: $message';
}

/// Menyimpan PNG QR sesi ke Galeri perangkat. Izin penyimpanan diminta di
/// sini — hanya saat guru menekan Simpan, bukan saat aplikasi dibuka — dan
/// penolakannya dilaporkan sebagai [QrSaveFailure]; menyimpan QR tidak
/// mengubah sesi, Form, atau state attempt.
Future<void> saveSessionQrToGallery(ExamSession session, Uint8List png) async {
  try {
    if (!await Gal.hasAccess(toAlbum: true) &&
        !await Gal.requestAccess(toAlbum: true)) {
      throw QrSaveFailure(_accessDeniedMessage);
    }
    await Gal.putImageBytes(
      png,
      album: kSessionQrAlbum,
      name: sessionQrFileName(session),
    );
  } on QrSaveFailure {
    rethrow;
  } on GalException catch (e) {
    throw QrSaveFailure(describeQrSaveFailure(e.type));
  } catch (_) {
    throw QrSaveFailure(_unexpectedMessage);
  }
}

/// Pesan per jenis kegagalan `gal`; dipisah agar dapat diuji tanpa platform
/// channel dan agar UI tidak menyatakan QR tersimpan saat gagal.
String describeQrSaveFailure(GalExceptionType type) => switch (type) {
  GalExceptionType.accessDenied => _accessDeniedMessage,
  GalExceptionType.notEnoughSpace =>
    'Ruang penyimpanan tidak cukup untuk menyimpan QR. Kosongkan ruang lalu coba lagi, atau gunakan Bagikan Gambar QR.',
  GalExceptionType.notSupportedFormat =>
    'Gambar QR tidak didukung Galeri perangkat ini. Gunakan Bagikan Gambar QR.',
  GalExceptionType.unexpected => _unexpectedMessage,
};
