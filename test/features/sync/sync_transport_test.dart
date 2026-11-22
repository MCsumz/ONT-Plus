import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/sync/data/sync_transport.dart';
import 'package:opennutritracker/features/sync/domain/sync_cipher.dart';
import 'package:opennutritracker/features/sync/domain/sync_offer.dart';

Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  test('two phones exchange bundles over a socket and acknowledge', () async {
    final host = (await SyncHost.start(
      bytes('host diary'),
      addresses: ['127.0.0.1'],
    ))!;
    final hostSide = host.waitForPartner();

    final joined = await SyncJoin.exchange(host.offer, bytes('join diary'));
    final hosted = await hostSide;

    expect(utf8.decode(joined.remoteBundle), 'host diary');
    expect(utf8.decode(hosted.remoteBundle), 'join diary');

    final ack = hosted.readAck();
    await joined.sendAck(ok: true);
    expect(await ack, isTrue);
  });

  test('a large bundle crosses intact', () async {
    final big = Uint8List.fromList(
      List<int>.generate(3 * 1024 * 1024 + 17, (i) => i % 251),
    );
    final host = (await SyncHost.start(big, addresses: ['127.0.0.1']))!;
    final hostSide = host.waitForPartner();
    final joined = await SyncJoin.exchange(host.offer, bytes('small'));
    await hostSide;
    expect(joined.remoteBundle, big);
    await joined.close();
  });

  test('a connection with the wrong key is dropped and the host keeps waiting',
      () async {
    final host = (await SyncHost.start(
      bytes('host diary'),
      addresses: ['127.0.0.1'],
    ))!;
    final hostSide = host.waitForPartner();

    final stranger = SyncOffer(
      hosts: host.offer.hosts,
      port: host.offer.port,
      key: SyncCipher.randomKey(),
    );
    await expectLater(
      SyncJoin.exchange(stranger, bytes('intruder')),
      throwsA(anything),
    );

    // Random bytes, not even the sync's magic.
    final raw = await Socket.connect('127.0.0.1', host.offer.port);
    raw.add(List<int>.filled(64, 7));
    await raw.flush();
    raw.destroy();

    final joined = await SyncJoin.exchange(host.offer, bytes('join diary'));
    final hosted = await hostSide;
    expect(utf8.decode(hosted.remoteBundle), 'join diary');
    expect(utf8.decode(joined.remoteBundle), 'host diary');
    await joined.close();
  });

  test('private network addresses only', () {
    expect(isPrivateIPv4('192.168.1.20'), isTrue);
    expect(isPrivateIPv4('10.0.0.5'), isTrue);
    expect(isPrivateIPv4('172.20.10.1'), isTrue, reason: 'iPhone hotspot');
    expect(isPrivateIPv4('172.32.0.1'), isFalse);
    expect(isPrivateIPv4('8.8.8.8'), isFalse);
    expect(isPrivateIPv4('100.64.1.1'), isFalse);
  });
}
