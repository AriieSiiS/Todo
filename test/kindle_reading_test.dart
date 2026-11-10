import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/data/local_store_file_backed.dart';
import 'package:todo/data/repositories/local_todo_state_repository.dart';
import 'package:todo/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late _ReadingStore store;
  late TodoWorkspace workspace;
  LibraryItem book(String id, {String title = 'Circe'}) => LibraryItem(
      id: id,
      type: LibraryItemType.book,
      title: title,
      author: 'Madeline Miller',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026));
  Map<String, dynamic> event(String request,
          {double progress = .14, int time = 100, int sequence = 1}) =>
      {
        'request_id': request,
        'document_id': 'a' * 32,
        'source_id': 'kindle-prueba',
        'sequence': sequence,
        'title': 'Circe',
        'author': 'Madeline Miller',
        'observed_at': time,
        'progress': progress,
        'page': '42',
        'total_pages': 1300,
        'position': '/body/p[42]',
        'quotes': [
          {
            'anchor': '/body/p[5]:0-20',
            'text': 'Una cita de prueba.',
            'note': 'Mi nota',
            'page': '5',
            'chapter': 'Capítulo uno',
            'created_at': '2026-10-24 12:00:00'
          }
        ],
      };
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('todo-lectura-');
    store = _ReadingStore(directory);
    workspace = TodoWorkspace.createForTest(
        snapshot: AppStateSnapshot.fromJson({
          'schemaVersion': 12,
          'libraryItems': [book('circe').toJson()],
        }),
        stateRepository: LocalTodoStateRepository(store));
  });
  tearDown(() async {
    workspace.dispose();
    await directory.delete(recursive: true);
  });
  for (final progress in [0.0, .0099, .01, .10, 1.0]) {
    test('un pendiente se inicia desde el 1 % sincronizado: $progress',
        () async {
      workspace.updateLibraryItemStatus('circe', LibraryItemStatus.pending);
      final args = event('lectura-inicio-0001', progress: progress);
      await workspace.executeAgentCommand('sync_kindle_book', args);
      final saved = (await store.load())!.libraryItems.single;
      expect(
          saved.status,
          progress >= .01
              ? LibraryItemStatus.inProgress
              : LibraryItemStatus.pending);
      expect(saved.completedDate, isNull);
      expect(saved.reading!.progress, progress);
      expect(saved.reading!.quotes, hasLength(1));
      final before = saved.toJson();
      await workspace.executeAgentCommand('sync_kindle_book', args);
      expect((await store.load())!.libraryItems.single.toJson(), before);
    });
  }
  test('el estado usa el progreso vigente y no retrocede al volver al inicio',
      () async {
    workspace.updateLibraryItemStatus('circe', LibraryItemStatus.pending);
    await workspace.executeAgentCommand('sync_kindle_book',
        event('lectura-vigente-0001', progress: 0, time: 200));
    await workspace.executeAgentCommand('sync_kindle_book',
        event('lectura-antigua-0002', progress: .10, time: 100, sequence: 2));
    expect(workspace.libraryItems.single.status, LibraryItemStatus.pending);
    await workspace.executeAgentCommand('sync_kindle_book',
        event('lectura-vigente-0003', progress: .10, time: 300, sequence: 3));
    expect(workspace.libraryItems.single.status, LibraryItemStatus.inProgress);
    await workspace.executeAgentCommand('sync_kindle_book',
        event('lectura-vigente-0004', progress: 0, time: 400, sequence: 4));
    expect(workspace.libraryItems.single.status, LibraryItemStatus.inProgress);
  });

  test(
      'un completado sigue al 100 % tras sincronizar y conserva el avance al reabrirlo',
      () async {
    await workspace.executeAgentCommand(
        'sync_kindle_book', event('lectura-completado-0001', progress: .98));
    final saved = (await store.load())!.libraryItems.single;
    expect(saved.status, LibraryItemStatus.completed);
    expect(saved.readingPercent, 100);
    final originalReading = saved.reading!.toJson();
    await workspace.executeAgentCommand(
        'sync_kindle_book',
        event('lectura-completado-0002',
            progress: .97, time: 200, sequence: 2));
    final updated = (await store.load())!.libraryItems.single;
    expect(updated.readingPercent, 100);
    expect(updated.reading!.quotes, [
      for (final quote in originalReading['quotes'] as List)
        {...quote as Map<String, dynamic>, 'observed_at': 200}
    ]);
    workspace.updateLibraryItemStatus('circe', LibraryItemStatus.inProgress);
    expect(workspace.libraryItems.single.readingPercent, 97);
    expect(workspace.libraryItems.single.reading!.position,
        originalReading['position']);
  });

  test('se guardan las unidades de progreso, citas y estadísticas', () async {
    final args = event('lectura-unidades-01')..['page_unit'] = 'screen';
    (args['quotes'] as List).single['page_unit'] = 'page';
    args['statistics'] = {
      'origin': 'historial-prueba',
      'book_id': 1,
      'periods': [
        {'start': 3600, 'seconds': 120, 'pages': 2}
      ]
    };
    final result =
        await workspace.executeAgentCommand('sync_kindle_book', args);
    expect(result['savedLocally'], true);
    final saved = (await store.load())!.libraryItems.single.reading!.toJson();
    expect(saved['pageUnit'], 'screen');
    expect(saved['quotes'].single['page_unit'], 'page');
    expect((saved['statistics'] as Map).values.single['pageUnit'], 'screen');
  });
  test('una cita borrada no vuelve al sincronizar, editar o unir fichas',
      () async {
    await workspace.executeAgentCommand(
        'sync_kindle_book', event('cita-borrada-0001'));
    final stale = workspace.libraryItems.single;
    final id = stale.reading!.quotes.single['id'] as String;
    expect(workspace.deleteBookQuote('circe', id), true);
    expect(workspace.deleteBookQuote('circe', id), false);
    await workspace.flushPendingChanges();
    final restored = (await store.load())!.libraryItems.single.reading!;
    expect(restored.quotes, isEmpty);
    expect(restored.deletedQuoteIds, contains(id));
    expect(restored.merge(stale.reading).quotes, isEmpty);
    workspace.updateLibraryItem(stale.copyWith(pages: '500'));
    expect(workspace.updateBookReadingPage('circe', 20), true);
    expect(workspace.libraryItems.single.reading!.quotes, isEmpty);
    expect(
        workspace.libraryItems.single.reading!.deletedQuoteIds, contains(id));
    final later = event('cita-borrada-0002', time: 200, sequence: 2);
    await workspace.executeAgentCommand('sync_kindle_book', later);
    final anotherDevice = event('cita-borrada-0003', time: 300)
      ..['source_id'] = 'kindle-segundo';
    await workspace.executeAgentCommand('sync_kindle_book', anotherDevice);
    expect(workspace.libraryItems.single.reading!.quotes, isEmpty);
    final different = event('cita-borrada-0004', time: 400, sequence: 3);
    (different['quotes'] as List).single['anchor'] = '/body/p[8]';
    await workspace.executeAgentCommand('sync_kindle_book', different);
    expect(workspace.libraryItems.single.reading!.quotes, hasLength(1));
    expect(
        workspace.libraryItems.single.reading!.deletedQuoteIds, contains(id));
    await workspace.flushPendingChanges();
    expect((await store.load())!.libraryItems.single.reading!.deletedQuoteIds,
        contains(id));
  });
  test('la paginación estimada se guarda explícita sin convertir estadísticas',
      () async {
    final args = event('lectura-estimada-01')
      ..['page_unit'] = 'estimated_page'
      ..['total_pages'] = 1088
      ..['statistics'] = {
        'origin': 'historial-prueba',
        'book_id': 1,
        'page_unit': 'screen',
        'periods': [
          {'start': 3600, 'seconds': 120, 'pages': 2}
        ]
      };
    (args['quotes'] as List).single['page_unit'] = 'estimated_page';
    await workspace.executeAgentCommand('sync_kindle_book', args);
    final saved = (await store.load())!.libraryItems.single.reading!;
    expect(saved.pageUnit, 'estimated_page');
    expect(saved.pageLabel, 'Página');
    expect(saved.totalPages, 1088);
    expect(saved.progress, .14);
    expect(saved.quotes.single['page_unit'], 'estimated_page');
    expect(saved.statistics.values.single.pageUnit, 'screen');
  });
  test('el mapa editorial no convierte el historial de pantallas en páginas',
      () async {
    final args = event('lectura-mapa-editorial-01')
      ..['page_unit'] = 'page'
      ..['page'] = '83'
      ..['total_pages'] = 669
      ..['statistics'] = {
        'origin': 'historial-prueba',
        'book_id': 1,
        'page_unit': 'screen',
        'periods': [
          {'start': 3600, 'seconds': 120, 'pages': 2}
        ]
      };
    await workspace.executeAgentCommand('sync_kindle_book', args);
    final reading = (await store.load())!.libraryItems.single.reading!;
    expect(reading.page, '83');
    expect(reading.totalPages, 669);
    expect(reading.progress, .14);
    expect(reading.pageUnit, 'page');
    expect(reading.statistics.values.single.pageUnit, 'screen');
  });
  test(
      'las estadísticas acumuladas se sustituyen sin duplicar reintentos y sobreviven a ediciones',
      () async {
    final first = event('lectura-estadisticas-01')
      ..['statistics'] = {
        'origin': 'historial-prueba',
        'book_id': 1,
        'periods': [
          {'start': 3600, 'seconds': 120, 'pages': 2}
        ]
      };
    await workspace.executeAgentCommand('sync_kindle_book', first);
    await workspace.executeAgentCommand('sync_kindle_book', first);
    Map stats() =>
        workspace.libraryItems.single.toJson()['reading']['statistics'] as Map;
    expect(stats().values.single['periods'].single['seconds'], 120);
    final next = event('lectura-estadisticas-02', time: 200, sequence: 2)
      ..['statistics'] = {
        'origin': 'historial-prueba',
        'book_id': 1,
        'periods': [
          {'start': 3600, 'seconds': 180, 'pages': 3}
        ]
      };
    await workspace.executeAgentCommand('sync_kindle_book', next);
    expect(stats().length, 1);
    expect(stats().values.single['periods'].single['seconds'], 180);
    workspace.updateLibraryItem(
        workspace.libraryItems.single.copyWith(pages: '200'));
    expect(workspace.updateBookReadingPage('circe', 50), true);
    expect(stats().values.single['periods'].single['seconds'], 180);
    final saved = (await store.load())!;
    expect(saved.libraryItems.single.reading!.toJson()['statistics'], stats());
  });
  test(
      'un traslado conserva el origen y no duplica el historial; rechaza contadores inválidos',
      () async {
    final args = event('lectura-estadisticas-03')
      ..['statistics'] = {
        'origin': 'historial-prueba',
        'book_id': 1,
        'periods': [
          {'start': 3600, 'seconds': 120, 'pages': 2}
        ]
      };
    await workspace.executeAgentCommand('sync_kindle_book', args);
    await workspace.executeAgentCommand('sync_kindle_book', {
      ...args,
      'request_id': 'lectura-estadisticas-04',
      'source_id': 'kindle-nuevo',
      'observed_at': 200
    });
    final stats =
        workspace.libraryItems.single.toJson()['reading']['statistics'] as Map;
    expect(stats.length, 1);
    final invalid = event('lectura-estadisticas-05', time: 300, sequence: 3)
      ..['statistics'] = {
        'origin': 'historial-prueba',
        'book_id': 1,
        'periods': [
          {'start': 3600, 'seconds': -1, 'pages': 2}
        ]
      };
    await expectLater(
        workspace.executeAgentCommand('sync_kindle_book', invalid),
        throwsFormatException);
  });
  test(
      'conserva completado al guardar el 14 %, citas y notas; reintento tras reiniciar',
      () async {
    final args = event('lectura-prueba-0001')..['chapter'] = 'Capítulo siete';
    final result =
        await workspace.executeAgentCommand('sync_kindle_book', args);
    expect(result['savedLocally'], true);
    final saved = (await store.load())!;
    final data = saved.libraryItems.single.toJson()['reading'] as Map;
    expect(data['progress'], .14);
    expect(data['totalPages'], 1300);
    expect(data['chapter'], 'Capítulo siete');
    expect(data['quotes'], hasLength(1));
    expect(data['quotes'][0]['note'], 'Mi nota');
    expect(saved.libraryItems.single.status, LibraryItemStatus.completed);
    workspace.dispose();
    workspace = TodoWorkspace.createForTest(
        snapshot: saved, stateRepository: LocalTodoStateRepository(store));
    expect(
        await workspace.executeAgentCommand('sync_kindle_book', args), result);
    expect(workspace.libraryItems.single.toJson()['reading']['quotes'],
        hasLength(1));
  });
  test(
      'ignora progreso antiguo y permite volver atrás en una lectura posterior',
      () async {
    await workspace.executeAgentCommand('sync_kindle_book',
        event('lectura-prueba-0002', progress: .5, time: 200, sequence: 2));
    await workspace.executeAgentCommand(
        'sync_kindle_book', event('lectura-prueba-0001'));
    expect(workspace.libraryItems.single.toJson()['reading']['progress'], .5);
    await workspace.executeAgentCommand('sync_kindle_book',
        event('lectura-prueba-0003', progress: .3, time: 300, sequence: 3));
    expect(workspace.libraryItems.single.toJson()['reading']['progress'], .3);
    expect(workspace.libraryItems.single.toJson()['reading']['quotes'],
        hasLength(1));
  });

  test(
      'el capítulo sigue la posición más reciente y admite clientes anteriores',
      () async {
    await workspace.executeAgentCommand(
        'sync_kindle_book',
        event('lectura-capitulo-0002', time: 200, sequence: 2)
          ..['chapter'] = 'Capítulo siete');
    await workspace.executeAgentCommand('sync_kindle_book',
        event('lectura-capitulo-0001')..['chapter'] = 'Capítulo uno');
    expect(workspace.libraryItems.single.reading!.toJson()['chapter'],
        'Capítulo siete');
    final current = workspace.libraryItems.single;
    workspace.updateLibraryItem(current.copyWith(note: 'Mi reseña'));
    expect(workspace.libraryItems.single.reading!.toJson()['chapter'],
        'Capítulo siete');
    await workspace.executeAgentCommand('sync_kindle_book',
        event('lectura-capitulo-0003', time: 300, sequence: 3));
    expect(workspace.libraryItems.single.reading!.toJson()['chapter'], '');
  });
  test('no adivina una coincidencia ambigua y permite elegir ficha', () async {
    workspace.createLibraryItem(
        type: LibraryItemType.book,
        title: 'Circe',
        author: 'Otro autor',
        status: LibraryItemStatus.pending);
    final args = event('lectura-prueba-0001')..['author'] = '';
    final result =
        await workspace.executeAgentCommand('sync_kindle_book', args);
    expect(result['status'], 'needs_link');
    expect(workspace.libraryItems.every((b) => b.toJson()['reading'] == null),
        true);
    final linked = await workspace.executeAgentCommand('sync_kindle_book', {
      ...args,
      'request_id': 'lectura-prueba-0002',
      'library_item_id': 'circe'
    });
    expect(linked['library_item_id'], 'circe');
  });
  test('rechaza datos inválidos antes de tocar el libro', () async {
    await expectLater(
        workspace.executeAgentCommand(
            'sync_kindle_book', event('lectura-prueba-0001', progress: 1.1)),
        throwsFormatException);
    expect(workspace.libraryItems.single.toJson()['reading'], isNull);
  });
  test('un editor abierto antes de sincronizar conserva la lectura nueva',
      () async {
    final opened = workspace.libraryItems.single;
    await workspace.executeAgentCommand(
        'sync_kindle_book', event('lectura-prueba-0001'));
    workspace.updateLibraryItem(opened.copyWith(note: 'Mi reseña'));
    expect(workspace.libraryItems.single.reading!.percent, 14);
    expect(workspace.libraryItems.single.reading!.quotes, hasLength(1));
    expect(workspace.libraryItems.single.note, 'Mi reseña');
  });
  test('no confirma un fallo de disco y reutiliza el recibo al reintentar',
      () async {
    final args = event('lectura-prueba-0001');
    store.failWrites = true;
    await expectLater(workspace.executeAgentCommand('sync_kindle_book', args),
        throwsA(isA<FileSystemException>()));
    store.failWrites = false;
    final result =
        await workspace.executeAgentCommand('sync_kindle_book', args);
    expect(result['savedLocally'], true);
    final persisted = (await store.load())!;
    expect(persisted.libraryItems.single.reading!.quotes, hasLength(1));
    expect(persisted.agentOperationReceipts, contains(args['request_id']));
  });
  test(
      'un segundo dispositivo no duplica una cita ni sustituye una nota más reciente',
      () async {
    await workspace.executeAgentCommand(
        'sync_kindle_book', event('lectura-prueba-0002', time: 200));
    final older = event('lectura-prueba-0001')
      ..['source_id'] = 'segundo-kindle';
    (older['quotes'] as List).single['note'] = 'Nota anterior';
    await workspace.executeAgentCommand('sync_kindle_book', older);
    expect(workspace.libraryItems.single.reading!.quotes, hasLength(1));
    expect(workspace.libraryItems.single.reading!.quotes.single['note'],
        'Mi nota');
  });
  test(
      'la página manual usa el total editorial y una cita editada resiste la sincronización',
      () async {
    await workspace.executeAgentCommand(
        'sync_kindle_book', event('lectura-prueba-0001'));
    final current = workspace.libraryItems.single;
    workspace.updateLibraryItem(current.copyWith(pages: '1088'));
    expect(workspace.updateBookReadingPage('circe', 27), true);
    expect(workspace.updateBookReadingPage('circe', 1089), false);
    final quoteId =
        workspace.libraryItems.single.reading!.quotes.single['id'] as String;
    expect(
        workspace.updateBookQuote('circe', quoteId,
            text: 'Texto corregido',
            page: '27',
            chapter: 'Capítulo nuevo',
            note: 'Nota personal corregida'),
        true);
    expect(workspace.libraryItems.single.reading!.percent, 2);
    await workspace.flushPendingChanges();
    final persisted = (await store.load())!.libraryItems.single.reading!;
    expect(persisted.page, '27');
    expect(persisted.totalPages, 1088);
    expect(persisted.quotes.single['text'], 'Texto corregido');

    final newer = event('lectura-prueba-0002',
        time: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1, sequence: 2);
    await workspace.executeAgentCommand('sync_kindle_book', newer);
    final quote = workspace.libraryItems.single.reading!.quotes.single;
    expect(quote['text'], 'Texto corregido');
    expect(quote['note'], 'Nota personal corregida');
  });
}

class _ReadingStore extends FileBackedLocalStore {
  _ReadingStore(Directory directory) : super(baseDirectory: directory);
  bool failWrites = false;
  @override
  Future<void> save(AppStateSnapshot snapshot) async {
    if (failWrites) throw const FileSystemException('Fallo de disco simulado');
    await super.save(snapshot);
  }
}
