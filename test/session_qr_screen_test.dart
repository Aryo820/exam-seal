import 'dart:typed_data';

import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/screens/session_qr_screen.dart';
import 'package:examseal/services/qr_codec.dart';
import 'package:examseal/services/qr_gallery_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  final session = ExamSession(
    schemaVersion: kSessionQrSchemaVersion,
    sessionId: 's',
    sessionCode: 'MTH-7K2P',
    examName: 'Matematika Kelas XI',
    formUrl: Uri.parse('https://docs.google.com/forms/d/e/example/viewform'),
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    required Future<void> Function(ExamSession, Uint8List) saveQrToGallery,
  }) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: SessionQrScreen(
          session: session,
          saveQrToGallery: saveQrToGallery,
        ),
      ),
    );
    await tester.ensureVisible(find.text('Simpan QR ke Galeri'));
    await tester.pump();
  }

  /// Menekan Simpan lalu menunggu handler selesai. Render PNG memakai
  /// encoding gambar engine yang tidak selesai di zona fake-async
  /// `testWidgets`, jadi aksinya dijalankan lewat [WidgetTester.runAsync].
  Future<void> tapSave(WidgetTester tester, bool Function() done) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('Simpan QR ke Galeri'));
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (!done() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(done(), isTrue, reason: 'handler simpan tidak selesai');
    });
    await tester.pumpAndSettle();
  }

  testWidgets('QR sesi langsung dibuat tanpa PIN', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SessionQrScreen(session: session)));

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('PIN'), findsNothing);
    await tester.pumpAndSettle();
    final shareButton = find.widgetWithText(FilledButton, 'Bagikan Gambar QR');
    await tester.ensureVisible(shareButton);
    expect(shareButton, findsOneWidget);
  });

  testWidgets('T03 simpan QR ke Galeri memakai PNG sesi yang sama', (
    tester,
  ) async {
    Uint8List? saved;
    ExamSession? savedSession;
    var savedOnce = false;
    await pumpScreen(
      tester,
      saveQrToGallery: (value, png) async {
        savedSession = value;
        saved = png;
        savedOnce = true;
      },
    );

    await tapSave(tester, () => savedOnce);

    expect(savedSession, same(session));
    expect(saved, isNotNull);
    // PNG sesi, bukan payload teks: tanda tangan PNG harus ada.
    expect(saved!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    expect(
      find.textContaining('album $kSessionQrAlbum'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('kegagalan simpan dilaporkan dan tidak mengklaim tersimpan', (
    tester,
  ) async {
    var attempted = false;
    await pumpScreen(
      tester,
      saveQrToGallery: (_, _) async {
        attempted = true;
        throw QrSaveFailure(
          'Izin menyimpan ke Galeri tidak diberikan. Gunakan Bagikan Gambar QR.',
        );
      },
    );

    await tapSave(tester, () => attempted);

    expect(
      find.text('Izin menyimpan ke Galeri tidak diberikan. Gunakan Bagikan Gambar QR.'),
      findsOneWidget,
    );
    expect(find.textContaining('album $kSessionQrAlbum'), findsNothing);
    // Tombol kembali aktif agar guru dapat mencoba jalur lain.
    expect(
      tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Simpan QR ke Galeri'),
      ).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
