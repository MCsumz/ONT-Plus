import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:opennutritracker/features/sync/domain/sync_cipher.dart';
import 'package:opennutritracker/features/sync/domain/sync_offer.dart';

/// Bytes moved so far out of the total, for a progress bar.
typedef SyncProgress = void Function(int done, int total);

/// The wire format: a magic, a version byte, a big-endian length and the
/// sealed bundle. After both bundles have crossed, the joining phone sends
/// one byte once it has applied the merge.
class _Frame {
  static const magic = [0x4F, 0x4E, 0x54, 0x53]; // "ONTS"
  static const version = 1;
  static const headerLength = 4 + 1 + 8;

  /// Larger than any diary with photos; a length beyond it is not a bundle.
  static const maxPayload = 1024 * 1024 * 1024;

  static const ackOk = 1;
  static const ackFailed = 2;

  static Uint8List header(int length) {
    final header = ByteData(headerLength);
    for (var i = 0; i < magic.length; i++) {
      header.setUint8(i, magic[i]);
    }
    header.setUint8(4, version);
    header.setUint64(5, length);
    return header.buffer.asUint8List();
  }
}

/// Reads exact byte counts from a socket.
class _SocketReader {
  final StreamIterator<Uint8List> _input;
  final Duration idleTimeout;
  Uint8List _pending = Uint8List(0);

  _SocketReader(Socket socket, {required this.idleTimeout})
    : _input = StreamIterator(socket);

  Future<Uint8List> read(int count, {SyncProgress? onProgress}) async {
    final out = BytesBuilder(copy: false);
    var have = 0;
    void take(Uint8List chunk) {
      final need = count - have;
      if (chunk.length <= need) {
        out.add(chunk);
        have += chunk.length;
      } else {
        out.add(Uint8List.sublistView(chunk, 0, need));
        _pending = Uint8List.sublistView(chunk, need);
        have = count;
      }
    }

    if (_pending.isNotEmpty) {
      final pending = _pending;
      _pending = Uint8List(0);
      take(pending);
    }
    while (have < count) {
      final more = await _input.moveNext().timeout(idleTimeout);
      if (!more) throw const SocketException('Connection closed early');
      take(_input.current);
      onProgress?.call(have, count);
    }
    return out.takeBytes();
  }

  Future<Uint8List> readFrame({SyncProgress? onProgress}) async {
    final header = ByteData.sublistView(await read(_Frame.headerLength));
    for (var i = 0; i < _Frame.magic.length; i++) {
      if (header.getUint8(i) != _Frame.magic[i]) {
        throw const SocketException('Not an ONT+ sync');
      }
    }
    if (header.getUint8(4) != _Frame.version) {
      throw const SocketException('Unsupported sync version');
    }
    final length = header.getUint64(5);
    if (length <= 0 || length > _Frame.maxPayload) {
      throw const SocketException('Implausible bundle size');
    }
    return read(length, onProgress: onProgress);
  }

  Future<void> cancel() => _input.cancel();
}

Future<void> _writeFrame(
  Socket socket,
  Uint8List payload, {
  SyncProgress? onProgress,
}) async {
  socket.add(_Frame.header(payload.length));
  const chunk = 64 * 1024;
  for (var offset = 0; offset < payload.length; offset += chunk) {
    final end = (offset + chunk).clamp(0, payload.length);
    socket.add(Uint8List.sublistView(payload, offset, end));
    await socket.flush();
    onProgress?.call(end, payload.length);
  }
}

/// The IPv4 addresses of this phone on private networks — home Wi-Fi or a
/// hotspot — which is all the sync ever listens on or offers.
Future<List<String>> privateIPv4Addresses() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  );
  final addresses = [
    for (final interface in interfaces)
      for (final address in interface.addresses)
        if (isPrivateIPv4(address.address)) address.address,
  ];
  int rank(String a) => a.startsWith('192.168.')
      ? 0
      : a.startsWith('10.')
      ? 1
      : 2;
  addresses.sort((a, b) => rank(a).compareTo(rank(b)));
  return addresses.toSet().toList();
}

bool isPrivateIPv4(String address) {
  final parts = address.split('.').map(int.tryParse).toList();
  if (parts.length != 4 || parts.any((p) => p == null)) return false;
  final a = parts[0]!, b = parts[1]!;
  return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
}

/// The two bundles have crossed; what is left is the acknowledgement.
class SyncExchange {
  final Uint8List remoteBundle;
  final Socket _socket;
  final _SocketReader _reader;

  SyncExchange._(this.remoteBundle, this._socket, this._reader);

  /// Joining phone: tells the host whether the merge was applied here.
  Future<void> sendAck({required bool ok}) async {
    _socket.add([ok ? _Frame.ackOk : _Frame.ackFailed]);
    await _socket.flush();
    await close();
  }

  /// Hosting phone: whether the joining phone applied the merge; null when
  /// it went away without saying.
  Future<bool?> readAck({Duration timeout = const Duration(minutes: 3)}) async {
    try {
      final byte = await _reader.read(1).timeout(timeout);
      return byte.first == _Frame.ackOk;
    } catch (_) {
      return null;
    } finally {
      await close();
    }
  }

  Future<void> close() async {
    await _reader.cancel();
    _socket.destroy();
  }
}

/// The phone that shows the QR code. It listens until one phone with the
/// right key has exchanged bundles, or until [close].
class SyncHost {
  final ServerSocket _server;
  final SyncCipher _cipher;
  final SyncOffer offer;
  final Uint8List _sealedBundle;

  SyncHost._(this._server, this._cipher, this.offer, this._sealedBundle);

  /// Starts listening with this phone's [bundle]. [addresses] overrides the
  /// network lookup (tests use loopback). Returns null when this phone is
  /// on no private network to offer.
  static Future<SyncHost?> start(
    Uint8List bundle, {
    List<String>? addresses,
  }) async {
    final hosts = addresses ?? await privateIPv4Addresses();
    if (hosts.isEmpty) return null;
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    final key = SyncCipher.randomKey();
    final cipher = SyncCipher(key);
    return SyncHost._(
      server,
      cipher,
      SyncOffer(hosts: hosts, port: server.port, key: key),
      cipher.encrypt(bundle),
    );
  }

  /// Waits for the joining phone. A connection that is not a sync with this
  /// session's key — another device, a stale code — is dropped and the
  /// wait goes on.
  Future<SyncExchange> waitForPartner({
    SyncProgress? onReceive,
    SyncProgress? onSend,
    void Function()? onConnected,
  }) async {
    await for (final socket in _server) {
      final reader = _SocketReader(
        socket,
        idleTimeout: const Duration(seconds: 60),
      );
      try {
        onConnected?.call();
        final sealed = await reader.readFrame(onProgress: onReceive);
        final remote = _cipher.decrypt(sealed);
        await _writeFrame(socket, _sealedBundle, onProgress: onSend);
        await close();
        return SyncExchange._(remote, socket, reader);
      } catch (_) {
        await reader.cancel();
        socket.destroy();
      }
    }
    throw const SocketException('Stopped waiting');
  }

  Future<void> close() => _server.close();
}

/// The phone that scanned the code.
class SyncJoin {
  /// Connects to the host in [offer], sends this phone's [bundle] and
  /// returns the host's. Tries each offered address in turn.
  static Future<SyncExchange> exchange(
    SyncOffer offer,
    Uint8List bundle, {
    SyncProgress? onSend,
    SyncProgress? onReceive,
  }) async {
    final cipher = SyncCipher(offer.key);
    Object? lastError;
    for (final host in offer.hosts) {
      Socket socket;
      try {
        socket = await Socket.connect(
          host,
          offer.port,
          timeout: const Duration(seconds: 6),
        );
      } catch (e) {
        lastError = e;
        continue;
      }
      final reader = _SocketReader(
        socket,
        idleTimeout: const Duration(seconds: 90),
      );
      try {
        await _writeFrame(socket, cipher.encrypt(bundle), onProgress: onSend);
        final sealed = await reader.readFrame(onProgress: onReceive);
        return SyncExchange._(cipher.decrypt(sealed), socket, reader);
      } catch (e) {
        await reader.cancel();
        socket.destroy();
        rethrow;
      }
    }
    throw lastError ?? const SocketException('No address to connect to');
  }
}
