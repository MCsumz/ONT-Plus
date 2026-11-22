import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:opennutritracker/features/sync/domain/sync_merge.dart';
import 'package:path_provider/path_provider.dart';

/// What two phones agreed on at the end of their last sync: an id both
/// stored, and the fingerprints of every entry per kind of entry.
class SyncBaseRecord {
  final String baseId;
  final Map<String, SyncBase> collections;

  const SyncBaseRecord(this.baseId, this.collections);

  Map<String, dynamic> toJson() => {'id': baseId, 'collections': collections};

  factory SyncBaseRecord.fromJson(Map<String, dynamic> json) =>
      SyncBaseRecord(json['id'] as String, {
        for (final MapEntry(:key, :value)
            in (json['collections'] as Map<String, dynamic>).entries)
          key: (value as Map<String, dynamic>).cast<String, String>(),
      });
}

/// Local, unsynced bookkeeping for the phone-to-phone sync: this install's
/// device id and, per profile and partner phone, the base of the last sync.
///
/// Kept in the app's support directory, outside the encrypted database: it
/// holds fingerprints and ids, no diary content. It goes with the app, so a
/// reinstall gets a new device id and starts its next sync as a first one.
class SyncStore {
  final Future<Directory> Function() _rootDir;

  SyncStore({Future<Directory> Function()? rootDir})
    : _rootDir = rootDir ?? getApplicationSupportDirectory;

  Future<Directory> _dir() async {
    final dir = Directory('${(await _rootDir()).path}/ont_sync');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> deviceId() async {
    final file = File('${(await _dir()).path}/device_id');
    if (await file.exists()) {
      final id = (await file.readAsString()).trim();
      if (id.isNotEmpty) return id;
    }
    final id = newId();
    await file.writeAsString(id, flush: true);
    return id;
  }

  static String newId() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(18, (_) => random.nextInt(256)));
  }

  String _baseName(String profileId, String partnerId) =>
      'base_${base64Url.encode(utf8.encode('$profileId|$partnerId'))}.json';

  Future<SyncBaseRecord?> readBase(String profileId, String partnerId) async {
    final file = File(
      '${(await _dir()).path}/${_baseName(profileId, partnerId)}',
    );
    if (!await file.exists()) return null;
    try {
      return SyncBaseRecord.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    } catch (_) {
      // A damaged record only costs the next sync its deletions.
      return null;
    }
  }

  Future<void> writeBase(
    String profileId,
    String partnerId,
    SyncBaseRecord record,
  ) async {
    final dir = await _dir();
    final file = File('${dir.path}/${_baseName(profileId, partnerId)}');
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(record.toJson()), flush: true);
    await tmp.rename(file.path);
  }

  /// The base id this phone holds for every partner, sent in a bundle so the
  /// other phone can check both stored the same base.
  Future<Map<String, String>> baseIdsFor(String profileId) async {
    final dir = await _dir();
    final ids = <String, String>{};
    await for (final entity in dir.list()) {
      final name = entity.uri.pathSegments.last;
      if (entity is! File ||
          !name.startsWith('base_') ||
          !name.endsWith('.json')) {
        continue;
      }
      try {
        final pair = utf8.decode(
          base64Url.decode(name.substring(5, name.length - 5)),
        );
        final sep = pair.indexOf('|');
        if (sep < 0 || pair.substring(0, sep) != profileId) continue;
        final record = SyncBaseRecord.fromJson(
          jsonDecode(await entity.readAsString()) as Map<String, dynamic>,
        );
        ids[pair.substring(sep + 1)] = record.baseId;
      } catch (_) {
        continue;
      }
    }
    return ids;
  }
}
