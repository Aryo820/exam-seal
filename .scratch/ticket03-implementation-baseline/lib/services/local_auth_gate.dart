import 'package:local_auth/local_auth.dart';

/// Gerbang autentikasi perangkat untuk melihat ulang PIN pengawas di HP
/// pembuat sesi (PRD FR01/Q04): local_auth dahulu, baru baca rahasia dari
/// secure storage.
abstract final class LocalAuthGate {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> authenticate() async {
    try {
      final supported =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!supported) return false;
      return await _auth.authenticate(
        localizedReason:
            'Autentikasi perangkat diperlukan untuk melihat PIN pengawas.',
      );
    } catch (_) {
      return false;
    }
  }
}
