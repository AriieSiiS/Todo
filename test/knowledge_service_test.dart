import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/services/knowledge_service.dart';

void main() {
  late KnowledgeService service;

  setUp(() {
    service = KnowledgeService.inMemory();
  });

  tearDown(() {
    service.dispose();
  });

  test('la migración de Biblioteca es idempotente y conserva la nota',
      () async {
    final now = DateTime(2026, 7, 22);
    final item = LibraryItem(
      id: 'film-1',
      type: LibraryItemType.movieSeries,
      title: 'La película',
      status: LibraryItemStatus.completed,
      completedDate: now,
      note: 'Comentario breve anterior',
      createdAt: now,
      updatedAt: now,
    );

    await service.ensureLibraryRoots(<LibraryItem>[item]);
    await service.ensureLibraryRoots(<LibraryItem>[item]);

    final root = service.rootForOwner('libraryItem', item.id);
    expect(root, isNotNull);
    expect(service.listPages(), hasLength(1));
    expect(service.search('Comentario breve'), hasLength(1));
    expect(root!.document.toString(), contains('Nota anterior'));
  });

  test('páginas, enlaces, pestañas, revisiones y papelera funcionan juntas',
      () {
    final root = service.createPage(title: 'Juego');
    final child = service.createPage(title: 'Logros', parentId: root.id);
    final linkedDocument = <String, dynamic>{
      'document': <String, dynamic>{
        'type': 'page',
        'children': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'paragraph',
            'data': <String, dynamic>{
              'knowledgeBlockId': 'block-link',
              'knowledgeTargetPageId': child.id,
              'delta': <Map<String, dynamic>>[
                <String, dynamic>{'insert': 'Abrir guía de logros'},
              ],
            },
          },
        ],
      },
    };
    final saved = service.savePage(
      root.copyWith(document: linkedDocument),
      checkpoint: true,
      reason: 'test',
    );

    expect(saved.revision, 2);
    expect(service.backlinks(child.id).single.id, root.id);
    expect(service.outgoingPages(root.id).single.id, child.id);
    expect(service.revisions(root.id), hasLength(1));

    service.saveTabs(
      <KnowledgeTab>[
        KnowledgeTab(
          pageId: root.id,
          pinned: true,
          backHistory: <String>[child.id],
        ),
      ],
      root.id,
    );
    expect(service.loadTabs().single.pinned, isTrue);
    expect(service.loadActivePageId(), root.id);

    final pending = service.pendingBackupOperations();
    expect(pending, isNotEmpty);
    final operationId = pending.first['id'] as String;
    service.markBackupOperationFailed(operationId, 'sin conexión');
    expect(
      service
          .pendingBackupOperations()
          .where((operation) => operation['id'] == operationId),
      isEmpty,
    );
    service.markBackupOperationSucceeded(operationId);

    expect(
      () => service.movePage(root.id, child.id),
      throwsArgumentError,
    );
    service.trashTree(root.id);
    expect(service.listPages(), isEmpty);
    service.restoreTree(root.id);
    expect(service.listPages(), hasLength(2));
  });

  test('las concesiones impiden escrituras simultáneas y luego se liberan', () {
    final page = service.createPage(title: 'Página bloqueada');
    expect(
      service.acquireLease(page.id, holder: 'Flutter', processId: 10),
      isTrue,
    );
    expect(
      () => service.savePage(page.copyWith(title: 'MCP')),
      throwsA(isA<KnowledgeLockedException>()),
    );
    service.releaseLease(page.id, 'Flutter');
    expect(service.savePage(page.copyWith(title: 'Libre')).title, 'Libre');
  });

  test('colecciones incluyen todos los tipos de vista y rollups sencillos', () {
    final page = service.createPage(title: 'Actores');
    final collection = service.createCollection(
      pageId: page.id,
      name: 'Reparto',
      properties: const <KnowledgePropertyDefinition>[
        KnowledgePropertyDefinition(
          id: 'name',
          name: 'Nombre',
          type: KnowledgePropertyType.text,
        ),
        KnowledgePropertyDefinition(
          id: 'amount',
          name: 'Apariciones',
          type: KnowledgePropertyType.number,
        ),
        KnowledgePropertyDefinition(
          id: 'sum',
          name: 'Total de apariciones',
          type: KnowledgePropertyType.rollup,
          rollupPropertyId: 'amount',
          rollupOperation: 'sum',
        ),
      ],
      views: KnowledgeViewType.values
          .map(
            (type) => KnowledgeCollectionView(
              id: type.name,
              name: type.name,
              type: type,
            ),
          )
          .toList(),
    );

    expect(service.collectionById(collection.id)!.views, hasLength(6));
    service.createPage(
      title: 'Actriz uno',
      parentId: page.id,
      collectionId: collection.id,
      properties: const <String, dynamic>{'amount': 2},
    );
    service.createPage(
      title: 'Actor dos',
      parentId: page.id,
      collectionId: collection.id,
      properties: const <String, dynamic>{'amount': 1},
    );
    expect(service.collectionRollups(collection.id)['sum'], 3);
    expect(
      service.queryCollectionRecords(
        collection.id,
        filters: const <Map<String, dynamic>>[
          <String, dynamic>{
            'propertyId': 'amount',
            'operator': 'greaterThan',
            'value': 1,
          },
        ],
      ).single['title'],
      'Actriz uno',
    );
  });

  test('el reemplazo de una fuente es exacto y conserva pasos manuales', () {
    final root = service.createPage(title: 'The Binding of Isaac');
    service.setProgress(
      rootPageId: root.id,
      key: 'isaac.guide.step.1',
      value: true,
    );
    service.replaceProgressFromSource(
      rootPageId: root.id,
      source: 'isaac-save',
      values: const <String, dynamic>{
        'isaac.achievement.1.unlocked': true,
        'isaac.challenge.1.completed': true,
      },
    );

    service.replaceProgressFromSource(
      rootPageId: root.id,
      source: 'isaac-save',
      values: const <String, dynamic>{
        'isaac.achievement.1.unlocked': false,
      },
    );

    expect(
      service.progressByKey(root.id, 'isaac.guide.step.1')?.value,
      isTrue,
    );
    expect(
      service.progressByKey(root.id, 'isaac.achievement.1.unlocked')?.value,
      isFalse,
    );
    expect(
      service.progressByKey(root.id, 'isaac.challenge.1.completed'),
      isNull,
    );
    expect(
      service.pendingBackupOperations().where(
            (operation) =>
                operation['entityType'] == 'progressSource' &&
                operation['entityId'] == '${root.id}:isaac-save' &&
                operation['operation'] == 'replace' &&
                ((operation['payload'] as Map<String, dynamic>)['removedKeys']
                        as List<dynamic>)
                    .contains('isaac.challenge.1.completed'),
          ),
      hasLength(1),
    );
  });

  test('el árbol y el progreso grande se cargan una sola vez', () {
    final root = service.createPage(title: 'The Binding of Isaac: Rebirth');
    final objects = service.createPage(title: 'Objetos', parentId: root.id);
    final achievements = service.createPage(title: 'Logros', parentId: root.id);
    for (var index = 0; index < 720; index++) {
      service.createPage(title: 'Objeto $index', parentId: objects.id);
    }
    for (var index = 0; index < 641; index++) {
      service.createPage(title: 'Logro $index', parentId: achievements.id);
    }
    for (var index = 0; index < 637; index++) {
      service.createPage(title: 'Página $index', parentId: root.id);
    }
    service.replaceProgressFromSource(
      rootPageId: root.id,
      source: 'isaac-save',
      values: <String, dynamic>{
        for (var index = 0; index < 1859; index++)
          'isaac.progress.$index': index.isEven,
      },
    );

    service.resetPerformanceDiagnostics();
    final firstIndex = service.treeIndex(root.id);
    final secondIndex = service.treeIndex(root.id);
    expect(firstIndex.pagesById, hasLength(2001));
    expect(identical(firstIndex, secondIndex), isTrue);
    expect(service.treeIndexQueryCount, 1);

    for (var index = 0; index < 686; index++) {
      service.progressByKey(root.id, 'isaac.progress.$index');
    }
    expect(service.progressSnapshotQueryCount, 1);
    expect(
      service.pendingBackupOperations().where(
            (operation) => operation['entityType'] == 'progressSource',
          ),
      hasLength(1),
    );
    expect(
      service.database
          .select("SELECT value FROM knowledge_meta WHERE key='schema_version'")
          .single['value'],
      '3',
    );
  });

  test('la copia gestionada es atómica y conserva un único ZIP', () async {
    service.createPage(title: 'Página para la copia');
    final backups = Directory(
      '${service.rootDirectory.path}${Platform.pathSeparator}backups',
    );
    await backups.create(recursive: true);
    await File('${backups.path}${Platform.pathSeparator}antigua-1.zip')
        .writeAsBytes(<int>[1]);
    await File('${backups.path}${Platform.pathSeparator}antigua-2.zip')
        .writeAsBytes(<int>[2]);

    final backup = await service.createLocalBackup();
    final files = backups
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.zip'))
        .toList();
    expect(backup.path, endsWith('conocimiento-actual.zip'));
    expect(files, hasLength(1));
    expect(await backup.length(), greaterThan(100));
  });

  test('el índice detecta escrituras realizadas por MCP', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'todo-knowledge-external-',
    );
    final diskService = KnowledgeService(rootOverride: temporary);
    await diskService.initialize();
    final root = diskService.createPage(title: 'Raíz');
    diskService.resetPerformanceDiagnostics();
    expect(diskService.treeIndex(root.id).pagesById, hasLength(1));

    final external = sqlite3.open(
      '${temporary.path}${Platform.pathSeparator}knowledge.sqlite',
    );
    final stamp = DateTime.now().toIso8601String();
    external.execute('''
      INSERT INTO knowledge_pages(
        id, parent_id, title, document_json, properties_json,
        sort_order, is_trashed, revision, created_at, updated_at
      ) VALUES(?, ?, ?, ?, '{}', 0, 0, 1, ?, ?)
    ''', <Object?>[
      'external-child',
      root.id,
      'Página desde MCP',
      '{"document":{"type":"page","children":[]}}',
      stamp,
      stamp,
    ]);
    external.close();

    expect(diskService.treeIndex(root.id).pagesById, hasLength(2));
    expect(diskService.treeIndexQueryCount, 2);
    diskService.dispose();

    final reopened = KnowledgeService(rootOverride: temporary);
    await reopened.initialize();
    expect(reopened.treeIndex(root.id).pagesById, hasLength(2));
    expect(
      reopened.database
          .select("SELECT value FROM knowledge_meta WHERE key='schema_version'")
          .single['value'],
      '3',
    );
    reopened.dispose();
    await temporary.delete(recursive: true);
  });

  test('la ruta del guardado queda local y no entra en la cola de backup', () {
    final root = service.createPage(title: 'The Binding of Isaac');
    service.saveImportSource(
      KnowledgeImportSource(
        rootPageId: root.id,
        kind: 'isaac-save',
        path:
            r'C:\Steam\userdata\account\250900\remote\rep+persistentgamedata1.dat',
        slot: 1,
        enabled: true,
      ),
    );

    expect(service.importSource(root.id, 'isaac-save')?.slot, 1);
    expect(
      service.pendingBackupOperations().toString(),
      isNot(contains('persistentgamedata')),
    );
  });
}
