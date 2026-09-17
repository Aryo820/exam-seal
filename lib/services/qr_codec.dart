import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/exam_sessions.dart';
import 'form_url_policy.dart';

/// Payload QR ExamSeal versi 3 hanya memuat identitas sesi dan tautan Form.
const int kSessionQrSchemaVersion = 3;

String encodeSessionQr(ExamSession session) => jsonEncode({
  'schemaVersion': kSessionQrSchemaVersion,
  'sessionId': session.sessionId,
  'sessionCode': session.sessionCode,
  'examName': session.examName,
  'formUrl': session.formUrl.toString(),
  'securityPolicyVersion': session.securityPolicyVersion,
});

Future<Uint8List> renderSessionQrPng(ExamSession session) async {
  const qrSize = 744.0;
  const padding = 60.0;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..drawColor(Colors.white, ui.BlendMode.src);
  canvas.translate(padding, padding);
  QrPainter(
    data: encodeSessionQr(session),
    version: QrVersions.auto,
    gapless: true,
    eyeStyle: const QrEyeStyle(
      eyeShape: QrEyeShape.square,
      color: Colors.black,
    ),
    dataModuleStyle: const QrDataModuleStyle(
      dataModuleShape: QrDataModuleShape.square,
      color: Colors.black,
    ),
  ).paint(canvas, const ui.Size(qrSize, qrSize));
  final image = await recorder.endRecording().toImage(
    (qrSize + padding * 2).toInt(),
    (qrSize + padding * 2).toInt(),
  );
  try {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw StateError('Gambar QR tidak dapat dibuat.');
    return byteData.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

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
    if (data is! Map<String, dynamic> ||
        data['schemaVersion'] is! int ||
        data['schemaVersion'] != kSessionQrSchemaVersion) {
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

    final allowedKeys = {...fields, 'schemaVersion', 'securityPolicyVersion'};
    if (data.keys.any((key) => !allowedKeys.contains(key)) ||
        data['securityPolicyVersion'] is! int ||
        data['securityPolicyVersion'] != 1) {
      return (
        session: null,
        error:
            'Kebijakan sesi tidak didukung. Minta QR sesi terbaru dari guru.',
      );
    }

    return (
      session: ExamSession(
        schemaVersion: kSessionQrSchemaVersion,
        sessionId: sessionId,
        sessionCode: sessionCode,
        examName: examName,
        formUrl: formUrl,
        securityPolicyVersion: 1,
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
