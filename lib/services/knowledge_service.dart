import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/models.dart';

class KnowledgeLockedException implements Exception {
  const KnowledgeLockedException(this.pageId, this.holder);

  final String pageId;
  final String holder;

  @override
  String toString() => 'La página está siendo editada por $holder.';
}

class KnowledgeSearchResult {
  const KnowledgeSearchResult({required this.page, required this.snippet});

  final KnowledgePage page;
  final String snippet;
}

class KnowledgeService {
  KnowledgeService({Directory? rootOverride, CommonDatabase? databaseOverride})
      : _rootOverride = rootOverride,
        _databaseOverride = databaseOverride;

  final Directory? _rootOverride;
  final CommonDatabase? _databaseOverride;
  final Random _random = Random.secure();
  CommonDatabase? _database;
  Directory? _root;

  factory KnowledgeService.inMemory() {
    final root = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}todo-knowledge-test-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final service = KnowledgeService(
      rootOverride: root,
      databaseOverride: sqlite3.openInMemory(),
    );
    service._root = root;
    service._database = service._databaseOverride;
    service.assetsDirectory.createSync(recursive: true);
    service.database.execute('PRAGMA foreign_keys = ON');
    service.database.execute('PRAGMA journal_mode = MEMORY');
    service._createSchema();
    return service;
  }

  CommonDatabase get database {
    final value = _database;
    if (value == null) {
      throw StateError('El repositorio documental no está inicializado.');
    }
    return value;
  }

  Directory get rootDirectory {
    final value = _root;
    if (value == null) {
      throw StateError('El repositorio documental no está inicializado.');
    }
    return value;
  }

  Directory get assetsDirectory => Directory(
        '${rootDirectory.path}${Platform.pathSeparator}assets',
      );

  Future<void> initialize() async {
    if (_database != null) return;
    _root = _rootOverride ?? _defaultRoot();
    await rootDirectory.create(recursive: true);
    await assetsDirectory.create(recursive: true);
    final backups = Directory(
      '${rootDirectory.path}${Platform.pathSeparator}backups',
    );
    await backups.create(recursive: true);
    _database = _databaseOverride ??
        sqlite3.open(
          '${rootDirectory.path}${Platform.pathSeparator}knowledge.sqlite',
        );
    database.execute('PRAGMA foreign_keys = ON');
    database.execute('PRAGMA journal_mode = WAL');
    database.execute('PRAGMA synchronous = NORMAL');
    database.execute('PRAGMA busy_timeout = 5000');
    _createSchema();
  }

  Directory _defaultRoot() {
    final profile = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final documents = Directory('$profile${Platform.pathSeparator}Documents');
    final todo = documents.existsSync()
        ? Directory('${documents.path}${Platform.pathSeparator}Todo')
        : Directory(profile);
    return Directory('${todo.path}${Platform.pathSeparator}knowledge');
  }

  void _createSchema() {
    database.execute('''
      CREATE TABLE IF NOT EXISTS knowledge_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS knowledge_pages (
        id TEXT PRIMARY KEY,
        parent_id TEXT REFERENCES knowledge_pages(id),
        title TEXT NOT NULL,
        icon TEXT,
        cover_asset_id TEXT,
        document_json TEXT NOT NULL,
        collection_id TEXT,
        properties_json TEXT NOT NULL DEFAULT '{}',
        canonical_source TEXT,
        canonical_id TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_trashed INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        revision INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    database.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS knowledge_canonical_identity
      ON knowledge_pages(canonical_source, canonical_id)
      WHERE canonical_source IS NOT NULL AND canonical_id IS NOT NULL
    ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS knowledge_owner_links (
        owner_type TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        page_id TEXT NOT NULL REFERENCES knowledge_pages(id) ON DELETE CASCADE,
        PRIMARY KEY(owner_type, owner_id),
        UNIQUE(page_id)
      )
    ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS knowledge_assets (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        relative_path TEXT NOT NULL,
        size INTEGER NOT NULL,
        source_url TEXT,
        source_page_url TEXT,
        author TEXT,
        alt_text TEXT,
        remote_status TEXT NOT NULL DEFAULT 'local',
        created_at TEXT NOT NULL
      )
    ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS knowledge_collections (
        id TEXT PRIMARY KEY,
        page_id TEXT NOT NULL REFERENCES knowledge_pages(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        schema_json TEXT NOT NULL,
        views_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS knowledge_links (
        source_page_id TEXT NOT NULL REFERENCES knowledge_pages(id) ON DELETE CASCADE,
        source_block_id TEXT NOT NULL,
        target_page_id TEXT NOT NULL,
        target_block_id TEXT,
        PRIMARY KEY(source_page_id, source_block_id, target_page_id, target_block_id)
      )
    ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS knowledge_revisions (
        id TEXT PRIMARY KEY,
        page_id TEXT NOT NULL REFERENCES knowledge_pages(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        document_json TEXT NOT NULL,
        properties_json TEXT NOT NULL,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    database.execute('''
      CREATE INDEX IF NOT EXISTS knowledge_revisions_page
      ON knowledge_revisions(page_id, created_at DESC)
    ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS knowledge_leases (
        page_id TEXT PRIMARY KEY REFERENCES knowledge_pages(id) ON DELETE CASCADE,
        holder TEXT NOT NULL,
        process_id INTEGER NOT NULL,
        expires_at TEXT NOT NULL
      )
    ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS knowledge_tabs (
        position INTEGER PRIMARY KEY,
        page_id TEXT NOT NULL REFERENCES knowledge_pages(id) ON DELETE CASCADE,
        pinned INTEGER NOT NULL DEFAULT 0,
        back_history_json TEXT NOT NULL DEFAULT '[]',
        forward_history_json TEXT NOT NULL DEFAULT '[]'
      )
    ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS knowledge_operations (
        operation_id TEXT PRIMARY KEY,
        result_json TEXT NOT NULL,
        applied_at TEXT NOT NULL
      )
    ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS knowledge_sync_queue (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        next_attempt_at TEXT,
        last_error TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    database.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS knowledge_fts USING fts5(
        page_id UNINDEXED,
        title,
        body,
        properties
      )
    ''');
    database.execute(
      "INSERT OR REPLACE INTO knowledge_meta(key, value) VALUES('schema_version', '1')",
    );
  }

  Future<void> ensureLibraryRoots(Iterable<LibraryItem> items) async {
    for (final item in items) {
      if (rootForOwner('libraryItem', item.id) != null) continue;
      KnowledgeAsset? cover;
      final coverPath = item.coverUrl;
      if (coverPath != null && _isLocalPath(coverPath)) {
        final file = File(coverPath);
        if (await file.exists()) {
          try {
            cover = await importAsset(file.path, altText: item.title);
          } catch (_) {
            // Una portada defectuosa no debe impedir la migración de las notas.
          }
        }
      }
      final page = createPage(
        title: item.title,
        document: initialDocument(item.note),
        coverAssetId: cover?.id,
      );
      database.execute(
        'INSERT INTO knowledge_owner_links(owner_type, owner_id, page_id) VALUES(?, ?, ?)',
        <Object?>['libraryItem', item.id, page.id],
      );
    }
  }

  Future<void> syncLibraryItem(LibraryItem item) async {
    var root = rootForOwner('libraryItem', item.id);
    if (root == null) {
      await ensureLibraryRoots(<LibraryItem>[item]);
      root = rootForOwner('libraryItem', item.id);
    }
    if (root == null || root.title == item.title) return;
    try {
      savePage(root.copyWith(title: item.title), reason: 'library-title');
    } on KnowledgeLockedException {
      // El título se reconciliará en la siguiente carga sin interrumpir la edición.
    }
  }

  Map<String, dynamic> initialDocument([String? legacyNote]) {
    final children = <Map<String, dynamic>>[];
    if (legacyNote != null && legacyNote.trim().isNotEmpty) {
      children.add(<String, dynamic>{
        'type': 'heading',
        'data': <String, dynamic>{
          'level': 2,
          'knowledgeBlockId': _id('block'),
          'delta': <Map<String, dynamic>>[
            <String, dynamic>{'insert': 'Nota anterior'},
          ],
        },
      });
      children.add(<String, dynamic>{
        'type': 'paragraph',
        'data': <String, dynamic>{
          'knowledgeBlockId': _id('block'),
          'delta': <Map<String, dynamic>>[
            <String, dynamic>{'insert': legacyNote.trim()},
          ],
        },
      });
    }
    children.add(<String, dynamic>{
      'type': 'paragraph',
      'data': <String, dynamic>{
        'knowledgeBlockId': _id('block'),
        'delta': <Map<String, dynamic>>[
          <String, dynamic>{'insert': ''},
        ],
      },
    });
    return <String, dynamic>{
      'document': <String, dynamic>{'type': 'page', 'children': children},
    };
  }

  KnowledgePage? rootForOwner(String ownerType, String ownerId) {
    final rows = database.select('''
      SELECT p.* FROM knowledge_pages p
      JOIN knowledge_owner_links o ON o.page_id = p.id
      WHERE o.owner_type = ? AND o.owner_id = ?
      LIMIT 1
    ''', <Object?>[ownerType, ownerId]);
    return rows.isEmpty ? null : _page(rows.first);
  }

  KnowledgePage? pageById(String pageId) {
    final rows = database.select(
      'SELECT * FROM knowledge_pages WHERE id = ? LIMIT 1',
      <Object?>[pageId],
    );
    return rows.isEmpty ? null : _page(rows.first);
  }

  List<KnowledgePage> listPages({bool includeTrashed = false}) {
    final rows = database.select(
      'SELECT * FROM knowledge_pages ${includeTrashed ? '' : 'WHERE is_trashed = 0'} ORDER BY parent_id, sort_order, title COLLATE NOCASE',
    );
    return rows.map(_page).toList(growable: false);
  }

  List<KnowledgePage> childrenOf(String? parentId,
      {bool includeTrashed = false}) {
    final condition = parentId == null ? 'parent_id IS NULL' : 'parent_id = ?';
    final rows = database.select(
      'SELECT * FROM knowledge_pages WHERE $condition ${includeTrashed ? '' : 'AND is_trashed = 0'} ORDER BY sort_order, title COLLATE NOCASE',
      parentId == null ? const <Object?>[] : <Object?>[parentId],
    );
    return rows.map(_page).toList(growable: false);
  }

  KnowledgePage createPage({
    required String title,
    String? parentId,
    Map<String, dynamic>? document,
    String? coverAssetId,
    String? collectionId,
    Map<String, dynamic> properties = const <String, dynamic>{},
    String? canonicalSource,
    String? canonicalId,
  }) {
    if (parentId != null && pageById(parentId) == null) {
      throw ArgumentError('La página superior no existe.');
    }
    if (canonicalSource != null && canonicalId != null) {
      final existing = findCanonical(canonicalSource, canonicalId);
      if (existing != null) return existing;
    }
    final now = DateTime.now();
    final page = KnowledgePage(
      id: _id('page'),
      parentId: parentId,
      title: title.trim().isEmpty ? 'Sin título' : title.trim(),
      coverAssetId: coverAssetId,
      document: document ?? initialDocument(),
      collectionId: collectionId,
      properties: properties,
      canonicalSource: canonicalSource,
      canonicalId: canonicalId,
      sortOrder: _nextSortOrder(parentId),
      createdAt: now,
      updatedAt: now,
    );
    database.execute('''
      INSERT INTO knowledge_pages(
        id, parent_id, title, icon, cover_asset_id, document_json,
        collection_id, properties_json, canonical_source, canonical_id,
        sort_order, is_trashed, revision, created_at, updated_at
      ) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 1, ?, ?)
    ''', <Object?>[
      page.id,
      page.parentId,
      page.title,
      page.icon,
      page.coverAssetId,
      jsonEncode(page.document),
      page.collectionId,
      jsonEncode(page.properties),
      page.canonicalSource,
      page.canonicalId,
      page.sortOrder,
      now.toIso8601String(),
      now.toIso8601String(),
    ]);
    _indexPage(page);
    _enqueueBackup('page', page.id, 'upsert', page.toJson());
    return page;
  }

  KnowledgePage? findCanonical(String source, String canonicalId) {
    final rows = database.select(
      'SELECT * FROM knowledge_pages WHERE canonical_source = ? AND canonical_id = ? LIMIT 1',
      <Object?>[source, canonicalId],
    );
    return rows.isEmpty ? null : _page(rows.first);
  }

  KnowledgePage savePage(
    KnowledgePage page, {
    String reason = 'autosave',
    bool checkpoint = false,
    String? leaseHolder,
  }) {
    final current = pageById(page.id);
    if (current == null) throw ArgumentError('La página ya no existe.');
    _assertEditable(page.id, leaseHolder);
    if (checkpoint) _createRevision(current, reason);
    final now = DateTime.now();
    final next = page.copyWith(
      revision: current.revision + 1,
      updatedAt: now,
    );
    database.execute('BEGIN IMMEDIATE');
    try {
      database.execute('''
        UPDATE knowledge_pages SET
          parent_id = ?, title = ?, icon = ?, cover_asset_id = ?,
          document_json = ?, collection_id = ?, properties_json = ?,
          canonical_source = ?, canonical_id = ?, sort_order = ?,
          is_trashed = ?, deleted_at = ?, revision = ?, updated_at = ?
        WHERE id = ?
      ''', <Object?>[
        next.parentId,
        next.title.trim().isEmpty ? 'Sin título' : next.title.trim(),
        next.icon,
        next.coverAssetId,
        jsonEncode(next.document),
        next.collectionId,
        jsonEncode(next.properties),
        next.canonicalSource,
        next.canonicalId,
        next.sortOrder,
        next.isTrashed ? 1 : 0,
        next.deletedAt?.toIso8601String(),
        next.revision,
        now.toIso8601String(),
        next.id,
      ]);
      _refreshLinks(next);
      _indexPage(next);
      _trimRevisions(next.id);
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
    final saved = pageById(page.id)!;
    _enqueueBackup('page', saved.id, 'upsert', saved.toJson());
    return saved;
  }

  void movePage(String pageId, String? newParentId, {String? leaseHolder}) {
    _assertEditable(pageId, leaseHolder);
    if (pageId == newParentId || _descendantIds(pageId).contains(newParentId)) {
      throw ArgumentError('Una página no puede moverse dentro de sí misma.');
    }
    final page = pageById(pageId);
    if (page == null) return;
    savePage(
      page.copyWith(
        parentId: newParentId,
        clearParentId: newParentId == null,
        sortOrder: _nextSortOrder(newParentId),
      ),
      reason: 'move',
      checkpoint: true,
      leaseHolder: leaseHolder,
    );
  }

  void trashTree(String pageId, {String? leaseHolder}) {
    final ids = <String>{pageId, ..._descendantIds(pageId)};
    for (final id in ids) {
      _assertEditable(id, leaseHolder);
    }
    final now = DateTime.now().toIso8601String();
    database.execute('BEGIN IMMEDIATE');
    try {
      for (final id in ids) {
        final page = pageById(id);
        if (page != null) _createRevision(page, 'before-trash');
        database.execute(
          'UPDATE knowledge_pages SET is_trashed = 1, deleted_at = ?, updated_at = ? WHERE id = ?',
          <Object?>[now, now, id],
        );
        database.execute(
            'DELETE FROM knowledge_fts WHERE page_id = ?', <Object?>[id]);
      }
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
    _enqueueBackup('pageTree', pageId, 'trash', <String, dynamic>{
      'pageId': pageId,
      'pageIds': ids.toList(),
      'deletedAt': now,
    });
  }

  void trashForOwner(String ownerType, String ownerId) {
    final root = rootForOwner(ownerType, ownerId);
    if (root != null) trashTree(root.id);
  }

  void restoreTree(String pageId) {
    final ids = <String>{pageId, ..._descendantIds(pageId)};
    final now = DateTime.now().toIso8601String();
    for (final id in ids) {
      database.execute(
        'UPDATE knowledge_pages SET is_trashed = 0, deleted_at = NULL, updated_at = ? WHERE id = ?',
        <Object?>[now, id],
      );
      final page = pageById(id);
      if (page != null) _indexPage(page);
    }
    _enqueueBackup('pageTree', pageId, 'restore', <String, dynamic>{
      'pageId': pageId,
      'pageIds': ids.toList(),
    });
  }

  List<KnowledgeSearchResult> search(String query, {int limit = 50}) {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return listPages()
          .take(limit)
          .map((page) => KnowledgeSearchResult(page: page, snippet: ''))
          .toList();
    }
    try {
      final rows = database.select('''
        SELECT page_id, snippet(knowledge_fts, 2, '[', ']', '…', 16) AS excerpt
        FROM knowledge_fts
        WHERE knowledge_fts MATCH ?
        LIMIT ?
      ''', <Object?>[_ftsQuery(normalized), limit]);
      return rows
          .map((row) {
            final page = pageById(row['page_id'] as String)!;
            return KnowledgeSearchResult(
              page: page,
              snippet: row['excerpt'] as String? ?? '',
            );
          })
          .where((result) => !result.page.isTrashed)
          .toList();
    } catch (_) {
      final lower = normalized.toLowerCase();
      return listPages()
          .where((page) =>
              page.title.toLowerCase().contains(lower) ||
              _plainText(page.document).toLowerCase().contains(lower))
          .take(limit)
          .map((page) => KnowledgeSearchResult(
                page: page,
                snippet: _plainText(page.document),
              ))
          .toList();
    }
  }

  List<KnowledgePage> backlinks(String pageId) {
    final rows = database.select('''
      SELECT DISTINCT p.* FROM knowledge_pages p
      JOIN knowledge_links l ON l.source_page_id = p.id
      WHERE l.target_page_id = ? AND p.is_trashed = 0
      ORDER BY p.title COLLATE NOCASE
    ''', <Object?>[pageId]);
    return rows.map(_page).toList(growable: false);
  }

  List<KnowledgePage> outgoingPages(String pageId) {
    final rows = database.select('''
      SELECT DISTINCT p.* FROM knowledge_pages p
      JOIN knowledge_links l ON l.target_page_id = p.id
      WHERE l.source_page_id = ? AND p.is_trashed = 0
      ORDER BY p.title COLLATE NOCASE
    ''', <Object?>[pageId]);
    return rows.map(_page).toList(growable: false);
  }

  List<KnowledgePage> unlinkedPages() {
    final rows = database.select('''
      SELECT p.* FROM knowledge_pages p
      LEFT JOIN knowledge_links incoming ON incoming.target_page_id = p.id
      LEFT JOIN knowledge_owner_links owner ON owner.page_id = p.id
      WHERE p.is_trashed = 0 AND incoming.target_page_id IS NULL
      GROUP BY p.id
      ORDER BY owner.page_id IS NULL DESC, p.title COLLATE NOCASE
    ''');
    return rows.map(_page).toList(growable: false);
  }

  bool acquireLease(
    String pageId, {
    required String holder,
    required int processId,
    Duration duration = const Duration(minutes: 2),
  }) {
    purgeExpiredLeases();
    final current = activeLease(pageId);
    if (current != null && current.$1 != holder) return false;
    final expires = DateTime.now().add(duration).toIso8601String();
    database.execute('''
      INSERT INTO knowledge_leases(page_id, holder, process_id, expires_at)
      VALUES(?, ?, ?, ?)
      ON CONFLICT(page_id) DO UPDATE SET
        holder = excluded.holder,
        process_id = excluded.process_id,
        expires_at = excluded.expires_at
    ''', <Object?>[pageId, holder, processId, expires]);
    return true;
  }

  (String, int, DateTime)? activeLease(String pageId) {
    purgeExpiredLeases();
    final rows = database.select(
      'SELECT holder, process_id, expires_at FROM knowledge_leases WHERE page_id = ?',
      <Object?>[pageId],
    );
    if (rows.isEmpty) return null;
    return (
      rows.first['holder'] as String,
      rows.first['process_id'] as int,
      DateTime.parse(rows.first['expires_at'] as String),
    );
  }

  void releaseLease(String pageId, String holder) {
    database.execute(
      'DELETE FROM knowledge_leases WHERE page_id = ? AND holder = ?',
      <Object?>[pageId, holder],
    );
  }

  void purgeExpiredLeases() {
    database.execute(
      'DELETE FROM knowledge_leases WHERE expires_at <= ?',
      <Object?>[DateTime.now().toIso8601String()],
    );
  }

  List<KnowledgeTab> loadTabs() {
    final rows =
        database.select('SELECT * FROM knowledge_tabs ORDER BY position');
    return rows.map((row) {
      return KnowledgeTab(
        pageId: row['page_id'] as String,
        pinned: (row['pinned'] as int) == 1,
        backHistory: _stringList(row['back_history_json'] as String),
        forwardHistory: _stringList(row['forward_history_json'] as String),
      );
    }).toList(growable: false);
  }

  void saveTabs(List<KnowledgeTab> tabs, String? activePageId) {
    database.execute('BEGIN IMMEDIATE');
    try {
      database.execute('DELETE FROM knowledge_tabs');
      for (var index = 0; index < tabs.length; index++) {
        final tab = tabs[index];
        database.execute('''
          INSERT INTO knowledge_tabs(position, page_id, pinned, back_history_json, forward_history_json)
          VALUES(?, ?, ?, ?, ?)
        ''', <Object?>[
          index,
          tab.pageId,
          tab.pinned ? 1 : 0,
          tab.encodeBackHistory(),
          tab.encodeForwardHistory(),
        ]);
      }
      database.execute(
        "INSERT OR REPLACE INTO knowledge_meta(key, value) VALUES('active_page_id', ?)",
        <Object?>[activePageId ?? ''],
      );
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  String? loadActivePageId() {
    final rows = database.select(
      "SELECT value FROM knowledge_meta WHERE key = 'active_page_id'",
    );
    if (rows.isEmpty) return null;
    final value = rows.first['value'] as String;
    return value.isEmpty ? null : value;
  }

  List<Map<String, dynamic>> revisions(String pageId) {
    return database
        .select(
          'SELECT * FROM knowledge_revisions WHERE page_id = ? ORDER BY created_at DESC',
          <Object?>[pageId],
        )
        .map((row) => <String, dynamic>{
              'id': row['id'],
              'pageId': row['page_id'],
              'title': row['title'],
              'document': jsonDecode(row['document_json'] as String),
              'properties': jsonDecode(row['properties_json'] as String),
              'reason': row['reason'],
              'createdAt': row['created_at'],
            })
        .toList();
  }

  KnowledgePage restoreRevision(String revisionId, {String? leaseHolder}) {
    final rows = database.select(
      'SELECT * FROM knowledge_revisions WHERE id = ? LIMIT 1',
      <Object?>[revisionId],
    );
    if (rows.isEmpty) throw ArgumentError('La versión no existe.');
    final page = pageById(rows.first['page_id'] as String)!;
    return savePage(
      page.copyWith(
        title: rows.first['title'] as String,
        document: (jsonDecode(rows.first['document_json'] as String) as Map)
            .cast<String, dynamic>(),
        properties: (jsonDecode(rows.first['properties_json'] as String) as Map)
            .cast<String, dynamic>(),
      ),
      reason: 'restore-revision',
      checkpoint: true,
      leaseHolder: leaseHolder,
    );
  }

  KnowledgeCollection createCollection({
    required String pageId,
    required String name,
    required List<KnowledgePropertyDefinition> properties,
    required List<KnowledgeCollectionView> views,
  }) {
    final now = DateTime.now();
    final collection = KnowledgeCollection(
      id: _id('collection'),
      pageId: pageId,
      name: name.trim().isEmpty ? 'Colección' : name.trim(),
      properties: properties,
      views: views,
      createdAt: now,
      updatedAt: now,
    );
    database.execute('''
      INSERT INTO knowledge_collections(id, page_id, name, schema_json, views_json, created_at, updated_at)
      VALUES(?, ?, ?, ?, ?, ?, ?)
    ''', <Object?>[
      collection.id,
      pageId,
      collection.name,
      jsonEncode(properties.map((item) => item.toJson()).toList()),
      jsonEncode(views.map((item) => item.toJson()).toList()),
      now.toIso8601String(),
      now.toIso8601String(),
    ]);
    _enqueueBackup(
      'collection',
      collection.id,
      'upsert',
      collection.toJson(),
    );
    return collection;
  }

  KnowledgeCollection? collectionById(String collectionId) {
    final rows = database.select(
      'SELECT * FROM knowledge_collections WHERE id = ? LIMIT 1',
      <Object?>[collectionId],
    );
    return rows.isEmpty ? null : _collection(rows.first);
  }

  List<KnowledgeCollection> collectionsForPage(String pageId) {
    return database
        .select(
          'SELECT * FROM knowledge_collections WHERE page_id = ? ORDER BY created_at',
          <Object?>[pageId],
        )
        .map(_collection)
        .toList(growable: false);
  }

  List<Map<String, dynamic>> collectionRecords(String collectionId) {
    return database
        .select(
          'SELECT * FROM knowledge_pages WHERE collection_id = ? AND is_trashed = 0 ORDER BY sort_order, title COLLATE NOCASE',
          <Object?>[collectionId],
        )
        .map((row) => _page(row).toJson())
        .toList();
  }

  List<Map<String, dynamic>> queryCollectionRecords(
    String collectionId, {
    List<Map<String, dynamic>> filters = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> sorting = const <Map<String, dynamic>>[],
  }) {
    final records = collectionRecords(collectionId).where((record) {
      final properties =
          (record['properties'] as Map? ?? const <dynamic, dynamic>{})
              .cast<String, dynamic>();
      return filters.every((filter) {
        final value = properties[filter['propertyId']];
        final expected = filter['value'];
        return switch (filter['operator']) {
          'notEquals' => value != expected,
          'contains' => value
              .toString()
              .toLowerCase()
              .contains(expected.toString().toLowerCase()),
          'greaterThan' => value is num && expected is num && value > expected,
          'lessThan' => value is num && expected is num && value < expected,
          'isEmpty' => value == null || value == '' || value == false,
          'isNotEmpty' => value != null && value != '' && value != false,
          _ => value == expected,
        };
      });
    }).toList();
    records.sort((left, right) {
      for (final sort in sorting) {
        final propertyId = sort['propertyId']?.toString();
        final leftValue = propertyId == 'title'
            ? left['title']
            : (left['properties'] as Map? ??
                const <dynamic, dynamic>{})[propertyId];
        final rightValue = propertyId == 'title'
            ? right['title']
            : (right['properties'] as Map? ??
                const <dynamic, dynamic>{})[propertyId];
        final compared = leftValue.toString().compareTo(rightValue.toString());
        if (compared != 0) {
          return sort['descending'] == true ? -compared : compared;
        }
      }
      return 0;
    });
    return records;
  }

  Map<String, dynamic> collectionRollups(String collectionId) {
    final collection = collectionById(collectionId);
    if (collection == null) return const <String, dynamic>{};
    final records = collectionRecords(collectionId);
    final result = <String, dynamic>{};
    for (final definition in collection.properties
        .where((property) => property.type == KnowledgePropertyType.rollup)) {
      final sourceId = definition.rollupPropertyId;
      final values = sourceId == null
          ? const <dynamic>[]
          : records
              .map((record) => (record['properties'] as Map? ??
                  const <dynamic, dynamic>{})[sourceId])
              .where((value) => value != null)
              .toList();
      result[definition.id] = switch (definition.rollupOperation) {
        'sum' =>
          values.whereType<num>().fold<num>(0, (sum, item) => sum + item),
        'min' => _numericExtreme(values, minimum: true),
        'max' => _numericExtreme(values, minimum: false),
        'earliestDate' => _dateExtreme(values, earliest: true),
        'latestDate' => _dateExtreme(values, earliest: false),
        _ => values.length,
      };
    }
    return result;
  }

  KnowledgeCollection _collection(Row row) {
    final definitions = (jsonDecode(row['schema_json'] as String) as List)
        .whereType<Map>()
        .map((raw) {
      final value = raw.cast<String, dynamic>();
      return KnowledgePropertyDefinition(
        id: value['id'] as String,
        name: value['name'] as String,
        type: KnowledgePropertyType.values.byName(value['type'] as String),
        options: (value['options'] as List? ?? const <dynamic>[])
            .whereType<String>()
            .toList(),
        relationCollectionId: value['relationCollectionId'] as String?,
        rollupPropertyId: value['rollupPropertyId'] as String?,
        rollupOperation: value['rollupOperation'] as String?,
      );
    }).toList();
    final views = (jsonDecode(row['views_json'] as String) as List)
        .whereType<Map>()
        .map((raw) {
      final value = raw.cast<String, dynamic>();
      return KnowledgeCollectionView(
        id: value['id'] as String,
        name: value['name'] as String,
        type: KnowledgeViewType.values.byName(value['type'] as String),
        configuration:
            (value['configuration'] as Map? ?? const <dynamic, dynamic>{})
                .cast<String, dynamic>(),
      );
    }).toList();
    return KnowledgeCollection(
      id: row['id'] as String,
      pageId: row['page_id'] as String,
      name: row['name'] as String,
      properties: definitions,
      views: views,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  Future<KnowledgeAsset> importAsset(
    String sourcePath, {
    String? sourceUrl,
    String? sourcePageUrl,
    String? author,
    String? altText,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('No se encuentra el recurso.');
    }
    final length = await source.length();
    final extension = _safeExtension(source.path);
    final kind = _assetKind(extension);
    final maxSize = switch (kind) {
      KnowledgeAssetKind.image => 25 * 1024 * 1024,
      KnowledgeAssetKind.pdf => 100 * 1024 * 1024,
      KnowledgeAssetKind.audio ||
      KnowledgeAssetKind.video =>
        1024 * 1024 * 1024,
      KnowledgeAssetKind.file => 100 * 1024 * 1024,
    };
    if (length > maxSize) {
      throw const FormatException('El recurso supera el tamaño permitido.');
    }
    final bytes = await source.readAsBytes();
    final id = sha256.convert(bytes).toString();
    final existing = assetById(id);
    if (existing != null) return existing;
    final prefix = id.substring(0, 2);
    final folder = Directory(
      '${assetsDirectory.path}${Platform.pathSeparator}$prefix',
    );
    await folder.create(recursive: true);
    final relativePath = '$prefix/$id$extension';
    final destination = File(
      '${assetsDirectory.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
    );
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(destination.path);
    final asset = KnowledgeAsset(
      id: id,
      kind: kind,
      mimeType: _mimeType(extension),
      relativePath: relativePath,
      size: length,
      sourceUrl: sourceUrl,
      sourcePageUrl: sourcePageUrl,
      author: author,
      altText: altText,
      createdAt: DateTime.now(),
    );
    database.execute('''
      INSERT INTO knowledge_assets(
        id, kind, mime_type, relative_path, size, source_url,
        source_page_url, author, alt_text, remote_status, created_at
      ) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', <Object?>[
      asset.id,
      asset.kind.name,
      asset.mimeType,
      asset.relativePath,
      asset.size,
      asset.sourceUrl,
      asset.sourcePageUrl,
      asset.author,
      asset.altText,
      asset.remoteStatus,
      asset.createdAt.toIso8601String(),
    ]);
    _enqueueBackup('asset', asset.id, 'upsert', asset.toJson());
    return asset;
  }

  List<Map<String, dynamic>> pendingBackupOperations({int limit = 100}) {
    final now = DateTime.now().toIso8601String();
    return database
        .select('''
          SELECT * FROM knowledge_sync_queue
          WHERE next_attempt_at IS NULL OR next_attempt_at <= ?
          ORDER BY created_at
          LIMIT ?
        ''', <Object?>[now, limit])
        .map((row) => <String, dynamic>{
              'id': row['id'],
              'entityType': row['entity_type'],
              'entityId': row['entity_id'],
              'operation': row['operation'],
              'payload': jsonDecode(row['payload_json'] as String),
              'attempts': row['attempts'],
              'nextAttemptAt': row['next_attempt_at'],
              'lastError': row['last_error'],
              'createdAt': row['created_at'],
            })
        .toList(growable: false);
  }

  void markBackupOperationSucceeded(String operationId) {
    database.execute(
      'DELETE FROM knowledge_sync_queue WHERE id = ?',
      <Object?>[operationId],
    );
  }

  void markBackupOperationFailed(String operationId, Object error) {
    final rows = database.select(
      'SELECT attempts FROM knowledge_sync_queue WHERE id = ?',
      <Object?>[operationId],
    );
    if (rows.isEmpty) return;
    final attempts = (rows.first['attempts'] as int) + 1;
    final exponent = min(attempts, 10);
    final delay = Duration(minutes: 1 << exponent);
    database.execute('''
      UPDATE knowledge_sync_queue
      SET attempts = ?, next_attempt_at = ?, last_error = ?
      WHERE id = ?
    ''', <Object?>[
      attempts,
      DateTime.now().add(delay).toIso8601String(),
      error.toString(),
      operationId,
    ]);
  }

  Future<KnowledgeAsset> importAssetFromUrl(
    Uri uri, {
    String? sourcePageUrl,
    String? author,
    String? altText,
  }) async {
    if (uri.scheme != 'https' || uri.host.isEmpty || _isPrivateHost(uri.host)) {
      throw const FormatException('La URL del recurso no es segura.');
    }
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
          'No se pudo descargar el recurso (${response.statusCode}).');
    }
    final staging = Directory(
      '${rootDirectory.path}${Platform.pathSeparator}staging',
    );
    await staging.create(recursive: true);
    final extension = _extensionForMime(
      response.headers['content-type']?.split(';').first,
      uri.path,
    );
    final temp = File(
      '${staging.path}${Platform.pathSeparator}${_id('download')}$extension',
    );
    await temp.writeAsBytes(response.bodyBytes, flush: true);
    try {
      return await importAsset(
        temp.path,
        sourceUrl: uri.toString(),
        sourcePageUrl: sourcePageUrl,
        author: author,
        altText: altText,
      );
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  KnowledgeAsset? assetById(String assetId) {
    final rows = database.select(
      'SELECT * FROM knowledge_assets WHERE id = ? LIMIT 1',
      <Object?>[assetId],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return KnowledgeAsset(
      id: row['id'] as String,
      kind: KnowledgeAssetKind.values.byName(row['kind'] as String),
      mimeType: row['mime_type'] as String,
      relativePath: row['relative_path'] as String,
      size: row['size'] as int,
      sourceUrl: row['source_url'] as String?,
      sourcePageUrl: row['source_page_url'] as String?,
      author: row['author'] as String?,
      altText: row['alt_text'] as String?,
      remoteStatus: row['remote_status'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  String absoluteAssetPath(KnowledgeAsset asset) {
    final normalized = asset.relativePath.replaceAll('\\', '/');
    if (normalized.startsWith('/') || normalized.contains('../')) return '';
    return '${assetsDirectory.path}${Platform.pathSeparator}${normalized.replaceAll('/', Platform.pathSeparator)}';
  }

  Future<File> exportArchive({String? targetPath}) async {
    final now = DateTime.now();
    final file = File(
      targetPath ??
          '${rootDirectory.path}${Platform.pathSeparator}backups${Platform.pathSeparator}conocimiento-${_dateStamp(now)}.zip',
    );
    final archive = Archive();
    final manifest = <String, dynamic>{
      'schemaVersion': 1,
      'exportedAt': now.toIso8601String(),
      'pages':
          listPages(includeTrashed: true).map((page) => page.toJson()).toList(),
      'collections': _rawCollections(),
      'assets': _rawAssets(),
    };
    final manifestBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );
    archive.addFile(
        ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));
    for (final page in listPages(includeTrashed: true)) {
      final markdown = _pageMarkdown(page);
      final bytes = utf8.encode(markdown);
      archive.addFile(ArchiveFile('pages/${page.id}.md', bytes.length, bytes));
    }
    for (final assetJson in _rawAssets()) {
      final asset = assetById(assetJson['id'] as String)!;
      final source = File(absoluteAssetPath(asset));
      if (!await source.exists()) continue;
      final bytes = await source.readAsBytes();
      archive.addFile(
          ArchiveFile('assets/${asset.relativePath}', bytes.length, bytes));
    }
    final encoded = ZipEncoder().encode(archive);
    if (!await file.parent.exists()) await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsBytes(encoded, flush: true);
    await temporary.rename(file.path);
    return file;
  }

  Future<File> createLocalBackup() async {
    database.execute('PRAGMA wal_checkpoint(FULL)');
    return exportArchive();
  }

  void _enqueueBackup(
    String entityType,
    String entityId,
    String operation,
    Map<String, dynamic> payload,
  ) {
    if (operation == 'upsert') {
      database.execute('''
        DELETE FROM knowledge_sync_queue
        WHERE entity_type = ? AND entity_id = ? AND operation = 'upsert'
      ''', <Object?>[entityType, entityId]);
    }
    final createdAt = DateTime.now();
    database.execute('''
      INSERT INTO knowledge_sync_queue(
        id, entity_type, entity_id, operation, payload_json, created_at
      ) VALUES(?, ?, ?, ?, ?, ?)
    ''', <Object?>[
      _id('sync'),
      entityType,
      entityId,
      operation,
      jsonEncode(payload),
      createdAt.toIso8601String(),
    ]);
  }

  void dispose() {
    _database?.close();
    _database = null;
  }

  KnowledgePage _page(Row row) {
    return KnowledgePage(
      id: row['id'] as String,
      parentId: row['parent_id'] as String?,
      title: row['title'] as String,
      icon: row['icon'] as String?,
      coverAssetId: row['cover_asset_id'] as String?,
      document: (jsonDecode(row['document_json'] as String) as Map)
          .cast<String, dynamic>(),
      collectionId: row['collection_id'] as String?,
      properties: (jsonDecode(row['properties_json'] as String) as Map)
          .cast<String, dynamic>(),
      canonicalSource: row['canonical_source'] as String?,
      canonicalId: row['canonical_id'] as String?,
      sortOrder: row['sort_order'] as int,
      isTrashed: (row['is_trashed'] as int) == 1,
      deletedAt: row['deleted_at'] == null
          ? null
          : DateTime.tryParse(row['deleted_at'] as String),
      revision: row['revision'] as int,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  int _nextSortOrder(String? parentId) {
    final rows = database.select(
      parentId == null
          ? 'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next_order FROM knowledge_pages WHERE parent_id IS NULL'
          : 'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next_order FROM knowledge_pages WHERE parent_id = ?',
      parentId == null ? const <Object?>[] : <Object?>[parentId],
    );
    return rows.first['next_order'] as int;
  }

  Set<String> _descendantIds(String pageId) {
    final rows = database.select('''
      WITH RECURSIVE descendants(id) AS (
        SELECT id FROM knowledge_pages WHERE parent_id = ?
        UNION ALL
        SELECT p.id FROM knowledge_pages p
        JOIN descendants d ON p.parent_id = d.id
      ) SELECT id FROM descendants
    ''', <Object?>[pageId]);
    return rows.map((row) => row['id'] as String).toSet();
  }

  void _assertEditable(String pageId, String? holder) {
    final lease = activeLease(pageId);
    if (lease != null && lease.$1 != holder) {
      throw KnowledgeLockedException(pageId, lease.$1);
    }
  }

  void _createRevision(KnowledgePage page, String reason) {
    database.execute('''
      INSERT INTO knowledge_revisions(
        id, page_id, title, document_json, properties_json, reason, created_at
      ) VALUES(?, ?, ?, ?, ?, ?, ?)
    ''', <Object?>[
      _id('revision'),
      page.id,
      page.title,
      jsonEncode(page.document),
      jsonEncode(page.properties),
      reason,
      DateTime.now().toIso8601String(),
    ]);
  }

  void _trimRevisions(String pageId) {
    database.execute('''
      DELETE FROM knowledge_revisions
      WHERE page_id = ? AND id NOT IN (
        SELECT id FROM knowledge_revisions
        WHERE page_id = ?
        ORDER BY created_at DESC LIMIT 50
      ) AND created_at < ?
    ''', <Object?>[
      pageId,
      pageId,
      DateTime.now().subtract(const Duration(days: 90)).toIso8601String(),
    ]);
  }

  void _indexPage(KnowledgePage page) {
    database.execute(
        'DELETE FROM knowledge_fts WHERE page_id = ?', <Object?>[page.id]);
    if (page.isTrashed) return;
    database.execute(
      'INSERT INTO knowledge_fts(page_id, title, body, properties) VALUES(?, ?, ?, ?)',
      <Object?>[
        page.id,
        page.title,
        _plainText(page.document),
        jsonEncode(page.properties),
      ],
    );
  }

  void _refreshLinks(KnowledgePage page) {
    database.execute(
      'DELETE FROM knowledge_links WHERE source_page_id = ?',
      <Object?>[page.id],
    );
    for (final link in _extractLinks(page.document)) {
      if (pageById(link.$2) == null) continue;
      database.execute('''
        INSERT OR IGNORE INTO knowledge_links(
          source_page_id, source_block_id, target_page_id, target_block_id
        ) VALUES(?, ?, ?, ?)
      ''', <Object?>[page.id, link.$1, link.$2, link.$3 ?? '']);
    }
  }

  Iterable<(String, String, String?)> _extractLinks(Object? value) sync* {
    if (value is Map) {
      final map = value.cast<Object?, Object?>();
      final data = map['data'];
      if (data is Map) {
        final blockId = data['knowledgeBlockId']?.toString() ?? _id('block');
        final target = data['knowledgeTargetPageId']?.toString();
        if (target != null && target.isNotEmpty) {
          yield (blockId, target, data['knowledgeTargetBlockId']?.toString());
        }
        final delta = data['delta'];
        if (delta is List) {
          for (final operation in delta.whereType<Map>()) {
            final attributes = operation['attributes'];
            final href =
                attributes is Map ? attributes['href']?.toString() : null;
            final parsed = href == null ? null : _parseKnowledgeHref(href);
            if (parsed != null) yield (blockId, parsed.$1, parsed.$2);
          }
        }
      }
      for (final child in map.values) {
        yield* _extractLinks(child);
      }
    } else if (value is List) {
      for (final child in value) {
        yield* _extractLinks(child);
      }
    }
  }

  (String, String?)? _parseKnowledgeHref(String value) {
    if (!value.startsWith('knowledge://page/')) return null;
    final fragmentIndex = value.indexOf('#');
    final pageId = value.substring(
      'knowledge://page/'.length,
      fragmentIndex == -1 ? value.length : fragmentIndex,
    );
    if (pageId.isEmpty) return null;
    return (
      pageId,
      fragmentIndex == -1 ? null : value.substring(fragmentIndex + 1)
    );
  }

  String _plainText(Object? value) {
    final output = StringBuffer();
    void visit(Object? node) {
      if (node is Map) {
        final data = node['data'];
        if (data is Map && data['delta'] is List) {
          for (final operation in (data['delta'] as List).whereType<Map>()) {
            final inserted = operation['insert'];
            if (inserted is String) output.write('$inserted ');
          }
        }
        for (final child in node.values) {
          visit(child);
        }
      } else if (node is List) {
        for (final child in node) {
          visit(child);
        }
      }
    }

    visit(value);
    return output.toString().trim();
  }

  List<Map<String, dynamic>> _rawCollections() => database
      .select('SELECT * FROM knowledge_collections ORDER BY created_at')
      .map((row) => <String, dynamic>{
            'id': row['id'],
            'pageId': row['page_id'],
            'name': row['name'],
            'properties': jsonDecode(row['schema_json'] as String),
            'views': jsonDecode(row['views_json'] as String),
            'createdAt': row['created_at'],
            'updatedAt': row['updated_at'],
          })
      .toList();

  List<Map<String, dynamic>> _rawAssets() => database
      .select('SELECT * FROM knowledge_assets ORDER BY created_at')
      .map((row) => assetById(row['id'] as String)!.toJson())
      .toList();

  String _pageMarkdown(KnowledgePage page) {
    final parent = page.parentId == null ? '' : 'parentId: ${page.parentId}\n';
    return '---\nid: ${page.id}\n${parent}title: ${jsonEncode(page.title)}\nrevision: ${page.revision}\n---\n\n# ${page.title}\n\n${_plainText(page.document)}\n';
  }

  String _ftsQuery(String query) => query
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty)
      .map((term) => '"${term.replaceAll('"', '""')}"*')
      .join(' AND ');

  List<String> _stringList(String encoded) {
    try {
      return (jsonDecode(encoded) as List).whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  num? _numericExtreme(List<dynamic> values, {required bool minimum}) {
    final numbers = values.whereType<num>().toList();
    if (numbers.isEmpty) return null;
    return numbers.reduce(
      (current, next) => minimum ? min(current, next) : max(current, next),
    );
  }

  String? _dateExtreme(List<dynamic> values, {required bool earliest}) {
    final dates = values
        .whereType<String>()
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .toList();
    if (dates.isEmpty) return null;
    final selected = dates.reduce(
      (current, next) => earliest
          ? (current.isBefore(next) ? current : next)
          : (current.isAfter(next) ? current : next),
    );
    return selected.toIso8601String();
  }

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_random.nextInt(1 << 32).toRadixString(36)}';

  bool _isLocalPath(String value) =>
      RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value) ||
      value.startsWith('\\\\') ||
      value.startsWith('/');

  String _safeExtension(String path) {
    final name = path.replaceAll('\\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot < 0) return '.bin';
    final value = name.substring(dot).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(value) ? value : '.bin';
  }

  KnowledgeAssetKind _assetKind(String extension) {
    if (<String>{'.png', '.jpg', '.jpeg', '.webp', '.gif', '.svg'}
        .contains(extension)) {
      return KnowledgeAssetKind.image;
    }
    if (<String>{'.mp3', '.wav', '.ogg', '.flac', '.m4a'}.contains(extension)) {
      return KnowledgeAssetKind.audio;
    }
    if (<String>{'.mp4', '.mkv', '.webm', '.mov', '.avi'}.contains(extension)) {
      return KnowledgeAssetKind.video;
    }
    if (extension == '.pdf') {
      return KnowledgeAssetKind.pdf;
    }
    return KnowledgeAssetKind.file;
  }

  String _mimeType(String extension) => switch (extension) {
        '.png' => 'image/png',
        '.jpg' || '.jpeg' => 'image/jpeg',
        '.webp' => 'image/webp',
        '.gif' => 'image/gif',
        '.svg' => 'image/svg+xml',
        '.mp3' => 'audio/mpeg',
        '.wav' => 'audio/wav',
        '.ogg' => 'audio/ogg',
        '.flac' => 'audio/flac',
        '.m4a' => 'audio/mp4',
        '.mp4' => 'video/mp4',
        '.webm' => 'video/webm',
        '.mov' => 'video/quicktime',
        '.pdf' => 'application/pdf',
        _ => 'application/octet-stream',
      };

  String _extensionForMime(String? mime, String path) => switch (mime) {
        'image/png' => '.png',
        'image/jpeg' => '.jpg',
        'image/webp' => '.webp',
        'image/gif' => '.gif',
        'audio/mpeg' => '.mp3',
        'audio/wav' => '.wav',
        'video/mp4' => '.mp4',
        'application/pdf' => '.pdf',
        _ => _safeExtension(path),
      };

  bool _isPrivateHost(String host) {
    final lower = host.toLowerCase();
    if (lower == 'localhost' || lower.endsWith('.local')) return true;
    final parts = lower.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((part) => part == null)) return false;
    final a = parts[0]!;
    final b = parts[1]!;
    return a == 10 ||
        a == 127 ||
        a == 0 ||
        (a == 169 && b == 254) ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168);
  }

  String _dateStamp(DateTime value) =>
      '${value.year}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}-${value.hour.toString().padLeft(2, '0')}${value.minute.toString().padLeft(2, '0')}${value.second.toString().padLeft(2, '0')}';
}
