import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

abstract final class SessionIdentifiers {
  static final _random = Random.secure();

  static String code(String examName) {
    final letters = examName.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final prefix =
        (letters.isEmpty ? 'EXM' : letters.substring(0, min(3, letters.length)))
            .padRight(3, 'X');
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final suffix = List.generate(
      4,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
    return '$prefix-$suffix';
  }

  static String id() => base64Url
      .encode(
        Uint8List.fromList(List.generate(16, (_) => _random.nextInt(256))),
      )
      .replaceAll('=', '');
}
