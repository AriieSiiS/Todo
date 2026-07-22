import 'package:flutter_test/flutter_test.dart';
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
}
