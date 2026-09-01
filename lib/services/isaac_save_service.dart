import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../domain/models.dart';
import 'knowledge_service.dart';

/// Resultado inmutable de una lectura validada. El lector nunca conserva ni
/// escribe los bytes de la partida fuera de la llamada de parseo.
class IsaacSaveSnapshot {
  const IsaacSaveSnapshot({
    required this.achievements,
    required this.challenges,
    required this.collectibles,
    required this.completionMarks,
    required this.counters,
    required this.formatVersion,
  });

  final List<bool> achievements;
  final List<bool> challenges;
  final List<bool> collectibles;
  final List<List<int>> completionMarks;
  final Map<String, int> counters;
  final int formatVersion;
}

class IsaacSaveFormatException implements Exception {
  const IsaacSaveFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Lector limpio y deliberadamente de solo lectura para ISAACNGSAVE09R.
class IsaacRepentancePlusSaveReader {
  static const _header = 'ISAACNGSAVE09R  ';
  static const _sectionEntryBytes = <int>[1, 4, 4, 1, 1, 1, 1, 4, 4, 1, 583];
  static const _knownLastSectionEntryBytes = <int>{583, 727, 865};
  static const _checksumSeed = 0xFEDCBA76;

  IsaacSaveSnapshot parse(Uint8List bytes) {
    if (bytes.length < 256) {
      throw const IsaacSaveFormatException('El archivo está truncado.');
    }
    final header = ascii.decode(bytes.sublist(0, 16), allowInvalid: true);
    if (header != _header) {
      throw const IsaacSaveFormatException(
        'La cabecera no corresponde a Repentance+ para PC.',
      );
    }
    final storedChecksum = _uint32(bytes, bytes.length - 4);
    final calculatedChecksum = _checksum(bytes, 16, bytes.length - 4);
    if (storedChecksum != calculatedChecksum) {
      throw const IsaacSaveFormatException(
        'El checksum no es válido; se conserva el último progreso correcto.',
      );
    }

    final offsets = <int>[];
    final counts = <int>[];
    var cursor = 0x14;
    for (var section = 0; section < _sectionEntryBytes.length; section++) {
      if (cursor + 12 > bytes.length - 4) {
        throw const IsaacSaveFormatException(
            'Falta la cabecera de una sección.');
      }
      final sectionId = _uint32(bytes, cursor);
      final declaredSize = _uint32(bytes, cursor + 4);
      final entryCount = _uint32(bytes, cursor + 8);
      cursor += 12;
      if (sectionId != section + 1 || declaredSize < entryCount) {
        throw IsaacSaveFormatException(
            'La sección ${section + 1} es desconocida.');
      }
      var entryBytes = _sectionEntryBytes[section];
      if (section == _sectionEntryBytes.length - 1 && entryCount > 0) {
        final remaining = bytes.length - 4 - cursor;
        final detected = remaining ~/ entryCount;
        final declaredOnlineWidth =
            declaredSize.isEven ? declaredSize ~/ 2 + 9 : -1;
        final supportedLayout =
            _knownLastSectionEntryBytes.contains(detected) ||
                (detected == declaredOnlineWidth &&
                    detected >= 583 &&
                    detected <= 4096 &&
                    entryCount <= 16);
        if (remaining % entryCount != 0 || !supportedLayout) {
          throw const IsaacSaveFormatException(
            'La versión de los registros online del guardado no es compatible.',
          );
        }
        entryBytes = detected;
      }
      final byteLength = entryCount * entryBytes;
      if (entryCount > 100000 || cursor + byteLength > bytes.length - 4) {
        throw IsaacSaveFormatException(
            'La longitud de la sección ${section + 1} no es válida.');
      }
      offsets.add(cursor);
      counts.add(entryCount);
      cursor += byteLength;
    }
    if (cursor != bytes.length - 4 ||
        counts[0] < 642 ||
        counts[3] < 733 ||
        counts[6] < 46) {
      throw IsaacSaveFormatException(
        'La estructura no coincide con el snapshot Repentance+ compatible '
        '(fin=$cursor/${bytes.length - 4}, secciones=$counts).',
      );
    }

    final achievements = List<bool>.generate(
      641,
      (index) => bytes[offsets[0] + index + 1] != 0,
      growable: false,
    );
    final collectibles = List<bool>.generate(
      732,
      (index) => bytes[offsets[3] + index + 1] != 0,
      growable: false,
    );
    final challenges = List<bool>.generate(
      45,
      (index) => bytes[offsets[6] + index + 1] != 0,
      growable: false,
    );
    final marks = List<List<int>>.generate(
      34,
      (character) => List<int>.generate(
        12,
        (mark) =>
            _soloDifficulty(bytes[_markOffset(offsets[1], character, mark)]),
        growable: false,
      ),
      growable: false,
    );
    final stats = <String, int>{
      'donation': _uint32(bytes, offsets[1]),
      'mom-kills': _uint32(bytes, offsets[1] + 0x04),
      'rocks-broken': _uint32(bytes, offsets[1] + 0x08),
      'deaths': _uint32(bytes, offsets[1] + 0x24),
      'shopkeeper-kills': _uint32(bytes, offsets[1] + 0x2C),
      'donation-coins': _uint32(bytes, offsets[1] + 0x4C),
      'eden-tokens': _uint32(bytes, offsets[1] + 0x54),
      'win-streak': _uint32(bytes, offsets[1] + 0x58),
      'best-streak': _uint32(bytes, offsets[1] + 0x5C),
    };
    return IsaacSaveSnapshot(
      achievements: achievements,
      challenges: challenges,
      collectibles: collectibles,
      completionMarks: marks,
      counters: stats,
      formatVersion: bytes[0x18],
    );
  }

  int _markOffset(int sectionOffset, int character, int mark) {
    var offset = character == 14
        ? sectionOffset + 0x32C
        : character > 14
            ? sectionOffset + 0x31C
            : sectionOffset + 0x6C;
    for (var current = 0; current <= mark; current++) {
      final result = character == 14
          ? offset + current * 4
          : character > 14
              ? offset + character * 4 + current * 19 * 4
              : offset + character * 4 + current * 14 * 4;
      if (current == mark) return result;
      if (character == 14) {
        if (current == 8) offset += 0x04;
        if (current == 9) offset += 0x37C;
        if (current == 10) offset += 0x84;
      } else if (character > 14) {
        if (current == 8) offset += 0x4C;
        if (current == 9 || current == 10) offset += 0x3C;
      } else {
        if (current == 5) offset += 0x14;
        if (current == 8) offset += 0x3C;
        if (current == 9) offset += 0x3B0;
        if (current == 10) offset += 0x50;
      }
    }
    throw RangeError.index(mark, List<void>.filled(12, null));
  }

  int _soloDifficulty(int encoded) {
    final value = encoded & 0x03;
    return value == 3 ? 2 : value;
  }

  int _uint32(Uint8List bytes, int offset) =>
      ByteData.sublistView(bytes).getUint32(offset, Endian.little);

  int _checksum(Uint8List bytes, int start, int end) {
    var checksum = (~_checksumSeed).toUnsigned(32);
    final table = _crcTable;
    for (var index = start; index < end; index++) {
      checksum = (table[(checksum & 0xFF) ^ bytes[index]] ^ (checksum >>> 8))
          .toUnsigned(32);
    }
    return (~checksum).toUnsigned(32);
  }

  static final List<int> _crcTable = List<int>.generate(256, (index) {
    var value = index;
    for (var bit = 0; bit < 8; bit++) {
      final signedShift = value.toSigned(32) >> 1;
      value = ((value & 1) == 1 ? signedShift ^ 0xEDB88320 : signedShift)
          .toUnsigned(32);
    }
    return value;
  }, growable: false);
}

class IsaacSaveSyncService {
  IsaacSaveSyncService(this.knowledge, {IsaacRepentancePlusSaveReader? reader})
      : reader = reader ?? IsaacRepentancePlusSaveReader();

  final KnowledgeService knowledge;
  final IsaacRepentancePlusSaveReader reader;
  final List<StreamSubscription<FileSystemEvent>> _watchers = [];
  final Map<String, Timer> _debounces = {};
  bool _disposed = false;

  Future<void> start() async {
    for (final outline in knowledge.rootPageOutlines()) {
      final isIsaacRoot =
          outline.title.toLowerCase().contains('binding of isaac');
      if (!isIsaacRoot) continue;
      final page = knowledge.pageById(outline.id);
      if (page != null) await _startRoot(page);
    }
  }

  Future<void> _startRoot(KnowledgePage root) async {
    var source = knowledge.importSource(root.id, 'isaac-save');
    if (source == null || !File(source.path).existsSync()) {
      final candidates = discoverSaveFiles();
      final slotOne =
          candidates.where((file) => _slotOf(file.path) == 1).toList();
      final chosen = candidates.length == 1
          ? candidates.first
          : slotOne.length == 1
              ? slotOne.first
              : null;
      if (chosen == null) return;
      source = KnowledgeImportSource(
        rootPageId: root.id,
        kind: 'isaac-save',
        path: chosen.path,
        slot: _slotOf(chosen.path),
        enabled: true,
      );
      knowledge.saveImportSource(source);
    }
    if (!source.enabled) return;
    await _readStable(root, source);
    final directory = File(source.path).parent;
    _watchers.add(directory.watch().listen((event) {
      if (_disposed || event.path.toLowerCase() != source!.path.toLowerCase()) {
        return;
      }
      _debounces[root.id]?.cancel();
      _debounces[root.id] = Timer(
        const Duration(milliseconds: 650),
        () => unawaited(_readStable(root, source!)),
      );
    }));
  }

  Future<void> _readStable(
      KnowledgePage root, KnowledgeImportSource source) async {
    final file = File(source.path);
    try {
      if (!await file.exists()) {
        throw const IsaacSaveFormatException(
            'El guardado no está disponible temporalmente.');
      }
      final first = await file.stat();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final second = await file.stat();
      if (first.size != second.size || first.modified != second.modified) {
        _debounces[root.id]?.cancel();
        _debounces[root.id] = Timer(
          const Duration(milliseconds: 700),
          () => unawaited(_readStable(root, source)),
        );
        return;
      }
      if (source.lastModifiedAt != null &&
          source.lastError == null &&
          source.lastModifiedAt!.isAtSameMomentAs(second.modified)) {
        return;
      }
      final snapshot = reader.parse(await file.readAsBytes());
      final values = _progressValues(root.id, snapshot, source.slot);
      knowledge.replaceProgressFromSource(
        rootPageId: root.id,
        source: 'isaac-save',
        values: values,
      );
      knowledge.saveImportSource(KnowledgeImportSource(
        rootPageId: source.rootPageId,
        kind: source.kind,
        path: source.path,
        slot: source.slot,
        enabled: source.enabled,
        lastImportedAt: DateTime.now(),
        lastModifiedAt: second.modified,
      ));
    } catch (error) {
      knowledge.saveImportSource(KnowledgeImportSource(
        rootPageId: source.rootPageId,
        kind: source.kind,
        path: source.path,
        slot: source.slot,
        enabled: source.enabled,
        lastImportedAt: source.lastImportedAt,
        lastModifiedAt: source.lastModifiedAt,
        lastError: error.toString(),
      ));
    }
  }

  Map<String, dynamic> _progressValues(
    String rootPageId,
    IsaacSaveSnapshot snapshot,
    int slot,
  ) {
    final values = <String, dynamic>{
      'isaac.sync.slot': slot,
      'isaac.sync.format': snapshot.formatVersion,
      'isaac.sync.lastSuccessfulAt': DateTime.now().toUtc().toIso8601String(),
    };
    for (var index = 0; index < snapshot.achievements.length; index++) {
      values['isaac.achievement.${index + 1}.unlocked'] =
          snapshot.achievements[index];
    }
    for (var index = 0; index < snapshot.challenges.length; index++) {
      values['isaac.challenge.${index + 1}.completed'] =
          snapshot.challenges[index];
    }
    final descendantProperties = knowledge.descendantProperties(rootPageId);
    final validCollectibles = descendantProperties.values
        .where((properties) => properties['isaacType'] == 'collectible')
        .map((properties) => properties['isaacId'])
        .whereType<num>()
        .map((id) => id.toInt())
        .toSet();
    final ids = validCollectibles.isEmpty
        ? Iterable<int>.generate(732, (index) => index + 1)
        : validCollectibles;
    for (final id in ids) {
      if (id > 0 && id <= snapshot.collectibles.length) {
        values['isaac.collectible.$id.collected'] =
            snapshot.collectibles[id - 1];
      }
    }
    for (var character = 0;
        character < snapshot.completionMarks.length;
        character++) {
      for (var mark = 0;
          mark < snapshot.completionMarks[character].length;
          mark++) {
        values['isaac.character.$character.mark.$mark'] =
            snapshot.completionMarks[character][mark];
      }
    }
    for (final entry in snapshot.counters.entries) {
      values['isaac.counter.${entry.key}'] = entry.value;
    }
    for (final properties in descendantProperties.values
        .where((properties) => properties['isaacType'] == 'character')) {
      final slug = properties['isaacSlug']?.toString();
      if (slug == null) continue;
      final achievement = (properties['unlockAchievementId'] as num?)?.toInt();
      values['isaac.character.$slug.unlocked'] = achievement == null ||
          (achievement > 0 &&
              achievement <= snapshot.achievements.length &&
              snapshot.achievements[achievement - 1]);
    }
    return values;
  }

  List<File> discoverSaveFiles() {
    final roots = <Directory>[];
    final programFilesX86 = Platform.environment['ProgramFiles(x86)'];
    if (programFilesX86 != null) {
      final userdata = Directory(
          '$programFilesX86${Platform.pathSeparator}Steam${Platform.pathSeparator}userdata');
      if (userdata.existsSync()) {
        for (final account in userdata.listSync().whereType<Directory>()) {
          roots.add(Directory(
              '${account.path}${Platform.pathSeparator}250900${Platform.pathSeparator}remote'));
        }
      }
    }
    final profile = Platform.environment['USERPROFILE'];
    if (profile != null) {
      roots.add(Directory(
          '$profile${Platform.pathSeparator}Documents${Platform.pathSeparator}My Games${Platform.pathSeparator}Binding of Isaac Repentance+'));
    }
    final result = <File>[];
    final seen = <String>{};
    final pattern = RegExp(r'^(?:rep\+)?persistentgamedata[1-3]\.dat$',
        caseSensitive: false);
    for (final directory in roots) {
      if (!directory.existsSync()) continue;
      for (final file in directory.listSync().whereType<File>()) {
        final name = file.uri.pathSegments.last;
        if (pattern.hasMatch(name) && seen.add(file.path.toLowerCase())) {
          result.add(file);
        }
      }
    }
    result.sort((left, right) => left.path.compareTo(right.path));
    return result;
  }

  Future<void> selectSaveFile(String rootPageId, String path) async {
    final root = knowledge.pageById(rootPageId);
    final file = File(path);
    if (root == null || !file.existsSync()) {
      throw ArgumentError('La partida seleccionada no existe.');
    }
    final source = KnowledgeImportSource(
      rootPageId: rootPageId,
      kind: 'isaac-save',
      path: file.path,
      slot: _slotOf(file.path),
      enabled: true,
    );
    knowledge.saveImportSource(source);
    await _stopWatching();
    _disposed = false;
    await _startRoot(root);
  }

  int _slotOf(String path) {
    final match =
        RegExp(r'persistentgamedata([1-3])\.dat$', caseSensitive: false)
            .firstMatch(path);
    return int.tryParse(match?.group(1) ?? '') ?? 1;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _stopWatching();
  }

  Future<void> _stopWatching() async {
    for (final timer in _debounces.values) {
      timer.cancel();
    }
    _debounces.clear();
    for (final watcher in _watchers) {
      await watcher.cancel();
    }
    _watchers.clear();
  }
}
