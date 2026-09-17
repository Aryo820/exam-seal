import 'package:examseal/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('active student session opens teacher mode without PIN', (
    tester,
  ) async {
    var resumed = false;
    var teacherModeOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          hasActiveStudentSession: true,
          onResumeStudentSession: () => resumed = true,
          onOpenTeacherMode: () => teacherModeOpened = true,
        ),
      ),
    );

    await tester.tap(find.text('Guru'));
    await tester.pumpAndSettle();
    expect(find.text('Buka mode guru?'), findsOneWidget);
    expect(find.textContaining('PIN'), findsNothing);

    await tester.tap(find.text('Kembali ke Ujian'));
    await tester.pumpAndSettle();
    expect(resumed, isTrue);

    await tester.tap(find.text('Guru'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buka Mode Guru'));
    await tester.pumpAndSettle();
    expect(teacherModeOpened, isTrue);
  });
}
