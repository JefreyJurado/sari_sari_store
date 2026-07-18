import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final BiometricService instance = BiometricService._();
  BiometricService._();

  final _auth = LocalAuthentication();

  /// Whether this device can actually use biometric unlock right now (has
  /// usable hardware AND at least one biometric enrolled) — checked before
  /// letting the user turn the Settings toggle on, so the app never offers
  /// a switch that would just fail silently every time.
  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Prompts Face/Fingerprint unlock. Returns false — never throws — on
  /// any failure, cancellation, or lockout. Callers always have the PIN
  /// keypad as the guaranteed fallback, so a false result here is a
  /// normal outcome to fall back from, not an error to surface.
  ///
  /// `biometricOnly: true` deliberately excludes the phone's own lock
  /// screen (PIN/pattern/password) as a fallback within this call — this
  /// app already has its own PIN screen for that, and offering two
  /// different PINs (the phone's and the app's) in the same prompt would
  /// only confuse which one is being asked for.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
