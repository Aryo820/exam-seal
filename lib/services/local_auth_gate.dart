import 'package:local_auth/local_auth.dart';

class DeviceAuthenticationUnavailable implements Exception {
  const DeviceAuthenticationUnavailable();
}

/// Gerbang autentikasi perangkat untuk melihat ulang PIN pengawas di HP
/// pembuat sesi (PRD FR01/Q04): local_auth dahulu, baru baca rahasia dari
/// secure storage.
abstract final class LocalAuthGate {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isDeviceSupported() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    if (!await isDeviceSupported()) {
      throw const DeviceAuthenticationUnavailable();
    }
    try {
      return await _auth.authenticate(
        localizedReason:
            'Autentikasi perangkat diperlukan untuk melihat PIN pengawas.',
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
