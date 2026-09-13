import 'dart:convert';

import '../models/exam_sessions.dart';
import 'form_url_policy.dart';

String encodeSessionQr(ExamSession session) => jsonEncode({
  'schemaVersion': session.schemaVersion,
  'sessionId': session.sessionId,
  'sessionCode': session.sessionCode,
  'examName': session.examName,
  'formUrl': session.formUrl.toString(),
});

({ExamSession? session, String? error}) decodeScan(Iterable<String> values) {
  final codes = values.where((value) => value.trim().isNotEmpty).toSet();
  if (codes.isEmpty) {
    return (
      session: null,
      error:
          'QR tidak ditemukan. Pilih gambar yang jelas dan memuat satu QR sesi.',
    );
  }
  if (codes.length != 1) {
    return (
      session: null,
      error:
          'Ada beberapa QR. Arahkan kamera atau potong gambar ke satu QR sesi.',
    );
  }

  final raw = codes.single;
  if (raw.length > 8192) {
    return (
      session: null,
      error: 'Data QR terlalu besar. Minta QR sesi ExamSeal dari guru.',
    );
  }
  if (Uri.tryParse(raw)?.hasScheme == true) {
    return (
      session: null,
      error: 'QR tautan saja tidak cukup. Minta QR sesi ExamSeal dari guru.',
    );
  }

  try {
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic> || data['schemaVersion'] != 1) {
      return (
        session: null,
        error: 'Versi QR tidak didukung. Minta QR sesi terbaru dari guru.',
      );
    }
    final fields = ['sessionId', 'sessionCode', 'examName', 'formUrl'];
    if (!fields.every(
      (key) => data[key] is String && (data[key] as String).trim().isNotEmpty,
    )) {
      return (
        session: null,
        error: 'Data QR tidak lengkap. Minta QR sesi ExamSeal dari guru.',
      );
    }

    final sessionId = (data['sessionId'] as String).trim();
    final sessionCode = (data['sessionCode'] as String).trim();
    final examName = (data['examName'] as String).trim();
    final formUrlText = (data['formUrl'] as String).trim();
    final formUrl = Uri.tryParse(formUrlText);
    if (sessionId.length > 128 ||
        sessionCode.length > 32 ||
        examName.length > 200 ||
        formUrlText.length > 2048 ||
        formUrl == null ||
        !isAllowedGoogleFormUrl(formUrl)) {
      return (
        session: null,
        error:
            'Data sesi atau tautan Google Forms tidak valid. Minta QR baru dari guru.',
      );
    }

    return (
      session: ExamSession(
        schemaVersion: 1,
        sessionId: sessionId,
        sessionCode: sessionCode,
        examName: examName,
        formUrl: formUrl,
      ),
      error: null,
    );
  } on FormatException {
    return (
      session: null,
      error: 'Format QR tidak dikenali. Minta QR sesi ExamSeal dari guru.',
    );
  }
}

String scanFeedback(Iterable<String> values) {
  final result = decodeScan(values);
  return result.error ?? 'QR sesi valid.';
}
