import 'package:examseal/services/form_url_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final form = Uri.parse('https://docs.google.com/forms/d/e/ujian/viewform');
  test(
    'short link mengikat satu Form dan hanya endpoint pengerjaan yang diizinkan',
    () {
      final policy = FormNavigationPolicy(Uri.parse('https://forms.gle/ujian'));
      expect(policy.allows(Uri.parse('https://forms.gle/ujian')), isTrue);
      expect(policy.allows(form), isTrue);
      expect(
        policy.allows(form.replace(path: '/forms/d/e/ujian/formResponse')),
        isTrue,
      );
      for (final url in [
        'https://docs.google.com/forms/d/e/lain/viewform',
        'https://docs.google.com/forms/d/e/ujian/viewform?edit2=token',
        'https://docs.google.com/forms/d/e/ujian/edit',
        'https://docs.google.com.evil/forms/d/e/ujian/viewform',
        'https://accounts.google.com/login',
        'https://example.com/',
        'intent://forms',
        'javascript:alert(1)',
        'http://docs.google.com/forms/d/e/ujian/viewform',
        'https://forms.gle/ujian',
      ]) {
        expect(policy.allows(Uri.parse(url)), isFalse, reason: url);
      }
    },
  );
  test(
    'halaman respons bukan bukti submit; hanya halaman tanpa formulir menahan pengulangan',
    () {
      final policy = FormNavigationPolicy(form);
      final response = form.replace(path: '/forms/d/e/ujian/formResponse');
      policy.observePage(response, hasForm: true);
      expect(policy.allows(response), isTrue);
      policy.observePage(response, hasForm: false);
      expect(policy.allows(form), isFalse);
      expect(policy.allows(response), isFalse);
    },
  );
  test(
    'navigasi iframe dibatasi; aset jaringan tidak memakai kebijakan halaman utama',
    () {
      final policy = FormNavigationPolicy(form);
      expect(
        policy.allows(
          Uri.parse('https://www.google.com/recaptcha/api2/anchor'),
          isMainFrame: false,
        ),
        isTrue,
      );
      expect(
        policy.allows(Uri.parse('https://example.com/'), isMainFrame: false),
        isFalse,
      );
      expect(
        policy.allows(
          Uri.parse('https://accounts.google.com/'),
          isMainFrame: false,
        ),
        isFalse,
      );
      expect(policy.allows(form), isTrue);
    },
  );
}
