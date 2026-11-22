import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';

/// A stored entry as JSON, keyed by its identity (an intake's id, a weight
/// entry's day, a template's name, ...).
typedef SyncRecords = Map<String, Map<String, dynamic>>;

/// The fingerprint of each entry as it stood after the last sync with a
/// given phone, keyed like [SyncRecords]. Both phones store the same one.
typedef SyncBase = Map<String, String>;

/// A stable fingerprint of [record]: SHA-256 over its JSON with every map's
/// keys sorted, so the same entry hashes the same on both phones whatever
/// order its fields were written in.
String syncFingerprint(Map<String, dynamic> record) {
  final bytes = utf8.encode(jsonEncode(_canonical(record)));
  final digest = SHA256Digest().process(Uint8List.fromList(bytes));
  return base64Url.encode(digest).substring(0, 43);
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

/// What a sync does to one kind of entry on this phone.
class SyncMergeResult {
  /// Entries to store here, added or replacing the local version.
  final SyncRecords upserts;

  /// Entries to remove here.
  final Set<String> deletes;

  /// Fingerprints of the merged collection, the next sync's base. Both
  /// phones compute the same.
  final SyncBase mergedBase;

  /// Entries both phones changed differently since the last sync; the
  /// hosting phone's version was kept.
  final int conflicts;

  int get added => upserts.keys.where((id) => !_hadLocally.contains(id)).length;
  int get updated => upserts.length - added;
  int get removed => deletes.length;

  final Set<String> _hadLocally;

  SyncMergeResult._({
    required this.upserts,
    required this.deletes,
    required this.mergedBase,
    required this.conflicts,
    required Set<String> hadLocally,
  }) : _hadLocally = hadLocally;

  bool get changesAnything => upserts.isNotEmpty || deletes.isNotEmpty;
}

/// Merges one kind of entry between this phone ([local]) and the other one
/// ([remote]) against the [base] both stored after their last sync — a
/// three-way merge, like a sync server would do, so a deletion on one phone
/// is not undone by the other phone still having the entry.
///
/// Per entry:
///  * unchanged on one side since the base → the other side's version wins,
///    including its deletion;
///  * new on one side (not in the base) → added on the other;
///  * deleted on one side and edited on the other → the edit is kept, so
///    nothing written since the last sync is lost;
///  * edited differently on both → the hosting phone's version
///    ([localIsHost] on the phone showing the QR code), counted in
///    [SyncMergeResult.conflicts].
///
/// With no [base] (the first sync between two phones) nothing is deleted:
/// the result is the union, the host winning where both hold an entry.
///
/// Both phones run this on the same three inputs with opposite
/// [localIsHost], so they end with the same collection and the same next
/// base.
SyncMergeResult mergeSyncRecords({
  required SyncRecords local,
  required SyncRecords remote,
  required SyncBase? base,
  required bool localIsHost,
}) {
  final localPrints = {
    for (final MapEntry(:key, :value) in local.entries)
      key: syncFingerprint(value),
  };
  final remotePrints = {
    for (final MapEntry(:key, :value) in remote.entries)
      key: syncFingerprint(value),
  };
  final ids = {...local.keys, ...remote.keys, ...?base?.keys};

  final upserts = <String, Map<String, dynamic>>{};
  final deletes = <String>{};
  final merged = <String, String>{};
  var conflicts = 0;

  for (final id in ids) {
    final l = localPrints[id];
    final r = remotePrints[id];
    final b = base?[id];

    // Which side's version (null: deleted / absent) the merge keeps.
    final _Side keep;
    if (l == r) {
      keep = _Side.local;
    } else if (b == null) {
      // Not in the base: new since the last sync, or a first sync.
      if (l == null) {
        keep = _Side.remote;
      } else if (r == null) {
        keep = _Side.local;
      } else {
        conflicts++;
        keep = localIsHost ? _Side.local : _Side.remote;
      }
    } else if (l == b) {
      keep = _Side.remote; // only the other phone changed it
    } else if (r == b) {
      keep = _Side.local; // only this phone changed it
    } else if (l == null) {
      keep = _Side.remote; // deleted here, edited there: keep the edit
    } else if (r == null) {
      keep = _Side.local; // edited here, deleted there: keep the edit
    } else {
      conflicts++;
      keep = localIsHost ? _Side.local : _Side.remote;
    }

    if (keep == _Side.remote) {
      if (r == null) {
        if (l != null) deletes.add(id);
      } else if (r != l) {
        upserts[id] = remote[id]!;
      }
    }
    final kept = keep == _Side.local ? l : r;
    if (kept != null) merged[id] = kept;
  }

  return SyncMergeResult._(
    upserts: upserts,
    deletes: deletes,
    mergedBase: merged,
    conflicts: conflicts,
    hadLocally: local.keys.toSet(),
  );
}

enum _Side { local, remote }
