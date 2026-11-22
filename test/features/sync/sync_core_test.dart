import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/sync/domain/sync_cipher.dart';
import 'package:opennutritracker/features/sync/domain/sync_merge.dart';
import 'package:opennutritracker/features/sync/domain/sync_offer.dart';

Map<String, dynamic> entry(String name, double amount) => {
      'name': name,
      'amount': amount,
    };

/// Runs the merge on both phones, as a sync does, and checks they agree.
({SyncMergeResult host, SyncMergeResult join}) syncBoth(
  SyncRecords host,
  SyncRecords join,
  SyncBase? base,
) {
  final h = mergeSyncRecords(
    local: host,
    remote: join,
    base: base,
    localIsHost: true,
  );
  final j = mergeSyncRecords(
    local: join,
    remote: host,
    base: base,
    localIsHost: false,
  );
  SyncRecords apply(SyncRecords local, SyncMergeResult result) => {
        for (final MapEntry(:key, :value) in local.entries)
          if (!result.deletes.contains(key)) key: value,
        ...result.upserts,
      };
  final hostAfter = apply(host, h);
  final joinAfter = apply(join, j);
  expect(jsonEncode(_sorted(hostAfter)), jsonEncode(_sorted(joinAfter)),
      reason: 'both phones end with the same entries');
  expect(h.mergedBase, j.mergedBase, reason: 'and store the same base');
  return (host: h, join: j);
}

Map<String, dynamic> _sorted(SyncRecords records) =>
    {for (final key in (records.keys.toList()..sort())) key: records[key]};

SyncBase baseOf(SyncRecords records) => {
      for (final MapEntry(:key, :value) in records.entries)
        key: syncFingerprint(value),
    };

void main() {
  group('three-way merge', () {
    test('a first sync is the union, nothing deleted', () {
      final r = syncBoth(
        {'a': entry('oats', 50)},
        {'b': entry('apple', 120)},
        null,
      );
      expect(r.host.upserts.keys, ['b']);
      expect(r.join.upserts.keys, ['a']);
      expect(r.host.deletes, isEmpty);
      expect(r.join.deletes, isEmpty);
    });

    test('an entry deleted on one phone is deleted on the other', () {
      final before = {'a': entry('oats', 50), 'b': entry('apple', 120)};
      final r = syncBoth(
        {'a': entry('oats', 50)}, // host deleted b
        before,
        baseOf(before),
      );
      expect(r.join.deletes, {'b'});
      expect(r.host.upserts, isEmpty, reason: 'b is not brought back');
    });

    test('an edit on one phone reaches the other', () {
      final before = {'a': entry('oats', 50)};
      final r = syncBoth(before, {'a': entry('oats', 80)}, baseOf(before));
      expect(r.host.upserts['a']!['amount'], 80);
      expect(r.host.conflicts, 0);
    });

    test('edited on one phone and deleted on the other: the edit is kept', () {
      final before = {'a': entry('oats', 50)};
      final r = syncBoth({}, {'a': entry('oats', 80)}, baseOf(before));
      expect(r.host.upserts['a']!['amount'], 80);
      expect(r.join.deletes, isEmpty);
    });

    test('edited differently on both: the host wins, counted as a conflict',
        () {
      final before = {'a': entry('oats', 50)};
      final r = syncBoth(
        {'a': entry('oats', 60)},
        {'a': entry('oats', 70)},
        baseOf(before),
      );
      expect(r.host.upserts, isEmpty);
      expect(r.join.upserts['a']!['amount'], 60);
      expect(r.host.conflicts, 1);
      expect(r.join.conflicts, 1);
    });

    test('a second sync with nothing changed does nothing', () {
      final both = {'a': entry('oats', 50), 'b': entry('apple', 120)};
      final r = syncBoth(both, {...both}, baseOf(both));
      expect(r.host.changesAnything, isFalse);
      expect(r.join.changesAnything, isFalse);
    });

    test('weekday on one phone, weekend on the other, two syncs a week', () {
      // Monday to Friday on the iPhone, then sync.
      var iphone = <String, Map<String, dynamic>>{
        'mon': entry('oats', 50),
        'tue': entry('rice', 200),
      };
      var android = <String, Map<String, dynamic>>{};
      var r = syncBoth(iphone, android, null);
      android = {...android, ...r.join.upserts};
      var base = r.host.mergedBase;

      // Weekend on Android: add Saturday, fix Tuesday, delete Monday.
      android = {
        'tue': entry('rice', 150),
        'sat': entry('pizza', 300),
      };
      r = syncBoth(iphone, android, base);
      iphone = {
        for (final MapEntry(:key, :value) in iphone.entries)
          if (!r.host.deletes.contains(key)) key: value,
        ...r.host.upserts,
      };

      expect(iphone.keys.toSet(), {'tue', 'sat'});
      expect(iphone['tue']!['amount'], 150);
      expect(r.host.conflicts, 0);
    });

    test('the fingerprint ignores field order', () {
      expect(
        syncFingerprint({'a': 1, 'b': {'y': 2, 'x': 3}}),
        syncFingerprint({'b': {'x': 3, 'y': 2}, 'a': 1}),
      );
    });
  });

  group('cipher', () {
    test('round-trips, and rejects another key or a flipped byte', () {
      final key = SyncCipher.randomKey();
      final message = Uint8List.fromList(utf8.encode('my diary'));
      final sealed = SyncCipher(key).encrypt(message);

      expect(utf8.decode(SyncCipher(key).decrypt(sealed)), 'my diary');
      expect(
        () => SyncCipher(SyncCipher.randomKey()).decrypt(sealed),
        throwsA(isA<SyncCipherException>()),
      );
      final tampered = Uint8List.fromList(sealed)..[sealed.length - 1] ^= 1;
      expect(
        () => SyncCipher(key).decrypt(tampered),
        throwsA(isA<SyncCipherException>()),
      );
    });

    test('two encryptions of the same data differ (fresh nonce)', () {
      final cipher = SyncCipher(SyncCipher.randomKey());
      final data = Uint8List.fromList([1, 2, 3]);
      expect(cipher.encrypt(data), isNot(cipher.encrypt(data)));
    });
  });

  group('QR offer', () {
    test('round-trips', () {
      final key = SyncCipher.randomKey();
      final offer = SyncOffer.tryParse(
        SyncOffer(hosts: ['192.168.1.20'], port: 40123, key: key).encode(),
      )!;
      expect(offer.hosts, ['192.168.1.20']);
      expect(offer.port, 40123);
      expect(offer.key, key);
    });

    test('ignores other QR codes', () {
      expect(SyncOffer.tryParse('https://example.com'), isNull);
      expect(SyncOffer.tryParse('ONTSYNC1:not-base64!'), isNull);
      expect(SyncOffer.tryParse(null), isNull);
    });
  });
}
