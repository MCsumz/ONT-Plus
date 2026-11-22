import 'dart:convert';
import 'dart:typed_data';

import 'package:opennutritracker/features/sync/domain/sync_cipher.dart';

/// What the hosting phone's QR code carries: where to reach it on the local
/// network and the one-time key for this session.
class SyncOffer {
  static const _prefix = 'ONTSYNC1:';

  /// IPv4 addresses the host listens on, most likely first. A phone on Wi-Fi
  /// and hotspot at once has more than one; the joining phone tries each.
  final List<String> hosts;
  final int port;
  final Uint8List key;

  SyncOffer({required this.hosts, required this.port, required this.key});

  String encode() =>
      _prefix +
      base64Url.encode(
        utf8.encode(
          jsonEncode({'h': hosts, 'p': port, 'k': base64Url.encode(key)}),
        ),
      );

  /// The offer in a scanned code, or null for any other QR code — a shared
  /// meal, a URL — so the scanner can simply keep looking.
  static SyncOffer? tryParse(String? raw) {
    if (raw == null || !raw.startsWith(_prefix)) return null;
    try {
      final json = jsonDecode(
        utf8.decode(base64Url.decode(raw.substring(_prefix.length))),
      );
      if (json is! Map) return null;
      final hosts = (json['h'] as List).cast<String>();
      final port = json['p'] as int;
      final key = base64Url.decode(json['k'] as String);
      if (hosts.isEmpty || port <= 0 || port > 65535) return null;
      if (key.length != SyncCipher.keyLength) return null;
      return SyncOffer(hosts: hosts, port: port, key: key);
    } catch (_) {
      return null;
    }
  }
}
