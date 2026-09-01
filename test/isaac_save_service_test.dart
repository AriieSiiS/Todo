import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/services/isaac_save_service.dart';
import 'package:todo/services/knowledge_service.dart';

void main() {
  group('IsaacRepentancePlusSaveReader', () {
    final reader = IsaacRepentancePlusSaveReader();

    test('valida estructura y extrae progreso del fixture sintético', () {
      final fixture = _syntheticSave();
      final snapshot = reader.parse(fixture);

      expect(snapshot.achievements, hasLength(641));
      expect(snapshot.achievements.first, isTrue);
      expect(snapshot.achievements.last, isTrue);
      expect(snapshot.challenges[4], isTrue);
      expect(snapshot.collectibles[0], isTrue);
      expect(snapshot.collectibles[731], isTrue);
      expect(snapshot.completionMarks, hasLength(34));
      expect(snapshot.completionMarks.first.first, 2);
      expect(snapshot.counters['donation'], 321);
    });

    test('rechaza cabecera desconocida, truncado y checksum inválido', () {
      final valid = _syntheticSave();
      final badHeader = Uint8List.fromList(valid)..[0] = 0;
      final badChecksum = Uint8List.fromList(valid)..[100] ^= 1;

      expect(
        () => reader.parse(Uint8List(50)),
        throwsA(isA<IsaacSaveFormatException>()),
      );
      expect(
        () => reader.parse(badHeader),
        throwsA(isA<IsaacSaveFormatException>()),
      );
      expect(
        () => reader.parse(badChecksum),
        throwsA(isA<IsaacSaveFormatException>()),
      );
    });

    test('acepta las anchuras conocidas de los registros online', () {
      for (final width in <int>[583, 727, 865]) {
        final snapshot = reader.parse(
          _syntheticSave(onlineEntryBytes: width, onlineEntries: 2),
        );
        expect(snapshot.achievements.first, isTrue);
      }
    });

    test('acepta una anchura online variable coherente con la cabecera', () {
      final snapshot = reader.parse(
        _syntheticSave(onlineEntryBytes: 977, onlineEntries: 4),
      );
      expect(snapshot.achievements.first, isTrue);
    });

    test('lee el guardado local real cuando está disponible, sin escribirlo',
        () async {
      final knowledge = KnowledgeService.inMemory();
      addTearDown(knowledge.dispose);
      final sync = IsaacSaveSyncService(knowledge);
      final candidates = sync.discoverSaveFiles();
      if (candidates.isEmpty) return;

      final file = candidates.first;
      final before = await file.stat();
      final bytes = await file.readAsBytes();
      final snapshot = reader.parse(bytes);
      final after = await file.stat();

      expect(snapshot.achievements, hasLength(641));
      expect(after.size, before.size);
      expect(after.modified, before.modified);
    });
  });

  test('un guardado sin cambios no reescribe el progreso al arrancar',
      () async {
    final temporary = await Directory.systemTemp.createTemp('todo-isaac-sync-');
    final save = File(
      '${temporary.path}${Platform.pathSeparator}rep+persistentgamedata1.dat',
    );
    await save.writeAsBytes(_syntheticSave(), flush: true);
    final modified = (await save.stat()).modified;
    final knowledge = KnowledgeService.inMemory();
    final root = knowledge.createPage(title: 'The Binding of Isaac: Rebirth');
    knowledge.saveImportSource(
      KnowledgeImportSource(
        rootPageId: root.id,
        kind: 'isaac-save',
        path: save.path,
        slot: 1,
        enabled: true,
        lastImportedAt: DateTime.now(),
        lastModifiedAt: modified,
      ),
    );
    final sync = IsaacSaveSyncService(knowledge);
    addTearDown(() async {
      await sync.dispose();
      knowledge.dispose();
      await temporary.delete(recursive: true);
    });

    await sync.start();

    expect(knowledge.listProgress(root.id, source: 'isaac-save'), isEmpty);
    expect(
      knowledge.pendingBackupOperations().where(
            (operation) => operation['entityType'] == 'progressSource',
          ),
      isEmpty,
    );
  });
}

Uint8List _syntheticSave({int onlineEntryBytes = 583, int onlineEntries = 0}) {
  final entryBytes = <int>[1, 4, 4, 1, 1, 1, 1, 4, 4, 1, onlineEntryBytes];
  final counts = <int>[642, 2000, 0, 733, 0, 0, 46, 0, 0, 0, onlineEntries];
  final bytes = BytesBuilder(copy: false)
    ..add(ascii.encode('ISAACNGSAVE09R  '))
    ..add(Uint8List(4));
  for (var index = 0; index < counts.length; index++) {
    final header = ByteData(12)
      ..setUint32(0, index + 1, Endian.little)
      ..setUint32(
        4,
        index == counts.length - 1 && onlineEntries > 0
            ? (onlineEntryBytes - 9) * 2
            : counts[index],
        Endian.little,
      )
      ..setUint32(8, counts[index], Endian.little);
    bytes.add(header.buffer.asUint8List());
    final section = Uint8List(counts[index] * entryBytes[index]);
    if (index == 0) {
      section[1] = 1;
      section[641] = 1;
    } else if (index == 1) {
      ByteData.sublistView(section).setUint32(0, 321, Endian.little);
      section[0x6c] = 3;
    } else if (index == 3) {
      section[1] = 1;
      section[732] = 1;
    } else if (index == 6) {
      section[5] = 1;
    }
    bytes.add(section);
  }
  final body = bytes.takeBytes();
  final checksum = _checksum(body, 16, body.length);
  final result = BytesBuilder(copy: false)
    ..add(body)
    ..add((ByteData(4)..setUint32(0, checksum, Endian.little))
        .buffer
        .asUint8List());
  return result.takeBytes();
}

int _checksum(Uint8List bytes, int start, int end) {
  var checksum = (~0xFEDCBA76).toUnsigned(32);
  final table = List<int>.generate(256, (index) {
    var value = index;
    for (var bit = 0; bit < 8; bit++) {
      final signedShift = value.toSigned(32) >> 1;
      value = ((value & 1) == 1 ? signedShift ^ 0xEDB88320 : signedShift)
          .toUnsigned(32);
    }
    return value;
  }, growable: false);
  for (var index = start; index < end; index++) {
    checksum = (table[(checksum & 0xff) ^ bytes[index]] ^ (checksum >>> 8))
        .toUnsigned(32);
  }
  return (~checksum).toUnsigned(32);
}
