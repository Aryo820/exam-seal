import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/screens/session_qr_screen.dart';
import 'package:examseal/services/qr_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('QR sesi langsung dibuat tanpa PIN', (tester) async {
    final session = ExamSession(
      schemaVersion: kSessionQrSchemaVersion,
      sessionId: 's',
      sessionCode: 'MTH-7K2P',
      examName: 'Matematika Kelas XI',
      formUrl: Uri.parse('https://docs.google.com/forms/d/e/example/viewform'),
    );
    await tester.pumpWidget(
      MaterialApp(home: SessionQrScreen(session: session)),
    );

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('PIN'), findsNothing);
    await tester.pumpAndSettle();
    final shareButton = find.widgetWithText(FilledButton, 'Bagikan Gambar QR');
    await tester.ensureVisible(shareButton);
    expect(shareButton, findsOneWidget);
  });
}
