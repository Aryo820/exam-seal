import 'package:examseal/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('active student session protects teacher mode with PIN', (
    tester,
  ) async {
    var resumed = false;
    var teacherModeOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          hasActiveStudentSession: true,
          verifySupervisorPin: (pin) => pin == '01234',
          onResumeStudentSession: () => resumed = true,
          onOpenTeacherMode: () => teacherModeOpened = true,
        ),
      ),
    );

    await tester.tap(find.text('Guru'));
    await tester.pumpAndSettle();
    expect(find.text('Buka mode guru?'), findsOneWidget);
    expect(find.text('PIN pengawas diperlukan.'), findsOneWidget);

    await tester.tap(find.text('Kembali ke Ujian'));
    await tester.pumpAndSettle();
    expect(resumed, isTrue);
    expect(teacherModeOpened, isFalse);

    resumed = false;
    await tester.tap(find.text('Guru'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masukkan PIN Pengawas'));
    await tester.pumpAndSettle();
    expect(find.text('Buka mode guru'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '01234');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.ensureVisible(find.text('Verifikasi PIN'));
    await tester.tap(find.text('Verifikasi PIN'));
    await tester.pumpAndSettle();

    expect(teacherModeOpened, isTrue);
    expect(resumed, isFalse);
    expect(tester.takeException(), isNull);
  });
}
