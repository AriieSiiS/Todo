import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/state/todo_workspace.dart';
import '../../domain/models.dart';
import '../../services/knowledge_service.dart';
import '../../services/clipboard_image_service.dart';
import '../shared/texto_busqueda.dart';

part 'knowledge_arbol.dart';
part 'knowledge_bloque_multimedia.dart';
part 'knowledge_bloques.dart';

class KnowledgeWorkspacePage extends StatefulWidget {
  const KnowledgeWorkspacePage({
    required this.controller,
    required this.libraryItem,
    this.embedded = false,
    this.onClose,
    super.key,
  });

  final TodoWorkspace controller;
  final LibraryItem libraryItem;
  final bool embedded;
  final VoidCallback? onClose;

  @override
  State<KnowledgeWorkspacePage> createState() => _KnowledgeWorkspacePageState();
}

class _KnowledgeWorkspacePageState extends State<KnowledgeWorkspacePage> {
  KnowledgeService get service => widget.controller.knowledge;

  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _holder = 'Flutter-$pid-${DateTime.now().microsecondsSinceEpoch}';
  final List<KnowledgeTab> _tabs = <KnowledgeTab>[];
  List<KnowledgeSearchResult> _searchResults = const <KnowledgeSearchResult>[];
  KnowledgePage? _activePage;
  EditorState? _editorState;
  EditorScrollController? _editorScrollController;
  StreamSubscription<EditorTransactionValue>? _transactionSubscription;
  Timer? _saveTimer;
  Timer? _leaseTimer;
  Timer? _checkpointTimer;
  StreamSubscription<String>? _progressSubscription;
  bool _editable = true;
  bool _disposing = false;
  int _navigationGeneration = 0;
  final ValueNotifier<String?> _statusMessage = ValueNotifier<String?>(null);
  final ValueNotifier<int> _progressVersion = ValueNotifier<int>(0);
  final ValueNotifier<int> _metadataVersion = ValueNotifier<int>(0);
  String? _rootPageId;
  String? _lastSavedDocumentJson;
  String? _lastSavedTitle;
  late final Future<bool> Function(String?) _previousEditorLaunchUrl;
  late final Future<bool> Function(String?) _knowledgeEditorLaunchUrl;

  @override
  void initState() {
    super.initState();
    _previousEditorLaunchUrl = editorLaunchUrl;
    _knowledgeEditorLaunchUrl = _handleEditorLink;
    editorLaunchUrl = _knowledgeEditorLaunchUrl;
    _progressSubscription = service.progressChanges.listen((rootPageId) {
      if (rootPageId == _rootPageId) _progressVersion.value++;
    });
    _openInitialWorkspace();
  }

  Future<bool> _handleEditorLink(String? href) async {
    if (href == null || href.isEmpty) return false;
    const prefix = 'knowledge://page/';
    if (href.startsWith(prefix)) {
      final remainder = href.substring(prefix.length);
      final parts = remainder.split('#');
      final pageId = Uri.decodeComponent(parts.first);
      final blockId = parts.length > 1 ? Uri.decodeComponent(parts[1]) : null;
      if (service.pageById(pageId) == null) return false;
      _openPageFromBlock(pageId, blockId);
      return true;
    }
    final uri = Uri.tryParse(href);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openInitialWorkspace() {
    final root = service.rootForOwner('libraryItem', widget.libraryItem.id);
    if (root == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await service.syncLibraryItem(widget.libraryItem);
        if (!mounted) return;
        final created =
            service.rootForOwner('libraryItem', widget.libraryItem.id);
        if (created != null) {
          _rootPageId = created.id;
          _openPage(created.id);
        }
      });
      return;
    }
    _rootPageId = root.id;
    _tabs.addAll(service
        .loadTabs()
        .where((tab) => service.pageById(tab.pageId) != null));
    if (_tabs.every((tab) => tab.pageId != root.id)) {
      _tabs.add(KnowledgeTab(pageId: root.id, pinned: true));
    }
    final remembered = service.loadActivePageId();
    final initial =
        _tabs.any((tab) => tab.pageId == remembered) ? remembered! : root.id;
    _openPage(initial, persistTabs: false);
  }

  @override
  void dispose() {
    _disposing = true;
    _navigationGeneration++;
    _saveTimer?.cancel();
    _leaseTimer?.cancel();
    _checkpointTimer?.cancel();
    _transactionSubscription?.cancel();
    _progressSubscription?.cancel();
    _editorScrollController?.dispose();
    _saveActive(checkpoint: true, reason: 'close-workspace');
    final page = _activePage;
    if (page != null) service.releaseLease(page.id, _holder);
    _editorState?.dispose();
    _searchController.dispose();
    _titleController.dispose();
    _statusMessage.dispose();
    _progressVersion.dispose();
    _metadataVersion.dispose();
    if (editorLaunchUrl == _knowledgeEditorLaunchUrl) {
      editorLaunchUrl = _previousEditorLaunchUrl;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _activePage;
    final content = ColoredBox(
      color: const Color(0xFFF5F1EA),
      child: Column(
        children: [
          _buildTopBar(context),
          ValueListenableBuilder<int>(
            valueListenable: _metadataVersion,
            builder: (context, _, __) => _buildTabs(),
          ),
          Expanded(
            child: page == null
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 270, child: _buildTreePanel()),
                      const VerticalDivider(width: 1),
                      Expanded(child: _buildEditorPanel(page)),
                      const VerticalDivider(width: 1),
                      SizedBox(width: 285, child: _buildInspector(page)),
                    ],
                  ),
          ),
        ],
      ),
    );
    if (widget.embedded) {
      return content;
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1EA),
      body: SafeArea(child: content),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFCF8),
        border: Border(bottom: BorderSide(color: Color(0xFFE3D8CB))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
            tooltip: 'Volver a Biblioteca',
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: _canNavigateBack ? _navigateBack : null,
            tooltip: 'Atrás en esta pestaña',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
          ),
          IconButton(
            onPressed: _canNavigateForward ? _navigateForward : null,
            tooltip: 'Adelante en esta pestaña',
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 17),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.hub_outlined, color: Color(0xFF607A4D)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _breadcrumbText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16),
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: _statusMessage,
                  builder: (context, status, _) => Text(
                    status ??
                        (_editable
                            ? 'Guardado local automático'
                            : 'Solo lectura: página bloqueada'),
                    style: TextStyle(
                      color: _editable
                          ? const Color(0xFF6F7868)
                          : const Color(0xFF9B4D43),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showSearch,
            tooltip: 'Buscar en todas las páginas',
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            onPressed: _showHistory,
            tooltip: 'Historial de versiones',
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            onPressed: _export,
            tooltip: 'Exportar conocimiento',
            icon: const Icon(Icons.archive_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 45,
      color: const Color(0xFFF8F4EE),
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        itemCount: _tabs.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final tab = _tabs.removeAt(oldIndex);
            _tabs.insert(newIndex, tab);
            _persistTabs();
          });
        },
        itemBuilder: (context, index) {
          final tab = _tabs[index];
          final page = service.pageById(tab.pageId);
          final active = tab.pageId == _activePage?.id;
          return ReorderableDragStartListener(
            key: ValueKey(tab.pageId),
            index: index,
            child: InkWell(
              onTap: () => _openPage(tab.pageId),
              child: Container(
                constraints: const BoxConstraints(minWidth: 145, maxWidth: 230),
                padding: const EdgeInsets.fromLTRB(13, 0, 5, 0),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFFFFCF8) : Colors.transparent,
                  border: Border(
                    right: const BorderSide(color: Color(0xFFE3D8CB)),
                    bottom: BorderSide(
                      color: active
                          ? const Color(0xFF607A4D)
                          : const Color(0xFFE3D8CB),
                      width: active ? 2 : 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (tab.pinned) ...[
                      const Icon(Icons.push_pin_outlined, size: 14),
                      const SizedBox(width: 5),
                    ],
                    Expanded(
                      child: Text(
                        page?.title ?? 'Página eliminada',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Opciones de pestaña',
                      padding: EdgeInsets.zero,
                      onSelected: (action) {
                        if (action == 'pin') _togglePin(index);
                        if (action == 'close') _closeTab(index);
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                            value: 'pin',
                            child: Text(tab.pinned ? 'Desfijar' : 'Fijar')),
                        const PopupMenuItem(
                            value: 'close', child: Text('Cerrar')),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.all(7),
                        child: Icon(Icons.more_horiz_rounded, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTreePanel() {
    final root = service.rootForOwner('libraryItem', widget.libraryItem.id);
    if (root == null) return const SizedBox.shrink();
    return _KnowledgeTreePanel(
      service: service,
      rootPageId: root.id,
      activePageId: _activePage?.id,
      editable: _editable,
      onOpen: (pageId) => _openPage(pageId),
      onOpenNewTab: (pageId) => _openPage(pageId, newTab: true),
      onAddChild: _createChildUnder,
      onAddPage: _createChildPage,
      onShowTrash: _showTrash,
      metadataVersion: _metadataVersion,
    );
  }

  Widget _buildEditorPanel(KnowledgePage page) {
    final editorState = _editorState;
    final editorScrollController = _editorScrollController;
    if (editorState == null || editorScrollController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final editor = AppFlowyEditor(
      editorState: editorState,
      editable: _editable,
      blockComponentBuilders: <String, BlockComponentBuilder>{
        ...standardBlockComponentBuilderMap,
        'knowledgeMedia': _KnowledgeMediaBlockBuilder(
          service,
          editable: _editable,
          onUpdate: _updateBlockAttributes,
        ),
        'image': _KnowledgeMediaBlockBuilder(
          service,
          editable: _editable,
          onUpdate: _updateBlockAttributes,
        ),
        'knowledgePage':
            _KnowledgePageBlockBuilder(service, _openPageFromBlock),
        'knowledgeProgress': _KnowledgeProgressBlockBuilder(
          service,
          (pageId) => _openPageFromBlock(pageId, null),
          progressVersion: _progressVersion,
        ),
        'knowledgeCharacter': _KnowledgeCharacterBlockBuilder(service),
        'knowledgeCollection': _KnowledgeCollectionBlockBuilder(
          service,
          (pageId) => _openPageFromBlock(pageId, null),
        ),
      },
      commandShortcutEvents: standardCommandShortcutEvents,
      characterShortcutEvents: standardCharacterShortcutEvents,
      editorStyle: EditorStyle.desktop(
        // AppFlowy aplica este padding a cada bloque, no al documento entero.
        padding: const EdgeInsets.fromLTRB(72, 3, 72, 3),
        maxWidth: 900,
        cursorColor: const Color(0xFF607A4D),
        selectionColor: const Color(0xFFD8E4CF),
        textStyleConfiguration: const TextStyleConfiguration(
          text: TextStyle(fontSize: 16, height: 1.55, color: Color(0xFF2D2A25)),
          bold: TextStyle(fontWeight: FontWeight.w800),
          code: TextStyle(fontFamily: 'monospace', color: Color(0xFF7E443D)),
        ),
      ),
      contextMenuBuilder: (context, position, state, onPressed) => ContextMenu(
        position: position,
        editorState: state,
        items: standardContextMenuItems,
        onPressed: onPressed,
      ),
    );
    return Container(
      color: const Color(0xFFFFFCF8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 28, 64, 8),
            child: TextField(
              controller: _titleController,
              enabled: _editable,
              onChanged: (_) => _scheduleSave(),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'Sin título',
              ),
            ),
          ),
          if (_isIsaacRoot(page)) _buildIsaacSyncPanel(page),
          if (_editable) _buildBlockToolbar(),
          const Divider(height: 1),
          Expanded(
            child: FloatingToolbar(
              editorState: editorState,
              editorScrollController: editorScrollController,
              textDirection: TextDirection.ltr,
              items: [
                paragraphItem,
                ...headingItems,
                ...markdownFormatItems,
                quoteItem,
                bulletedListItem,
                numberedListItem,
                linkItem,
                buildTextColorItem(),
                buildHighlightColorItem(),
              ],
              child: editor,
            ),
          ),
        ],
      ),
    );
  }

  bool _isIsaacRoot(KnowledgePage page) =>
      page.parentId == null &&
      page.title.toLowerCase().contains('binding of isaac');

  Widget _buildIsaacSyncPanel(KnowledgePage root) {
    return ValueListenableBuilder<int>(
      valueListenable: _progressVersion,
      builder: (context, _, __) {
        final source = service.importSource(root.id, 'isaac-save');
        final entries = service.listProgress(root.id, source: 'isaac-save');
        int completed(String prefix) => entries
            .where((entry) => entry.key.startsWith(prefix) && entry.isCompleted)
            .length;
        final saves = widget.controller.isaacSaveSync.discoverSaveFiles();
        return Container(
          margin: const EdgeInsets.fromLTRB(68, 0, 60, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: source?.lastError == null
                ? const Color(0xFFF1F6EC)
                : const Color(0xFFFFF0EC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: source?.lastError == null
                  ? const Color(0xFFC7D8BA)
                  : const Color(0xFFE8B8AA),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sync_rounded, color: Color(0xFF607A4D)),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text('Sincronización de Repentance+',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  if (saves.isNotEmpty)
                    DropdownButton<String>(
                      value: source != null &&
                              saves.any((file) => file.path == source.path)
                          ? source.path
                          : null,
                      hint: const Text('Elegir slot'),
                      items: [
                        for (final file in saves)
                          DropdownMenuItem<String>(
                            value: file.path,
                            child: Text(file.uri.pathSegments.last),
                          ),
                      ],
                      onChanged: (path) async {
                        if (path == null) return;
                        await widget.controller.isaacSaveSync
                            .selectSaveFile(root.id, path);
                        if (mounted) setState(() {});
                      },
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(source == null
                  ? 'No se ha detectado una partida compatible.'
                  : 'Slot ${source.slot} · última lectura: '
                      '${source.lastImportedAt?.toLocal().toString() ?? 'pendiente'}'),
              if (source?.lastError != null) ...[
                const SizedBox(height: 5),
                Text(source!.lastError!,
                    style: const TextStyle(color: Color(0xFF9B312D))),
              ],
              if (entries.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  '${completed('isaac.achievement.')} / 641 logros · '
                  '${completed('isaac.challenge.')} / 45 challenges · '
                  '${completed('isaac.collectible.')} objetos recogidos',
                ),
              ],
              const SizedBox(height: 4),
              const Text(
                'Solo lectura: Todo nunca modifica ni sube el archivo .dat.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF6E685F)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBlockToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(68, 0, 60, 10),
      child: Wrap(
        spacing: 4,
        children: [
          _toolbarButton(Icons.image_outlined, 'Imagen',
              () => _addAsset(KnowledgeAssetKind.image)),
          _toolbarButton(
            Icons.content_paste_rounded,
            'Pegar imagen',
            _pasteImageAsset,
          ),
          _toolbarButton(Icons.attach_file_rounded, 'Archivo',
              () => _addAsset(KnowledgeAssetKind.file)),
          _toolbarButton(Icons.audiotrack_rounded, 'Audio',
              () => _addAsset(KnowledgeAssetKind.audio)),
          _toolbarButton(Icons.movie_outlined, 'Vídeo',
              () => _addAsset(KnowledgeAssetKind.video)),
          _toolbarButton(Icons.picture_as_pdf_outlined, 'PDF',
              () => _addAsset(KnowledgeAssetKind.pdf)),
          _toolbarButton(
              Icons.note_add_outlined, 'Subpágina', _createChildPage),
          _toolbarButton(
              Icons.view_module_outlined, 'Colección', _createCollection),
          _toolbarButton(
              Icons.link_rounded, 'Enlace interno', _insertInternalLink),
        ],
      ),
    );
  }

  Future<void> _updateBlockAttributes(
    Node node,
    Map<String, dynamic> attributes,
  ) async {
    final editor = _editorState;
    if (!_editable || editor == null) return;
    final transaction = editor.transaction..updateNode(node, attributes);
    await editor.apply(transaction);
  }

  Widget _toolbarButton(IconData icon, String label, VoidCallback action) {
    return TextButton.icon(
      onPressed: action,
      icon: Icon(icon, size: 17),
      label: Text(label),
    );
  }

  Widget _buildInspector(KnowledgePage page) {
    final backlinks = service.backlinks(page.id);
    final outgoing = service.outgoingPages(page.id);
    final headings = _headings(page.document);
    final sources = (page.properties['sources'] as List? ?? const <dynamic>[])
        .whereType<String>()
        .toList();
    return Container(
      color: const Color(0xFFF8F4EE),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          _inspectorTitle('Esquema', Icons.format_list_bulleted_rounded),
          if (headings.isEmpty)
            const _EmptyInspectorText(
                'Añade encabezados para crear un esquema.')
          else
            for (final heading in headings)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.only(left: (heading.$1 - 1) * 12.0),
                title: Text(heading.$2,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: heading.$3 == null
                    ? null
                    : () => _scrollToBlock(heading.$3!),
              ),
          const Divider(height: 26),
          _inspectorTitle('Enlaces entrantes', Icons.call_received_rounded),
          if (backlinks.isEmpty)
            const _EmptyInspectorText('Ninguna página enlaza todavía a esta.')
          else
            for (final linked in backlinks) _inspectorPage(linked),
          const SizedBox(height: 14),
          _inspectorTitle('Enlaces salientes', Icons.call_made_rounded),
          if (outgoing.isEmpty)
            const _EmptyInspectorText('No hay enlaces hacia otras páginas.')
          else
            for (final linked in outgoing) _inspectorPage(linked),
          const Divider(height: 26),
          Row(
            children: [
              Expanded(
                  child: _inspectorTitle('Fuentes', Icons.source_outlined)),
              IconButton(
                onPressed: _editable ? _editSources : null,
                tooltip: 'Editar fuentes',
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
            ],
          ),
          if (sources.isEmpty)
            const _EmptyInspectorText('Sin bibliografía registrada.')
          else
            for (final source in sources)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link_rounded, size: 17),
                title:
                    Text(source, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () {
                  final uri = Uri.tryParse(source);
                  if (uri != null) launchUrl(uri);
                },
              ),
          const Divider(height: 26),
          _inspectorTitle('Propiedades', Icons.tune_rounded),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Revisión'),
            trailing: Text('${page.revision}'),
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Actualizada'),
            trailing: Text(_shortDate(page.updatedAt)),
          ),
        ],
      ),
    );
  }

  Widget _inspectorTitle(String title, IconData icon) => Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF607A4D)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      );

  Widget _inspectorPage(KnowledgePage page) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.description_outlined, size: 17),
        title: Text(page.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () => _openPage(page.id, newTab: true),
      );

  Future<void> _openPage(String pageId,
      {bool newTab = false, bool persistTabs = true}) async {
    final next = service.pageById(pageId);
    if (next == null || next.isTrashed) return;
    final previous = _activePage;
    if (previous?.id == next.id && _editorState != null) return;
    final navigationGeneration = ++_navigationGeneration;
    await _saveActive(checkpoint: true, reason: 'switch-page');
    if (!mounted ||
        _disposing ||
        navigationGeneration != _navigationGeneration) {
      return;
    }
    if (previous != null) service.releaseLease(previous.id, _holder);
    _leaseTimer?.cancel();
    _checkpointTimer?.cancel();
    await _transactionSubscription?.cancel();
    if (!mounted ||
        _disposing ||
        navigationGeneration != _navigationGeneration) {
      return;
    }
    final previousEditor = _editorState;
    _editorState = null;
    previousEditor?.dispose();
    _editable = service.acquireLease(
      next.id,
      holder: _holder,
      processId: pid,
    );
    final document = Document.fromJson(next.document);
    _ensureBlockIds(document.root);
    final editorState = EditorState(document: document);
    editorState.logConfiguration.level = AppFlowyEditorLogLevel.off;
    _transactionSubscription = editorState.transactionStream.listen((event) {
      if (event.$1 == TransactionTime.after) _scheduleSave();
    });
    if (_tabs.every((tab) => tab.pageId != next.id)) {
      if (newTab || _tabs.isEmpty) {
        _tabs.add(KnowledgeTab(pageId: next.id));
      } else {
        final currentIndex =
            _tabs.indexWhere((tab) => tab.pageId == previous?.id);
        if (currentIndex >= 0 && !_tabs[currentIndex].pinned) {
          _tabs[currentIndex] = KnowledgeTab(
            pageId: next.id,
            backHistory: <String>[
              ..._tabs[currentIndex].backHistory,
              if (previous != null) previous.id
            ],
          );
        } else {
          _tabs.add(KnowledgeTab(pageId: next.id));
        }
      }
    }
    _activePage = next;
    _editorScrollController?.dispose();
    _editorState = editorState;
    _editorScrollController = EditorScrollController(editorState: editorState);
    _titleController.text = next.title;
    _lastSavedDocumentJson = jsonEncode(next.document);
    _lastSavedTitle = next.title;
    _statusMessage.value = _editable
        ? 'Página abierta para edición'
        : 'Otra operación está editando esta página';
    if (_editable) {
      _leaseTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        service.acquireLease(next.id, holder: _holder, processId: pid);
      });
      _checkpointTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        _saveActive(checkpoint: true, reason: 'periodic-five-minutes');
      });
    }
    if (persistTabs) _persistTabs();
    if (mounted) setState(() {});
  }

  int get _activeTabIndex =>
      _tabs.indexWhere((tab) => tab.pageId == _activePage?.id);

  bool get _canNavigateBack {
    final index = _activeTabIndex;
    return index >= 0 && _tabs[index].backHistory.isNotEmpty;
  }

  bool get _canNavigateForward {
    final index = _activeTabIndex;
    return index >= 0 && _tabs[index].forwardHistory.isNotEmpty;
  }

  String get _breadcrumbText {
    final titles = <String>[];
    var page = _activePage;
    final seen = <String>{};
    while (page != null && seen.add(page.id)) {
      titles.insert(0, page.title);
      page = page.parentId == null ? null : service.pageById(page.parentId!);
    }
    return titles.isEmpty ? widget.libraryItem.title : titles.join('  ›  ');
  }

  Future<void> _navigateBack() async {
    final index = _activeTabIndex;
    if (index < 0) return;
    final tab = _tabs[index];
    if (tab.backHistory.isEmpty) return;
    final target = tab.backHistory.last;
    final current = tab.pageId;
    _tabs[index] = KnowledgeTab(
      pageId: target,
      pinned: tab.pinned,
      backHistory: tab.backHistory.sublist(0, tab.backHistory.length - 1),
      forwardHistory: <String>[current, ...tab.forwardHistory],
    );
    await _openPage(target);
  }

  Future<void> _navigateForward() async {
    final index = _activeTabIndex;
    if (index < 0) return;
    final tab = _tabs[index];
    if (tab.forwardHistory.isEmpty) return;
    final target = tab.forwardHistory.first;
    final current = tab.pageId;
    _tabs[index] = KnowledgeTab(
      pageId: target,
      pinned: tab.pinned,
      backHistory: <String>[...tab.backHistory, current],
      forwardHistory: tab.forwardHistory.sublist(1),
    );
    await _openPage(target);
  }

  Future<void> _openPageFromBlock(
    String pageId,
    String? blockId,
  ) async {
    await _openPage(
      pageId,
      newTab: HardwareKeyboard.instance.isControlPressed,
    );
    if (blockId != null && blockId.isNotEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBlock(blockId);
      });
    }
  }

  void _scheduleSave() {
    if (!_editable) return;
    _saveTimer?.cancel();
    _statusMessage.value = 'Guardando cambios…';
    _saveTimer = Timer(const Duration(milliseconds: 800), () {
      _saveActive();
    });
  }

  Future<void> _saveActive(
      {bool checkpoint = false, String reason = 'autosave'}) async {
    final page = _activePage;
    final editor = _editorState;
    if (!_editable || page == null || editor == null) return;
    _ensureBlockIds(editor.document.root);
    final serialized = jsonEncode(editor.document.toJson());
    final title = _titleController.text.trim().isEmpty
        ? 'Sin título'
        : _titleController.text.trim();
    if (!checkpoint &&
        serialized == _lastSavedDocumentJson &&
        title == _lastSavedTitle) {
      _statusMessage.value = 'Guardado local · ${_shortTime(DateTime.now())}';
      return;
    }
    final encoded = jsonDecode(serialized) as Map<String, dynamic>;
    try {
      final saved = service.savePage(
        page.copyWith(
          title: title,
          document: encoded,
        ),
        checkpoint: checkpoint,
        reason: reason,
        leaseHolder: _holder,
      );
      final titleChanged = title != _lastSavedTitle;
      _activePage = saved;
      _lastSavedDocumentJson = serialized;
      _lastSavedTitle = title;
      _statusMessage.value = 'Guardado local · ${_shortTime(DateTime.now())}';
      if (titleChanged) _metadataVersion.value++;
    } on KnowledgeLockedException catch (error) {
      _editable = false;
      _statusMessage.value = error.toString();
    }
  }

  void _ensureBlockIds(Node node) {
    if (node.type != 'page' && node.attributes['knowledgeBlockId'] == null) {
      node.updateAttributes(<String, dynamic>{
        'knowledgeBlockId':
            'block-${DateTime.now().microsecondsSinceEpoch}-${node.hashCode}',
      });
    }
    for (final child in node.children) {
      _ensureBlockIds(child);
    }
  }

  Future<void> _addAsset(KnowledgeAssetKind expectedKind) async {
    const group = XTypeGroup(
      label: 'Recursos',
      extensions: <String>[
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
        'svg',
        'mp3',
        'wav',
        'ogg',
        'flac',
        'm4a',
        'mp4',
        'mkv',
        'webm',
        'mov',
        'avi',
        'pdf',
      ],
    );
    final selected =
        await openFile(acceptedTypeGroups: const <XTypeGroup>[group]);
    if (selected == null) return;
    try {
      final asset = await service.importAsset(selected.path);
      if (expectedKind != KnowledgeAssetKind.file &&
          asset.kind != expectedKind) {
        throw FormatException(
            'El archivo seleccionado no es de tipo ${_assetKindLabel(expectedKind)}.');
      }
      if (asset.kind == KnowledgeAssetKind.image) {
        await _insertNode(imageNode(url: service.absoluteAssetPath(asset))
          ..updateAttributes(<String, dynamic>{
            'knowledgeAssetId': asset.id,
            'knowledgeBlockId':
                'block-${DateTime.now().microsecondsSinceEpoch}',
          }));
      } else {
        await _insertNode(Node(
          type: 'knowledgeMedia',
          attributes: <String, dynamic>{
            'knowledgeAssetId': asset.id,
            'knowledgeKind': asset.kind.name,
            'knowledgeBlockId':
                'block-${DateTime.now().microsecondsSinceEpoch}',
            'caption': selected.name,
          },
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _pasteImageAsset() async {
    final result = await readClipboardImage();
    if (!mounted) return;
    if (!result.hasImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage!)),
      );
      return;
    }
    try {
      final asset = await service.importAssetBytes(
        result.bytes!,
        extension: '.png',
      );
      await _insertNode(imageNode(url: service.absoluteAssetPath(asset))
        ..updateAttributes(<String, dynamic>{
          'knowledgeAssetId': asset.id,
          'knowledgeBlockId': 'block-${DateTime.now().microsecondsSinceEpoch}',
        }));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imagen pegada.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo pegar la imagen: $error')),
        );
      }
    }
  }

  Future<void> _insertNode(Node node) async {
    final editor = _editorState;
    if (editor == null || !_editable) return;
    final transaction = editor.transaction
      ..insertNode(<int>[editor.document.root.children.length], node);
    await editor.apply(transaction);
  }

  Future<void> _createChildPage() async {
    final parent = _activePage;
    if (parent == null) return;
    await _createChildUnder(parent.id);
  }

  Future<void> _createChildUnder(String parentId) async {
    final title = await _askText('Nueva subpágina', 'Nombre de la página');
    if (title == null) return;
    final page = service.createPage(title: title, parentId: parentId);
    if (_activePage?.id == parentId) {
      await _insertNode(Node(
        type: 'knowledgePage',
        attributes: <String, dynamic>{
          'knowledgeTargetPageId': page.id,
          'knowledgeBlockId': 'block-${DateTime.now().microsecondsSinceEpoch}',
        },
      ));
    }
    await _openPage(page.id, newTab: true);
  }

  Future<void> _createCollection() async {
    final page = _activePage;
    if (page == null) return;
    final name = await _askText('Nueva colección', 'Ej. Actores o Logros');
    if (name == null) return;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final collection = service.createCollection(
      pageId: page.id,
      name: name,
      properties: <KnowledgePropertyDefinition>[
        KnowledgePropertyDefinition(
            id: 'prop-name-$stamp',
            name: 'Nombre',
            type: KnowledgePropertyType.text),
        KnowledgePropertyDefinition(
            id: 'prop-status-$stamp',
            name: 'Estado',
            type: KnowledgePropertyType.status),
        KnowledgePropertyDefinition(
            id: 'prop-date-$stamp',
            name: 'Fecha',
            type: KnowledgePropertyType.date),
        KnowledgePropertyDefinition(
            id: 'prop-image-$stamp',
            name: 'Imagen',
            type: KnowledgePropertyType.asset),
        KnowledgePropertyDefinition(
            id: 'prop-related-$stamp',
            name: 'Relación',
            type: KnowledgePropertyType.relation),
      ],
      views: <KnowledgeCollectionView>[
        KnowledgeCollectionView(
            id: 'view-table-$stamp',
            name: 'Tabla',
            type: KnowledgeViewType.table),
        KnowledgeCollectionView(
            id: 'view-list-$stamp',
            name: 'Lista',
            type: KnowledgeViewType.list),
        KnowledgeCollectionView(
            id: 'view-gallery-$stamp',
            name: 'Galería',
            type: KnowledgeViewType.gallery),
        KnowledgeCollectionView(
            id: 'view-board-$stamp',
            name: 'Tablero',
            type: KnowledgeViewType.board),
        KnowledgeCollectionView(
            id: 'view-calendar-$stamp',
            name: 'Calendario',
            type: KnowledgeViewType.calendar),
        KnowledgeCollectionView(
            id: 'view-timeline-$stamp',
            name: 'Cronología',
            type: KnowledgeViewType.timeline),
      ],
    );
    await _insertNode(Node(
      type: 'knowledgeCollection',
      attributes: <String, dynamic>{
        'knowledgeCollectionId': collection.id,
        'knowledgeViewType': KnowledgeViewType.gallery.name,
        'knowledgeBlockId': 'block-$stamp',
      },
    ));
  }

  Future<void> _insertInternalLink() async {
    final pages = service.listPages();
    final selected = await showDialog<KnowledgePage>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enlazar una página'),
        content: SizedBox(
          width: 480,
          height: 420,
          child: ListView(
            children: [
              for (final page in pages)
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(page.title),
                  onTap: () => Navigator.of(context).pop(page),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    await _insertNode(Node(
      type: 'knowledgePage',
      attributes: <String, dynamic>{
        'knowledgeBlockId': 'block-${DateTime.now().microsecondsSinceEpoch}',
        'knowledgeTargetPageId': selected.id,
        'knowledgeHref': 'knowledge://page/${selected.id}',
      },
    ));
  }

  Future<void> _editSources() async {
    final page = _activePage;
    if (page == null) return;
    final current = (page.properties['sources'] as List? ?? const <dynamic>[])
        .whereType<String>()
        .join('\n');
    final value = await _askText(
        'Fuentes de la página', 'Una URL o referencia por línea',
        initial: current, lines: 10);
    if (value == null) return;
    final sources = value
        .split(RegExp(r'\r?\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    _activePage = page.copyWith(
        properties: <String, dynamic>{...page.properties, 'sources': sources});
    await _saveActive(checkpoint: true, reason: 'edit-sources');
  }

  Future<String?> _askText(String title, String hint,
      {String initial = '', int lines = 1}) async {
    var value = initial;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 520,
          child: TextFormField(
            initialValue: initial,
            autofocus: true,
            minLines: lines,
            maxLines: lines,
            decoration: InputDecoration(hintText: hint),
            onChanged: (next) => value = next,
            onFieldSubmitted: lines == 1
                ? (next) => Navigator.of(context).pop(next.trim())
                : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(value.trim()),
              child: const Text('Guardar')),
        ],
      ),
    );
    return result?.trim().isEmpty == true ? null : result;
  }

  void _togglePin(int index) {
    final tab = _tabs[index];
    setState(() {
      _tabs[index] = KnowledgeTab(
        pageId: tab.pageId,
        pinned: !tab.pinned,
        backHistory: tab.backHistory,
        forwardHistory: tab.forwardHistory,
      );
      _persistTabs();
    });
  }

  void _closeTab(int index) {
    if (_tabs[index].pinned) return;
    final wasActive = _tabs[index].pageId == _activePage?.id;
    setState(() => _tabs.removeAt(index));
    if (_tabs.isEmpty) {
      final root = service.rootForOwner('libraryItem', widget.libraryItem.id);
      if (root != null) _tabs.add(KnowledgeTab(pageId: root.id, pinned: true));
    }
    if (wasActive && _tabs.isNotEmpty) {
      _openPage(_tabs[index.clamp(0, _tabs.length - 1)].pageId);
    } else {
      _persistTabs();
    }
  }

  void _persistTabs() => service.saveTabs(_tabs, _activePage?.id);

  Future<void> _showSearch() async {
    _searchController.clear();
    _searchResults = service.search('', limit: 50);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Buscar en el conocimiento'),
          content: SizedBox(
            width: 650,
            height: 520,
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Título, contenido o propiedad...'),
                  onChanged: (value) => setDialogState(
                      () => _searchResults = service.search(value)),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    children: [
                      for (final result in _searchResults)
                        ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: Text(result.page.title),
                          subtitle: result.snippet.isEmpty
                              ? null
                              : Text(result.snippet,
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            _openPage(result.page.id, newTab: true);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showHistory() async {
    final page = _activePage;
    if (page == null) return;
    final revisions = service.revisions(page.id);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Historial de ${page.title}'),
        content: SizedBox(
          width: 620,
          height: 480,
          child: revisions.isEmpty
              ? const Center(child: Text('Aún no hay versiones anteriores.'))
              : ListView(
                  children: [
                    for (final revision in revisions)
                      ListTile(
                        leading: const Icon(Icons.history_rounded),
                        title: Text(revision['reason'] as String),
                        subtitle: Text(revision['createdAt'] as String),
                        trailing: TextButton(
                          onPressed: _editable
                              ? () {
                                  service.restoreRevision(
                                      revision['id'] as String,
                                      leaseHolder: _holder);
                                  Navigator.of(dialogContext).pop();
                                  _openPage(page.id);
                                }
                              : null,
                          child: const Text('Restaurar'),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _showTrash() async {
    final trashed = service
        .listPages(includeTrashed: true)
        .where((page) => page.isTrashed)
        .toList();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Papelera de páginas'),
        content: SizedBox(
          width: 600,
          height: 450,
          child: trashed.isEmpty
              ? const Center(child: Text('La papelera está vacía.'))
              : ListView(
                  children: [
                    for (final page in trashed)
                      ListTile(
                        leading: const Icon(Icons.delete_outline_rounded),
                        title: Text(page.title),
                        subtitle: Text(page.deletedAt == null
                            ? ''
                            : _shortDate(page.deletedAt!)),
                        trailing: TextButton(
                          onPressed: () {
                            service.restoreTree(page.id);
                            Navigator.of(dialogContext).pop();
                            setState(() {});
                          },
                          child: const Text('Restaurar'),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _export() async {
    _statusMessage.value = 'Creando copia exportable…';
    try {
      final file = await service.exportArchive();
      if (!mounted) return;
      _statusMessage.value = 'Exportado en ${file.path}';
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copia creada en ${file.path}')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo exportar: $error')));
      }
    }
  }

  void _scrollToBlock(String blockId) {
    final editor = _editorState;
    final scrollController = _editorScrollController;
    if (editor == null || scrollController == null) return;
    Node? target;
    void visit(Node node) {
      if (target != null) return;
      if (node.attributes['knowledgeBlockId'] == blockId) {
        target = node;
        return;
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    visit(editor.document.root);
    final node = target;
    if (node == null || node.path.isEmpty) return;
    scrollController.jumpTo(offset: node.path.first.toDouble());
    editor.selection = Selection.collapsed(Position(path: node.path));
    _statusMessage.value = 'Bloque resaltado';
  }

  List<(int, String, String?)> _headings(Map<String, dynamic> document) {
    final result = <(int, String, String?)>[];
    void visit(Object? value) {
      if (value is Map) {
        if (value['type'] == 'heading' && value['data'] is Map) {
          final data = value['data'] as Map;
          final text = (data['delta'] as List? ?? const <dynamic>[])
              .whereType<Map>()
              .map((item) => item['insert'])
              .whereType<String>()
              .join();
          if (text.isNotEmpty) {
            result.add((
              (data['level'] as num?)?.toInt() ?? 1,
              text,
              data['knowledgeBlockId']?.toString(),
            ));
          }
        }
        for (final child in value.values) {
          visit(child);
        }
      } else if (value is List) {
        for (final child in value) {
          visit(child);
        }
      }
    }

    visit(document);
    return result;
  }

  String _shortDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  String _shortTime(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  String _assetKindLabel(KnowledgeAssetKind kind) => switch (kind) {
        KnowledgeAssetKind.image => 'imagen',
        KnowledgeAssetKind.audio => 'audio',
        KnowledgeAssetKind.video => 'vídeo',
        KnowledgeAssetKind.pdf => 'PDF',
        KnowledgeAssetKind.file => 'archivo',
      };
}
