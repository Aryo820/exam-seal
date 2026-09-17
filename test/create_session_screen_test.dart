import 'package:examseal/screens/create_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('T02 rejects deceptive links and submits valid session data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? createdName;
    Uri? createdUrl;
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => CreateSessionScreen(
                        createSession: (name, url) {
                          createdName = name;
                          createdUrl = url;
                          return true;
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Buka T02'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka T02'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '  Matematika  ');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'https://docs.google.com.evil/forms/d/example/viewform',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Buat QR Ujian'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Buat QR Ujian'),
    );
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -120),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Buat QR Ujian'));
    await tester.pump();

    expect(
      find.text(
        'Gunakan link forms.gle atau docs.google.com/forms yang valid.',
      ),
      findsOneWidget,
    );
    expect(createdName, isNull);

    await tester.enterText(
      find.byType(TextFormField).at(1),
      'https://docs.google.com/forms/d/e/example/viewform',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Buat QR Ujian'),
    );
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -120),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Buat QR Ujian'));
    await tester.pumpAndSettle();

    expect(createdName, 'Matematika');
    expect(createdUrl?.host, 'docs.google.com');
    expect(result, isTrue);
    expect(tester.takeException(), isNull);
  });
}
