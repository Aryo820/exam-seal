import 'package:examseal/services/local_auth_gate.dart';
// ignore: depend_on_referenced_packages
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'melanjutkan autentikasi ketika UI kunci layar melatarbelakangi aplikasi',
    () async {
      final previous = LocalAuthPlatform.instance;
      final platform = _BackgroundingAuthPlatform();
      LocalAuthPlatform.instance = platform;
      addTearDown(() => LocalAuthPlatform.instance = previous);

      expect(await LocalAuthGate.authenticate(), isTrue);
      expect(platform.options?.stickyAuth, isTrue);
      expect(platform.options?.biometricOnly, isFalse);
    },
  );
}

class _BackgroundingAuthPlatform extends LocalAuthPlatform {
  AuthenticationOptions? options;

  @override
  Future<bool> deviceSupportsBiometrics() async => false;

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    this.options = options;
    return options.stickyAuth;
  }
}
