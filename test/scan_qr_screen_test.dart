import 'dart:async';
import 'dart:convert';

import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/core/exam_app.dart';
import 'package:examseal/screens/pre_exam_screen.dart';
import 'package:examseal/services/exam_session_controller.dart';
import 'package:examseal/services/teacher_session_secrets.dart';
import 'package:examseal/screens/scan_qr_screen.dart';
import 'package:examseal/services/qr_codec.dart';
import 'package:examseal/services/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ScannerPlatform extends MobileScannerPlatform {
  final captures = StreamController<BarcodeCapture?>.broadcast();
  BarcodeCapture? image;
  bool denied = false;
  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const SizedBox();
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    if (denied) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      );
    }
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(320, 320),
    );
  }

  @override
  Future<BarcodeCapture?> analyzeImage(
    String path, {
    List<BarcodeFormat> formats = const [],
  }) async => image;
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> updateScanWindow(Rect? window) async {}
}

void main() {
  sqfliteFfiInit();
  final session = ExamSession(
    schemaVersion: 2,
    sessionId: 'scan-1',
    sessionCode: 'MTK-1234',
    examName: 'Matematika',
    formUrl: Uri.parse('https://forms.gle/example'),
    pinSalt: base64Encode(List.filled(16, 1)),
    pinVerifier: base64Encode(List.filled(32, 2)),
  );
  BarcodeCapture capture(String payload) => BarcodeCapture(
    barcodes: [Barcode(rawValue: payload, format: BarcodeFormat.qrCode)],
  );
  late ScannerPlatform scanner;
  String? picked;

  setUp(() {
    final previous = MobileScannerPlatform.instance;
    scanner = ScannerPlatform();
    MobileScannerPlatform.instance = scanner;
    picked = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/image_picker'),
          (call) async => call.method == 'pickImage' ? picked : null,
        );
    addTearDown(() async {
      MobileScannerPlatform.instance = previous;
      await scanner.captures.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/image_picker'),
            null,
          );
    });
  });

  testWidgets('kamera menunggu penyimpanan dan mengabaikan scan ganda', (
    tester,
  ) async {
    final saved = Completer<void>();
    var deliveries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ScanQrScreen(
          onSession: (value) async {
            expect(value.sessionId, session.sessionId);
            deliveries++;
            await saved.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final detect = tester
        .widget<MobileScanner>(find.byType(MobileScanner))
        .onDetect!;
    detect(capture(encodeSessionQr(session)));
    detect(capture(encodeSessionQr(session)));
    await tester.pump();
    expect(deliveries, 1);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    saved.complete();
    await tester.pump();
    detect(capture(encodeSessionQr(session)));
    expect(deliveries, 1);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'scan aplikasi gagal tertahan lalu membuka pra-ujian hanya setelah tersimpan',
    (tester) async {
      final db = await databaseFactoryFfiNoIsolate.openDatabase(
        inMemoryDatabasePath,
      );
      addTearDown(db.close);
      final store = await SessionStore.open(db);
      final app = ExamSessionController(
        store: store,
        secrets: TeacherSessionSecrets.inMemory(),
        now: DateTime.now,
      );
      await tester.pumpWidget(ExamApp(controller: app));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siswa'));
      await tester.pumpAndSettle();
      await db.execute('PRAGMA query_only = ON');
      scanner.captures.add(capture(encodeSessionQr(session)));
      await tester.pumpAndSettle();
      expect(find.byType(PreExamScreen), findsNothing);
      expect(await store.loadSession(session.sessionId), isNull);
      expect(find.text('Scan ulang'), findsOneWidget);
      await db.execute('PRAGMA query_only = OFF');
      await tester.ensureVisible(find.text('Scan ulang'));
      await tester.tap(find.text('Scan ulang'));
      await tester.pumpAndSettle();
      scanner.captures.add(capture(encodeSessionQr(session)));
      await tester.pumpAndSettle();
      expect(find.byType(PreExamScreen), findsOneWidget);
      expect(
        (await store.loadSession(session.sessionId))!.sameIdentityAs(session),
        isTrue,
      );
      expect(find.text('Matematika'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Mulai Ujian'), 400);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Mulai Ujian'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'izin kamera ditolak tetap menyediakan galeri, batal tidak mengirim sesi',
    (tester) async {
      scanner.denied = true;
      var deliveries = 0;
      await tester.pumpWidget(
        MaterialApp(home: ScanQrScreen(onSession: (_) => deliveries++)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Izin kamera ditolak'), findsOneWidget);
      await tester.tap(find.text('Pilih dari Galeri'));
      await tester.pumpAndSettle();
      expect(deliveries, 0);
      picked = 'qr.png';
      scanner.image = capture(encodeSessionQr(session));
      await tester.tap(find.text('Pilih dari Galeri'));
      await tester.pump();
      await tester.pump();
      expect(deliveries, 1);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('Back ditahan selama hasil scan sedang disimpan', (tester) async {
    final saved = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ScanQrScreen(onSession: (_) => saved.future),
                ),
              ),
              child: const Text('Buka scan'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka scan'));
    await tester.pumpAndSettle();
    scanner.captures.add(capture(encodeSessionQr(session)));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(ScanQrScreen), findsOneWidget);
    saved.complete();
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'galeri menunggu simpan dan menampilkan kegagalan agar dapat diulang',
    (tester) async {
      picked = 'qr.png';
      scanner.image = capture(encodeSessionQr(session));
      final saved = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(home: ScanQrScreen(onSession: (_) => saved.future)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilih dari Galeri'));
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      saved.completeError(
        StorageFailure('Penyimpanan penuh. Kosongkan ruang lalu scan ulang.'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Penyimpanan penuh'), findsOneWidget);
      expect(find.text('Scan ulang'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
