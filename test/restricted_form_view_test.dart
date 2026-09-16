import 'dart:async';

import 'package:examseal/models/exam_sessions.dart';
import 'package:examseal/screens/form_test_run_screen.dart';
import 'package:examseal/screens/supervisor_pin_screen.dart';
import 'package:examseal/widgets/restricted_form_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Adaptor uji untuk antarmuka platform yang dibawa webview_flutter.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  const form = 'https://docs.google.com/forms/d/e/pilot/viewform';
  late _Platform platform;
  setUp(() {
    platform = _Platform();
    WebViewPlatform.instance = platform;
  });

  for (final storageFails in [false, true]) {
    testWidgets(
      'keluar uji perlu PIN; kegagalan catatan membatalkan pemeriksaan: $storageFails',
      (tester) async {
        bool? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => FormTestRunScreen(
                          session: ExamSession(
                            schemaVersion: 2,
                            sessionId: 'pilot',
                            sessionCode: 'TEST',
                            examName: 'Uji',
                            formUrl: Uri.parse(form),
                          ),
                          verifyPin: (pin) async => pin == '12345',
                          recordBlocked: () async {
                            if (storageFails) throw StateError('gagal tulis');
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('Mulai uji'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Mulai uji'));
        await tester.pumpAndSettle();
        platform.delegate.started(form);
        platform.delegate.finished(form);
        await tester.pumpAndSettle();
        await platform.delegate.navigate(
          const NavigationRequest(
            url: 'https://example.com',
            isMainFrame: true,
          ),
        );
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(SupervisorPinScreen), findsOneWidget);
        expect(result, isNull);
        await tester.enterText(find.byType(TextField), '00000');
        tester.testTextInput.hide();
        await tester.tap(find.text('Verifikasi PIN'));
        await tester.pumpAndSettle();
        expect(result, isNull);
        await tester.enterText(find.byType(TextField), '12345');
        tester.testTextInput.hide();
        await tester.tap(find.text('Verifikasi PIN'));
        await tester.pumpAndSettle();
        expect(result, !storageFails);
        expect(find.text('Mulai uji'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'retry setelah konfigurasi gagal membuat controller dengan pembatasan lengkap',
    (tester) async {
      platform.failFirstSetup = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RestrictedFormView(url: Uri.parse(form))),
        ),
      );
      await tester.pumpAndSettle();
      final failed = platform.controller;
      expect(failed.loaded, isEmpty);
      expect(find.textContaining('gagal disiapkan'), findsOneWidget);
      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Muat Ulang'));
      await tester.pumpAndSettle();
      expect(platform.controller, isNot(same(failed)));
      expect(failed.loaded, isEmpty);
      expect(platform.controller.loaded, [form]);
      expect(
        await platform.delegate.navigate(
          const NavigationRequest(
            url: 'https://example.com/',
            isMainFrame: true,
          ),
        ),
        NavigationDecision.prevent,
      );
    },
  );

  testWidgets(
    'konten ditahan sampai inspeksi; respons tidak membuka pengulangan',
    (tester) async {
      var inspected = false;
      var blocked = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RestrictedFormView(
              url: Uri.parse(form),
              onInspected: (value) => inspected = value,
              onBlocked: () => blocked++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(platform.controller.loaded, [form]);
      expect(find.text('Form native'), findsNothing);
      final delegate = platform.delegate;
      delegate.started(form);
      delegate.finished(form);
      await tester.pump();
      expect(inspected, isTrue);
      expect(find.text('Form native'), findsOneWidget);
      expect(
        await delegate.navigate(
          const NavigationRequest(
            url: 'https://example.com/',
            isMainFrame: true,
          ),
        ),
        NavigationDecision.prevent,
      );
      expect(blocked, 1);
      delegate.resourceError(
        const WebResourceError(
          errorCode: -1,
          description: 'aset',
          isForMainFrame: false,
        ),
      );
      expect(inspected, isTrue);
      const response = 'https://docs.google.com/forms/d/e/pilot/formResponse';
      expect(
        await delegate.navigate(
          const NavigationRequest(url: response, isMainFrame: true),
        ),
        NavigationDecision.navigate,
      );
      delegate.started(response);
      platform.controller.result = '{"hasForm":false,"upload":false}';
      delegate.finished(response);
      await tester.pump();
      expect(inspected, isTrue);
      expect(
        await delegate.navigate(
          const NavigationRequest(url: form, isMainFrame: true),
        ),
        NavigationDecision.prevent,
      );
      expect(find.textContaining('berhasil dikirim'), findsNothing);
    },
  );

  testWidgets(
    'kehilangan proses WebView menahan Form sampai pengawas menyetujui muat ulang',
    (tester) async {
      var inspected = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RestrictedFormView(
              url: Uri.parse(form),
              onInspected: (value) => inspected = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      platform.delegate.started(form);
      platform.delegate.finished(form);
      await tester.pumpAndSettle();
      expect(inspected, isTrue);
      expect(find.text('Form native'), findsOneWidget);

      platform.delegate.resourceError(
        const WebResourceError(
          errorCode: -1,
          description: 'WebView renderer process gone',
          isForMainFrame: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(inspected, isFalse);
      expect(find.text('Form native'), findsNothing);
      expect(find.textContaining('Form gagal dimuat'), findsOneWidget);
      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Muat ulang Form?'), findsOneWidget);
    },
  );

  testWidgets(
    'hasil inspeksi terlambat tidak membuka halaman baru; upload ditolak',
    (tester) async {
      var inspected = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RestrictedFormView(
              url: Uri.parse(form),
              onInspected: (value) => inspected = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final lateResult = Completer<Object>();
      platform.controller.pendingResult = lateResult.future;
      platform.delegate.started(form);
      platform.delegate.finished(form);
      platform.delegate.started('$form?usp=next');
      lateResult.complete('{"hasForm":true,"upload":false}');
      await tester.pump();
      expect(inspected, isFalse);
      expect(find.text('Form native'), findsNothing);
      platform.controller.pendingResult = null;
      platform.controller.result = '{"hasForm":true,"upload":true}';
      platform.delegate.finished('$form?usp=next');
      await tester.pumpAndSettle();
      expect(inspected, isFalse);
      expect(find.textContaining('Form ditutup'), findsOneWidget);
      expect(find.text('Form native'), findsNothing);
    },
  );
}

class _Platform extends WebViewPlatform {
  bool failFirstSetup = false;
  int creations = 0;
  late _Controller controller;
  late _Delegate delegate;
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller = _Controller(
    params,
    failSetup: failFirstSetup && creations++ == 0,
  );
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => delegate = _Delegate(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _View(params);
}

class _View extends PlatformWebViewWidget {
  _View(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const Text('Form native');
}

class _Controller extends PlatformWebViewController {
  _Controller(super.params, {this.failSetup = false}) : super.implementation();
  final bool failSetup;
  final loaded = <String>[];
  Object result = '{"hasForm":true,"upload":false}';
  Future<Object>? pendingResult;
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {
    if (failSetup) throw StateError('gagal konfigurasi');
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loaded.add(params.uri.toString());
  }

  @override
  Future<Object> runJavaScriptReturningResult(String script) async =>
      pendingResult ?? result;
}

class _Delegate extends PlatformNavigationDelegate {
  _Delegate(super.params) : super.implementation();
  late NavigationRequestCallback navigate;
  late PageEventCallback started;
  late PageEventCallback finished;
  late WebResourceErrorCallback resourceError;
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {
    navigate = callback;
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async {
    started = callback;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {
    finished = callback;
  }

  @override
  Future<void> setOnProgress(ProgressCallback callback) async {}
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {
    resourceError = callback;
  }

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback callback) async {}
}
