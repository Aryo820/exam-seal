import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Bahan verifikasi PIN offline (PRD §7: PinVerificationMaterial). PIN
/// mentah tidak pernah disimpan maupun dibagikan; HP siswa hanya menerima
/// salt dan verifier melalui QR.
///
/// Catatan jujur: verifier QR pada sistem offline lima digit adalah kontrol
/// operasional di kelas dengan pengawas hadir — bukan bukti autentikasi
/// identitas guru dan bukan perlindungan terhadap reverse engineering pada
/// perangkat siswa. Kode dan UI harus mempertahankan batas klaim ini.
class PinVerificationMaterial {
  const PinVerificationMaterial({required this.salt, required this.verifier});

  factory PinVerificationMaterial.fromSessionParts(
    String salt,
    String verifier,
  ) => PinVerificationMaterial(salt: salt, verifier: verifier);

  /// Salt acak (base64) yang dibuat bersama PIN.
  final String salt;

  /// Verifier PBKDF2-HMAC (base64) untuk PIN tersebut.
  final String verifier;
}

/// Status percobaan PIN pada satu sesi/attempt: lima kegagalan berturut-turut
/// memberi jeda 30 detik (PRD FR07). Status ini dipersist dan tetap berlaku
/// setelah aplikasi dibuka ulang.
class PinAttemptState {
  PinAttemptState({this.failedAttempts = 0, this.lockedUntil});

  PinAttemptState.initial() : this();

  int failedAttempts;
  DateTime? lockedUntil;

  static const int maxFailedAttempts = 5;
  static const Duration cooldown = Duration(seconds: 30);

  factory PinAttemptState.fromJson(Map<String, dynamic> json) =>
      PinAttemptState(
        failedAttempts: (json['failedAttempts'] as num).toInt(),
        lockedUntil: json['lockedUntil'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                (json['lockedUntil'] as num).toInt(),
                isUtc: true,
              ),
      );

  Map<String, dynamic> toJson() => {
    'failedAttempts': failedAttempts,
    'lockedUntil': lockedUntil?.millisecondsSinceEpoch,
  };

  bool isLocked({required DateTime now}) {
    final until = lockedUntil;
    return until != null && now.isBefore(until);
  }

  /// Catat kegagalan. Mengembalikan true bila percobaan ini memicu cooldown.
  bool onWrongAttempt({required DateTime now}) {
    failedAttempts++;
    if (failedAttempts >= maxFailedAttempts) {
      lockedUntil = now.add(cooldown);
      return true;
    }
    return false;
  }

  /// PIN benar atau cooldown berakhir: counter mulai nol lagi.
  void onCorrectAttempt() {
    failedAttempts = 0;
    lockedUntil = null;
  }
}

/// Layanan PIN pengawas: pembuatan PIN lima digit dan kode sesi dari
/// `Random.secure()`, pembuatan salt+verifier PBKDF2-HMAC, dan verifikasi
/// PIN. Rahasia milik HP pembuat sesi disimpan lewat secure storage oleh
/// pemanggil, bukan di sini.
abstract final class PinService {
  static final Random _secure = Random.secure();

  /// Parameter PBKDF2-HMAC-SHA256. Offline tanpa server, iterasi menahan
  /// pencobaan cepat; verifikasi tetap cukup cepat untuk interaksi pengawas.
  static const int _pbkdf2Iterations = 50000;
  static const int _saltBytes = 16;
  static const int _keyBits = 256;

  static final Pbkdf2 _pbkdf2 = Pbkdf2.hmacSha256(
    iterations: _pbkdf2Iterations,
    bits: _keyBits,
  );

  /// PIN pengawas lima digit acak (crypto-secure).
  static String generateSupervisorPin() {
    final digits = List.generate(5, (_) => _secure.nextInt(10));
    return digits.join();
  }

  /// Kode sesi pendek yang mudah dibandingkan pengawas secara visual:
  /// tiga karakter awalan dari nama ujian + empat karakter acak.
  static String generateSessionCode({required String seedName}) {
    final letters = seedName.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final prefix =
        (letters.isEmpty ? 'EXM' : letters.substring(0, min(3, letters.length)))
            .padRight(3, 'X');
    final alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = List.generate(
      4,
      (_) => alphabet[_secure.nextInt(alphabet.length)],
    );
    return '$prefix-${random.join()}';
  }

  /// ID sesi unik yang tidak mudah ditebak.
  static String generateSessionId() {
    final bytes = Uint8List.fromList(
      List.generate(16, (_) => _secure.nextInt(256)),
    );
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Buat salt + verifier untuk PIN. PIN mentah hanya diketahui pemanggil;
  /// fungsi ini hanya mengembalikan bahan yang aman dibagikan via QR.
  static Future<PinVerificationMaterial> createVerificationMaterial(
    String pin,
  ) async {
    final salt = Uint8List.fromList(
      List.generate(_saltBytes, (_) => _secure.nextInt(256)),
    );
    final verifier = await _deriveVerifier(pin, salt);
    return PinVerificationMaterial(
      salt: base64Encode(salt),
      verifier: verifier,
    );
  }

  /// Verifikasi PIN terhadap bahan yang tersimpan/dibagikan.
  static Future<bool> verifyPin(
    String pin,
    PinVerificationMaterial material,
  ) async {
    final salt = base64Decode(material.salt);
    final computed = await _deriveVerifier(pin, salt);
    return _constantTimeEquals(computed, material.verifier);
  }

  static Future<String> _deriveVerifier(String pin, List<int> salt) async {
    final key = await _pbkdf2.deriveKeyFromPassword(password: pin, nonce: salt);
    final bytes = await key.extractBytes();
    return base64Encode(bytes);
  }

  /// Perbandingan konstan-waktu untuk verifier base64.
  static bool _constantTimeEquals(String a, String b) {
    final left = a.codeUnits;
    final right = b.codeUnits;
    if (left.length != right.length) return false;
    var diff = 0;
    for (var i = 0; i < left.length; i++) {
      diff |= left[i] ^ right[i];
    }
    return diff == 0;
  }
}
