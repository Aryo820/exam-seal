import 'package:examseal/main.dart' show startExamSeal;
import 'package:examseal/services/exam_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('gagal membuka penyimpanan menampilkan pemulihan pengawas', (
    tester,
  ) async {
    var calls = 0;

    Future<ExamSessionController> openFailure() async {
      calls++;
      throw StateError('penyimpanan tidak tersedia');
    }

    await startExamSeal(openController: openFailure);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Penyimpanan ujian tidak dapat dibuka'),
      findsOneWidget,
    );
    expect(find.text('Pilih mode'), findsNothing);
    await tester.tap(find.text('Coba Pulihkan'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });
}
