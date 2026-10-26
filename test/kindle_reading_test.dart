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
    workspace.updateBookReadingPage('circe', 50);
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
      'guarda el 14 %, citas y notas sin cambiar el estado; reintento tras reiniciar',
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
