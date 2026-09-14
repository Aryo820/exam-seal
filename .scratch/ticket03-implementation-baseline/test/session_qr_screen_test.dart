import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/screens/session_qr_screen.dart';
import 'package:examseal/services/qr_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('T04 renders and shares the same public session payload', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = ExamSession(
      schemaVersion: 2,
      sessionId: 's',
      sessionCode: 'MTH-7K2P',
      examName: 'Matematika Kelas XI',
      formUrl: Uri.parse('https://docs.google.com/forms/d/e/example/viewform'),
      pinSalt: 'AQEBAQEBAQEBAQEBAQEBAQ==',
      pinVerifier: 'AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI=',
    );
    String? sharedPayload;
    var openedPin = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SessionQrScreen(
          session: session,
          shareQr: (payload) {
            sharedPayload = payload;
            return true;
          },
          onOpenSupervisorPin: () => openedPin = true,
        ),
      ),
    );

    expect(find.text('Matematika Kelas XI'), findsOneWidget);
    expect(find.text('MTH-7K2P'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(
      find.textContaining('PIN pengawas tidak ditampilkan'),
      findsOneWidget,
    );

    final shareButton = find.widgetWithText(FilledButton, 'Bagikan Gambar QR');
    await tester.ensureVisible(shareButton);
    await tester.pump();
    await tester.tap(shareButton);
    await tester.pump();

    expect(sharedPayload, encodeSessionQr(session));
    expect(decodeScan([sharedPayload!]).session?.sessionCode, 'MTH-7K2P');

    await tester.ensureVisible(find.text('Akses PIN Pengawas'));
    await tester.pump();
    await tester.tap(find.text('Akses PIN Pengawas'));
    expect(openedPin, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T05 reveals PIN only after device authentication', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = ExamSession(
      schemaVersion: 2,
      sessionId: 's',
      sessionCode: 'MTH-7K2P',
      examName: 'Matematika Kelas XI',
      formUrl: Uri.parse('https://docs.google.com/forms/d/e/example/viewform'),
      pinSalt: 'AQEBAQEBAQEBAQEBAQEBAQ==',
      pinVerifier: 'AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI=',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SessionQrScreen(
          session: session,
          authenticateSupervisor: () => true,
          readSupervisorPin: () => '74209',
        ),
      ),
    );

    await tester.ensureVisible(find.text('Akses PIN Pengawas'));
    await tester.tap(find.text('Akses PIN Pengawas'));
    await tester.pumpAndSettle();
    expect(find.text('•••••'), findsOneWidget);
    expect(find.text('7 4 2 0 9'), findsNothing);

    await tester.ensureVisible(find.text('Autentikasi Kunci Layar HP'));
    await tester.tap(find.text('Autentikasi Kunci Layar HP'));
    await tester.pumpAndSettle();
    expect(find.text('7 4 2 0 9'), findsOneWidget);

    await tester.ensureVisible(find.text('Kunci Kembali PIN'));
    await tester.tap(find.text('Kunci Kembali PIN'));
    await tester.pump();
    expect(find.text('•••••'), findsOneWidget);
    expect(find.text('7 4 2 0 9'), findsNothing);
  });
}
