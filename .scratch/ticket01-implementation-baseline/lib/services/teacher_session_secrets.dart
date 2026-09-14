import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Rahasia sesi milik HP pembuat (PRD §7: TeacherSessionSecret). PIN mentah
/// TIDAK disimpan; yang disimpan adalah bahan untuk menampilkan ulang PIN
/// (guru perlu membacanya lagi setelah local_auth). Untuk itu kita menyimpan
/// PIN terenkripsi sederhana? Tidak — menyimpan PIN mentah di secure storage
/// adalah praktik yang diterima PRD ("Bahan PIN disimpan terlindungi;
/// akses ulang melalui autentikasi perangkat"). Secure storage Android
/// (Keystore) adalah tempat yang diminta PRD.
abstract class TeacherSessionSecrets {
  Future<void> savePin(String sessionId, String pin);
  Future<String?> readPin(String sessionId);

  /// Implementasi secure storage asli (flutter_secure_storage).
  static TeacherSessionSecrets secure() => _SecureStorageSecrets();

  /// Implementasi memori untuk pengujian.
  static TeacherSessionSecrets inMemory() => _InMemorySecrets();
}

class _SecureStorageSecrets implements TeacherSessionSecrets {
  const _SecureStorageSecrets();

  static const _storage = FlutterSecureStorage();
  static const _prefix = 'teacher_pin_';

  @override
  Future<void> savePin(String sessionId, String pin) =>
      _storage.write(key: '$_prefix$sessionId', value: pin);

  @override
  Future<String?> readPin(String sessionId) =>
      _storage.read(key: '$_prefix$sessionId');
}

class _InMemorySecrets implements TeacherSessionSecrets {
  final _pins = <String, String>{};

  @override
  Future<void> savePin(String sessionId, String pin) async {
    _pins[sessionId] = pin;
  }

  @override
  Future<String?> readPin(String sessionId) => Future.value(_pins[sessionId]);
}
