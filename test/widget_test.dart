import 'package:examseal/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Splash matches Stitch and fits large text on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const MyApp());

    final wordmark = find.text('ExamSeal');
    expect(wordmark, findsOneWidget);
    expect(tester.getCenter(wordmark), const Offset(180, 320));
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.white,
    );
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Pilih mode'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Siswa').hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Siswa'));
    await tester.pumpAndSettle();
    expect(find.text('Scan QR Ujian'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Guru').hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
      await tester.tap(find.text('Guru'));
      await tester.pumpAndSettle();
      expect(find.text('Sesi Guru'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Belum ada sesi ujian'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Belum ada sesi ujian'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
