import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// AES-256-GCM for the phone-to-phone sync.
///
/// The key travels only in the QR code one phone shows and the other scans,
/// so whoever else connects on the network gets ciphertext it cannot read,
/// and a payload altered on the way fails the tag check instead of being
/// imported. Each message has its own random nonce, which is what makes
/// reusing the one key for both directions safe.
class SyncCipher {
  static const keyLength = 32;
  static const _nonceLength = 12;
  static const _tagBits = 128;

  final Uint8List key;

  SyncCipher(this.key) {
    if (key.length != keyLength) {
      throw ArgumentError.value(key.length, 'key', 'must be $keyLength bytes');
    }
  }

  static Uint8List randomKey() => _randomBytes(keyLength);

  /// The nonce followed by the ciphertext and its tag.
  Uint8List encrypt(Uint8List plaintext) {
    final nonce = _randomBytes(_nonceLength);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(key), _tagBits, nonce, Uint8List(0)),
      );
    final sealed = cipher.process(plaintext);
    return Uint8List(nonce.length + sealed.length)
      ..setAll(0, nonce)
      ..setAll(nonce.length, sealed);
  }

  /// Throws [SyncCipherException] for anything not sealed with [key],
  /// truncated or altered.
  Uint8List decrypt(Uint8List message) {
    if (message.length < _nonceLength + _tagBits ~/ 8) {
      throw const SyncCipherException();
    }
    final nonce = Uint8List.sublistView(message, 0, _nonceLength);
    final sealed = Uint8List.sublistView(message, _nonceLength);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(key), _tagBits, nonce, Uint8List(0)),
      );
    try {
      return cipher.process(sealed);
    } on InvalidCipherTextException {
      throw const SyncCipherException();
    } on ArgumentError {
      throw const SyncCipherException();
    }
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}

/// A payload that was not sealed with this session's key, or was altered.
class SyncCipherException implements Exception {
  const SyncCipherException();

  @override
  String toString() => 'SyncCipherException: payload failed authentication';
}
