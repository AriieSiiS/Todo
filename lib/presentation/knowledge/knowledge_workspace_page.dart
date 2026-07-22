import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/state/todo_workspace.dart';
import '../../domain/models.dart';
import '../../services/knowledge_service.dart';

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
  bool _editable = true;
  bool _disposing = false;
  int _navigationGeneration = 0;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _openInitialWorkspace();
  }

  void _openInitialWorkspace() {
    final root = service.rootForOwner('libraryItem', widget.libraryItem.id);
    if (root == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await service.syncLibraryItem(widget.libraryItem);
        if (!mounted) return;
        final created =
            service.rootForOwner('libraryItem', widget.libraryItem.id);
        if (created != null) _openPage(created.id);
      });
      return;
    }
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
    _editorScrollController?.dispose();
    _saveActive(checkpoint: true, reason: 'close-workspace');
    final page = _activePage;
    if (page != null) service.releaseLease(page.id, _holder);
    _editorState?.dispose();
    _searchController.dispose();
    _titleController.dispose();
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
          _buildTabs(),
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
                Text(
                  _statusMessage ??
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
    return Container(
      color: const Color(0xFFF8F4EE),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Páginas',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  onPressed: _editable ? _createChildPage : null,
                  tooltip: 'Nueva subpágina',
                  icon: const Icon(Icons.add_rounded, size: 20),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(
                  () => _searchResults = service.search(value, limit: 20)),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Buscar páginas y contenido...',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _searchController.text.trim().isNotEmpty
                ? ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      for (final result in _searchResults)
                        ListTile(
                          dense: true,
                          leading:
                              const Icon(Icons.description_outlined, size: 18),
                          title: Text(result.page.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: result.snippet.isEmpty
                              ? null
                              : Text(result.snippet,
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () => _openPage(result.page.id, newTab: true),
                        ),
                    ],
                  )
                : root == null
                    ? const SizedBox.shrink()
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        children: [
                          _PageTreeNode(
                            service: service,
                            page: root,
                            activePageId: _activePage?.id,
                            onOpen: (pageId) => _openPage(pageId),
                            onOpenNewTab: (pageId) =>
                                _openPage(pageId, newTab: true),
                            onAddChild: _editable ? _createChildUnder : null,
                          )
                        ],
                      ),
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: const Icon(Icons.delete_outline_rounded, size: 19),
            title: const Text('Papelera'),
            onTap: _showTrash,
          ),
        ],
      ),
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
        'knowledgeCollection': _KnowledgeCollectionBlockBuilder(
          service,
          (pageId) => _openPageFromBlock(pageId, null),
        ),
      },
      commandShortcutEvents: standardCommandShortcutEvents,
      characterShortcutEvents: standardCharacterShortcutEvents,
      editorStyle: EditorStyle.desktop(
        padding: const EdgeInsets.fromLTRB(72, 12, 72, 80),
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

  Widget _buildBlockToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(68, 0, 60, 10),
      child: Wrap(
        spacing: 4,
        children: [
          _toolbarButton(Icons.image_outlined, 'Imagen',
              () => _addAsset(KnowledgeAssetKind.image)),
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
    _statusMessage = _editable
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
    if (mounted) {
      setState(() {
        _statusMessage = 'Guardando cambios…';
      });
    }
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
    final encoded = jsonDecode(jsonEncode(editor.document.toJson()))
        as Map<String, dynamic>;
    try {
      final saved = service.savePage(
        page.copyWith(
          title: _titleController.text.trim().isEmpty
              ? 'Sin título'
              : _titleController.text.trim(),
          document: encoded,
        ),
        checkpoint: checkpoint,
        reason: reason,
        leaseHolder: _holder,
      );
      _activePage = saved;
      _statusMessage = 'Guardado local · ${_shortTime(DateTime.now())}';
      if (mounted && !_disposing) setState(() {});
    } on KnowledgeLockedException catch (error) {
      _editable = false;
      _statusMessage = error.toString();
      if (mounted && !_disposing) setState(() {});
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
    setState(() => _statusMessage = 'Creando copia exportable…');
    try {
      final file = await service.exportArchive();
      if (!mounted) return;
      setState(() => _statusMessage = 'Exportado en ${file.path}');
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
    setState(() => _statusMessage = 'Bloque resaltado');
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

class _PageTreeNode extends StatefulWidget {
  const _PageTreeNode({
    required this.service,
    required this.page,
    required this.activePageId,
    required this.onOpen,
    required this.onOpenNewTab,
    this.onAddChild,
  });

  final KnowledgeService service;
  final KnowledgePage page;
  final String? activePageId;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onOpenNewTab;
  final Future<void> Function(String pageId)? onAddChild;

  @override
  State<_PageTreeNode> createState() => _PageTreeNodeState();
}

class _PageTreeNodeState extends State<_PageTreeNode> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final children = widget.service.childrenOf(widget.page.id);
    final active = widget.activePageId == widget.page.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => widget.onOpen(widget.page.id),
          onDoubleTap: () => widget.onOpenNewTab(widget.page.id),
          borderRadius: BorderRadius.circular(7),
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 7, 4, 7),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFDDE8D5) : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: children.isEmpty
                      ? const Icon(Icons.description_outlined, size: 17)
                      : IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () =>
                              setState(() => _expanded = !_expanded),
                          icon: Icon(
                              _expanded
                                  ? Icons.expand_more_rounded
                                  : Icons.chevron_right_rounded,
                              size: 18),
                        ),
                ),
                const SizedBox(width: 3),
                Expanded(
                    child: Text(widget.page.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (widget.onAddChild != null)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => widget.onAddChild!(widget.page.id),
                    tooltip: 'Añadir subpágina',
                    icon: const Icon(Icons.add_rounded, size: 17),
                  ),
              ],
            ),
          ),
        ),
        if (_expanded && children.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              children: [
                for (final child in children)
                  _PageTreeNode(
                    service: widget.service,
                    page: child,
                    activePageId: widget.activePageId,
                    onOpen: widget.onOpen,
                    onOpenNewTab: widget.onOpenNewTab,
                    onAddChild: widget.onAddChild,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _KnowledgeMediaBlockBuilder extends BlockComponentBuilder {
  _KnowledgeMediaBlockBuilder(
    this.service, {
    required this.editable,
    required this.onUpdate,
  });

  final KnowledgeService service;
  final bool editable;
  final Future<void> Function(Node, Map<String, dynamic>) onUpdate;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    return _KnowledgeMediaBlock(
      key: blockComponentContext.node.key,
      node: blockComponentContext.node,
      service: service,
      editable: editable,
      onUpdate: onUpdate,
      configuration: configuration,
    );
  }

  @override
  BlockComponentValidate get validate => (node) => node.children.isEmpty;
}

class _KnowledgeMediaBlock extends BlockComponentStatefulWidget {
  const _KnowledgeMediaBlock({
    required super.key,
    required super.node,
    required super.configuration,
    required this.service,
    required this.editable,
    required this.onUpdate,
  });

  final KnowledgeService service;
  final bool editable;
  final Future<void> Function(Node, Map<String, dynamic>) onUpdate;

  @override
  State<_KnowledgeMediaBlock> createState() => _KnowledgeMediaBlockState();
}

class _KnowledgeMediaBlockState extends State<_KnowledgeMediaBlock> {
  Player? _player;
  VideoController? _videoController;
  bool _imageSelected = false;
  double? _draftImageWidth;

  KnowledgeAsset? get asset => widget.service
      .assetById(widget.node.attributes['knowledgeAssetId']?.toString() ?? '');

  @override
  void initState() {
    super.initState();
    final current = asset;
    if (current?.kind == KnowledgeAssetKind.audio ||
        current?.kind == KnowledgeAssetKind.video) {
      _player = Player();
      if (current?.kind == KnowledgeAssetKind.video) {
        _videoController = VideoController(_player!);
      }
      final path =
          current == null ? '' : widget.service.absoluteAssetPath(current);
      if (path.isNotEmpty) unawaited(_player!.open(Media(path), play: false));
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = asset;
    if (current == null) {
      final source = widget.node.attributes['url']?.toString() ?? '';
      if (widget.node.type == 'image' && source.isNotEmpty) {
        return _buildImageBlock(source);
      }
      return const Padding(
          padding: EdgeInsets.all(16), child: Text('Recurso no disponible.'));
    }
    final path = widget.service.absoluteAssetPath(current);
    if (current.kind == KnowledgeAssetKind.image) {
      return _buildImageBlock(path);
    }
    Widget child;
    switch (current.kind) {
      case KnowledgeAssetKind.video:
        child =
            SizedBox(height: 360, child: Video(controller: _videoController!));
      case KnowledgeAssetKind.audio:
        child = StreamBuilder<bool>(
          stream: _player!.stream.playing,
          builder: (context, snapshot) => ListTile(
            leading: IconButton(
              onPressed: () =>
                  snapshot.data == true ? _player!.pause() : _player!.play(),
              icon: Icon(
                  snapshot.data == true
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  size: 36),
            ),
            title:
                Text(widget.node.attributes['caption']?.toString() ?? 'Audio'),
            subtitle: const Text('Recurso local gestionado'),
          ),
        );
      case KnowledgeAssetKind.pdf:
        child = SizedBox(height: 520, child: PdfViewer.file(path));
      case KnowledgeAssetKind.file:
        child = ListTile(
          leading: const Icon(Icons.insert_drive_file_outlined, size: 34),
          title:
              Text(widget.node.attributes['caption']?.toString() ?? 'Archivo'),
          subtitle: Text('${(current.size / 1024).toStringAsFixed(1)} KB'),
          trailing: const Icon(Icons.open_in_new_rounded),
          onTap: () => launchUrl(Uri.file(path)),
        );
      case KnowledgeAssetKind.image:
        throw StateError('Las imágenes se construyen como bloques editables.');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F4EE),
          border: Border.all(color: const Color(0xFFE3D8CB)),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }

  Widget _buildImageBlock(String path) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 900.0;
        final minWidth = maxWidth < 160 ? maxWidth : 160.0;
        final storedWidth = _nullableAttributeDouble('knowledgeImageWidth') ??
            _nullableAttributeDouble('width') ??
            maxWidth;
        final imageWidth = (_draftImageWidth ?? storedWidth)
            .clamp(minWidth, maxWidth)
            .toDouble();
        final blockAlignment = switch (
            widget.node.attributes['knowledgeImageAlignment']?.toString() ??
                widget.node.attributes['align']?.toString()) {
          'start' || 'left' => Alignment.centerLeft,
          'end' || 'right' => Alignment.centerRight,
          _ => Alignment.center,
        };
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Align(
            alignment: blockAlignment,
            child: SizedBox(
              width: imageWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.editable
                    ? () => setState(() => _imageSelected = true)
                    : null,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F4EE),
                        border: Border.all(
                          color: _imageSelected
                              ? const Color(0xFF708A5B)
                              : const Color(0xFFE3D8CB),
                          width: _imageSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _buildImageViewport(path),
                    ),
                    if (_imageSelected && widget.editable) ...[
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _buildImageToolbar(
                          path: path,
                          width: imageWidth,
                          maxWidth: maxWidth,
                        ),
                      ),
                      Positioned(
                        right: -7,
                        bottom: -7,
                        child: Tooltip(
                          message: 'Arrastra para cambiar el tamaño',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragUpdate: (details) {
                              setState(() {
                                _draftImageWidth =
                                    (imageWidth + details.delta.dx)
                                        .clamp(minWidth, maxWidth)
                                        .toDouble();
                              });
                            },
                            onHorizontalDragEnd: (_) {
                              final width = _draftImageWidth ?? imageWidth;
                              _updateImageAttributes(<String, dynamic>{
                                'knowledgeImageWidth': width
                              });
                            },
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0xFF607A4D),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: const Color(0xFFFFFCF8), width: 2),
                                boxShadow: const <BoxShadow>[
                                  BoxShadow(
                                      color: Color(0x33000000), blurRadius: 4),
                                ],
                              ),
                              child: const Icon(Icons.open_in_full_rounded,
                                  size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageViewport(String path) {
    final aspectRatio =
        _nullableAttributeDouble('knowledgeImageCropAspectRatio');
    if (aspectRatio == null) {
      return _knowledgeImageWidget(
        path,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => const SizedBox(
          height: 160,
          child: Center(child: Text('No se pudo mostrar la imagen.')),
        ),
      );
    }
    final zoom = _attributeDouble('knowledgeImageCropZoom', 1).clamp(1, 4);
    final focusX =
        _attributeDouble('knowledgeImageCropX', 0).clamp(-1, 1).toDouble();
    final focusY =
        _attributeDouble('knowledgeImageCropY', 0).clamp(-1, 1).toDouble();
    return AspectRatio(
      aspectRatio: aspectRatio.clamp(0.35, 3).toDouble(),
      child: ClipRect(
        child: Transform.scale(
          scale: zoom.toDouble(),
          child: _knowledgeImageWidget(
            path,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            alignment: Alignment(focusX, focusY),
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Text('No se pudo mostrar la imagen.'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageToolbar({
    required String path,
    required double width,
    required double maxWidth,
  }) {
    return Material(
      color: const Color(0xF7FFFCF8),
      elevation: 3,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 38,
        padding: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD9CCBD)),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${width.round()} px',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            IconButton(
              onPressed: () => _showCropDialog(path),
              tooltip: 'Recortar imagen',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.crop_rounded, size: 18),
            ),
            PopupMenuButton<_KnowledgeImageAction>(
              tooltip: 'Opciones de imagen',
              iconSize: 18,
              onSelected: (action) => _applyImageAction(action, maxWidth),
              itemBuilder: (context) =>
                  const <PopupMenuEntry<_KnowledgeImageAction>>[
                PopupMenuItem(
                  value: _KnowledgeImageAction.width25,
                  child: Text('Tamaño: 25 %'),
                ),
                PopupMenuItem(
                  value: _KnowledgeImageAction.width50,
                  child: Text('Tamaño: 50 %'),
                ),
                PopupMenuItem(
                  value: _KnowledgeImageAction.width75,
                  child: Text('Tamaño: 75 %'),
                ),
                PopupMenuItem(
                  value: _KnowledgeImageAction.width100,
                  child: Text('Ajustar al ancho'),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: _KnowledgeImageAction.alignStart,
                  child: Text('Alinear a la izquierda'),
                ),
                PopupMenuItem(
                  value: _KnowledgeImageAction.alignCenter,
                  child: Text('Centrar'),
                ),
                PopupMenuItem(
                  value: _KnowledgeImageAction.alignEnd,
                  child: Text('Alinear a la derecha'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _applyImageAction(_KnowledgeImageAction action, double maxWidth) {
    switch (action) {
      case _KnowledgeImageAction.width25:
        _setImageWidth(maxWidth * 0.25, maxWidth);
      case _KnowledgeImageAction.width50:
        _setImageWidth(maxWidth * 0.5, maxWidth);
      case _KnowledgeImageAction.width75:
        _setImageWidth(maxWidth * 0.75, maxWidth);
      case _KnowledgeImageAction.width100:
        _setImageWidth(maxWidth, maxWidth);
      case _KnowledgeImageAction.alignStart:
        _updateImageAttributes(
            <String, dynamic>{'knowledgeImageAlignment': 'start'});
      case _KnowledgeImageAction.alignCenter:
        _updateImageAttributes(
            <String, dynamic>{'knowledgeImageAlignment': 'center'});
      case _KnowledgeImageAction.alignEnd:
        _updateImageAttributes(
            <String, dynamic>{'knowledgeImageAlignment': 'end'});
    }
  }

  void _setImageWidth(double width, double maxWidth) {
    final minimum = maxWidth < 160 ? maxWidth : 160.0;
    final next = width.clamp(minimum, maxWidth).toDouble();
    setState(() => _draftImageWidth = next);
    _updateImageAttributes(<String, dynamic>{'knowledgeImageWidth': next});
  }

  Future<void> _showCropDialog(String path) async {
    final result = await showDialog<_KnowledgeImageCropSettings>(
      context: context,
      builder: (context) => _KnowledgeImageCropDialog(
        imagePath: path,
        initial: _KnowledgeImageCropSettings(
          aspectRatio:
              _nullableAttributeDouble('knowledgeImageCropAspectRatio'),
          zoom: _attributeDouble('knowledgeImageCropZoom', 1),
          focusX: _attributeDouble('knowledgeImageCropX', 0),
          focusY: _attributeDouble('knowledgeImageCropY', 0),
        ),
      ),
    );
    if (result == null || !mounted) return;
    _updateImageAttributes(<String, dynamic>{
      'knowledgeImageCropAspectRatio': result.aspectRatio,
      'knowledgeImageCropZoom': result.zoom,
      'knowledgeImageCropX': result.focusX,
      'knowledgeImageCropY': result.focusY,
    });
  }

  double _attributeDouble(String key, double fallback) =>
      _nullableAttributeDouble(key) ?? fallback;

  double? _nullableAttributeDouble(String key) {
    final value = widget.node.attributes[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  void _updateImageAttributes(Map<String, dynamic> attributes) {
    unawaited(widget.onUpdate(widget.node, attributes));
  }
}

enum _KnowledgeImageAction {
  width25,
  width50,
  width75,
  width100,
  alignStart,
  alignCenter,
  alignEnd,
}

class _KnowledgeImageCropSettings {
  const _KnowledgeImageCropSettings({
    required this.aspectRatio,
    required this.zoom,
    required this.focusX,
    required this.focusY,
  });

  final double? aspectRatio;
  final double zoom;
  final double focusX;
  final double focusY;
}

class _KnowledgeImageCropDialog extends StatefulWidget {
  const _KnowledgeImageCropDialog({
    required this.imagePath,
    required this.initial,
  });

  final String imagePath;
  final _KnowledgeImageCropSettings initial;

  @override
  State<_KnowledgeImageCropDialog> createState() =>
      _KnowledgeImageCropDialogState();
}

class _KnowledgeImageCropDialogState extends State<_KnowledgeImageCropDialog> {
  late bool _enabled;
  late double _ratio;
  late double _zoom;
  late double _focusX;
  late double _focusY;
  late bool _customRatio;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initial.aspectRatio != null;
    _ratio = widget.initial.aspectRatio ?? 16 / 9;
    _zoom = widget.initial.zoom.clamp(1, 4).toDouble();
    _focusX = widget.initial.focusX.clamp(-1, 1).toDouble();
    _focusY = widget.initial.focusY.clamp(-1, 1).toDouble();
    _customRatio = _enabled && !_isPresetRatio(_ratio);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.crop_rounded, color: Color(0xFF607A4D)),
                  SizedBox(width: 10),
                  Text('Recortar imagen',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'El recorte no modifica el archivo original. Puedes cambiarlo o quitarlo cuando quieras.',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 18),
              Expanded(child: _buildPreview()),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Original'),
                    selected: !_enabled,
                    onSelected: (_) => setState(() {
                      _enabled = false;
                      _customRatio = false;
                    }),
                  ),
                  _ratioChip('Cuadrada', 1),
                  _ratioChip('4:3', 4 / 3),
                  _ratioChip('16:9', 16 / 9),
                  _ratioChip('Vertical 3:4', 3 / 4),
                  ChoiceChip(
                    label: const Text('Libre'),
                    selected: _enabled && _customRatio,
                    onSelected: (_) => setState(() {
                      _enabled = true;
                      _customRatio = true;
                    }),
                  ),
                ],
              ),
              if (_enabled) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 104, child: Text('Zoom')),
                    Expanded(
                      child: Slider(
                        value: _zoom,
                        min: 1,
                        max: 4,
                        divisions: 30,
                        label: '${_zoom.toStringAsFixed(1)}×',
                        onChanged: (value) => setState(() => _zoom = value),
                      ),
                    ),
                  ],
                ),
                if (_customRatio)
                  Row(
                    children: [
                      const SizedBox(
                        width: 104,
                        child: Text(
                          'Proporción',
                          key: ValueKey('knowledge-image-crop-ratio-label'),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _ratio.clamp(0.5, 2.4),
                          min: 0.5,
                          max: 2.4,
                          divisions: 38,
                          label: _ratio.toStringAsFixed(2),
                          onChanged: (value) => setState(() => _ratio = value),
                        ),
                      ),
                    ],
                  ),
                const Text(
                  'Arrastra la imagen en la vista previa para elegir el punto de enfoque.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF777168)),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _enabled = false;
                      _customRatio = false;
                      _ratio = 16 / 9;
                      _zoom = 1;
                      _focusX = 0;
                      _focusY = 0;
                    }),
                    child: const Text('Restablecer'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      _KnowledgeImageCropSettings(
                        aspectRatio: _enabled ? _ratio : null,
                        zoom: _enabled ? _zoom : 1,
                        focusX: _enabled ? _focusX : 0,
                        focusY: _enabled ? _focusY : 0,
                      ),
                    ),
                    child: const Text('Aplicar recorte'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ratio = _enabled ? _ratio.clamp(0.5, 2.4).toDouble() : 16 / 9;
        var width = constraints.maxWidth;
        var height = width / ratio;
        if (height > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = height * ratio;
        }
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: GestureDetector(
              key: const ValueKey('knowledge-image-crop-preview'),
              behavior: HitTestBehavior.opaque,
              onPanUpdate: !_enabled
                  ? null
                  : (details) {
                      setState(() {
                        _focusX = (_focusX - (details.delta.dx / width) * 2)
                            .clamp(-1, 1)
                            .toDouble();
                        _focusY = (_focusY - (details.delta.dy / height) * 2)
                            .clamp(-1, 1)
                            .toDouble();
                      });
                    },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF24231F),
                  border: Border.all(color: const Color(0xFF607A4D), width: 2),
                ),
                child: ClipRect(
                  child: Transform.scale(
                    scale: _enabled ? _zoom : 1,
                    child: _knowledgeImageWidget(
                      widget.imagePath,
                      width: double.infinity,
                      height: double.infinity,
                      fit: _enabled ? BoxFit.cover : BoxFit.contain,
                      alignment: Alignment(_focusX, _focusY),
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _ratioChip(String label, double ratio) {
    return ChoiceChip(
      label: Text(label),
      selected: _enabled && !_customRatio && (_ratio - ratio).abs() < 0.01,
      onSelected: (_) => setState(() {
        _enabled = true;
        _customRatio = false;
        _ratio = ratio;
      }),
    );
  }

  bool _isPresetRatio(double ratio) => <double>[1, 4 / 3, 16 / 9, 3 / 4]
      .any((value) => (value - ratio).abs() < 0.01);
}

Widget _knowledgeImageWidget(
  String source, {
  double? width,
  double? height,
  required BoxFit fit,
  Alignment alignment = Alignment.center,
  FilterQuality filterQuality = FilterQuality.medium,
  ImageErrorWidgetBuilder? errorBuilder,
}) {
  final uri = Uri.tryParse(source);
  if (uri?.scheme == 'http' || uri?.scheme == 'https') {
    return Image.network(
      source,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      errorBuilder: errorBuilder,
    );
  }
  if (uri?.scheme == 'data') {
    try {
      return Image.memory(
        UriData.parse(source).contentAsBytes(),
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        filterQuality: filterQuality,
        errorBuilder: errorBuilder,
      );
    } catch (_) {
      // La vista de error uniforme se construye debajo.
    }
  }
  return Image.file(
    File(source),
    width: width,
    height: height,
    fit: fit,
    alignment: alignment,
    filterQuality: filterQuality,
    errorBuilder: errorBuilder,
  );
}

class _KnowledgePageBlockBuilder extends BlockComponentBuilder {
  _KnowledgePageBlockBuilder(this.service, this.onOpen);
  final KnowledgeService service;
  final void Function(String pageId, String? blockId) onOpen;

  @override
  BlockComponentWidget build(BlockComponentContext context) =>
      _KnowledgePageBlock(
        key: context.node.key,
        node: context.node,
        configuration: configuration,
        service: service,
        onOpen: onOpen,
      );

  @override
  BlockComponentValidate get validate => (node) => node.children.isEmpty;
}

class _KnowledgePageBlock extends BlockComponentStatelessWidget {
  const _KnowledgePageBlock({
    required super.key,
    required super.node,
    required super.configuration,
    required this.service,
    required this.onOpen,
  });

  final KnowledgeService service;
  final void Function(String pageId, String? blockId) onOpen;

  @override
  Widget build(BuildContext context) {
    final pageId = node.attributes['knowledgeTargetPageId']?.toString() ?? '';
    final page = service.pageById(pageId);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 7),
      elevation: 0,
      color: const Color(0xFFF5F8EF),
      child: ListTile(
        leading:
            const Icon(Icons.description_outlined, color: Color(0xFF607A4D)),
        title: Text(page?.title ?? 'Página no disponible',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.arrow_forward_rounded),
        onTap: page == null
            ? null
            : () => onOpen(
                  page.id,
                  node.attributes['knowledgeTargetBlockId']?.toString(),
                ),
      ),
    );
  }
}

class _KnowledgeCollectionBlockBuilder extends BlockComponentBuilder {
  _KnowledgeCollectionBlockBuilder(this.service, this.onOpen);
  final KnowledgeService service;
  final ValueChanged<String> onOpen;

  @override
  BlockComponentWidget build(BlockComponentContext context) =>
      _KnowledgeCollectionBlock(
        key: context.node.key,
        node: context.node,
        configuration: configuration,
        service: service,
        onOpen: onOpen,
      );

  @override
  BlockComponentValidate get validate => (node) => node.children.isEmpty;
}

class _KnowledgeCollectionBlock extends BlockComponentStatefulWidget {
  const _KnowledgeCollectionBlock({
    required super.key,
    required super.node,
    required super.configuration,
    required this.service,
    required this.onOpen,
  });

  final KnowledgeService service;
  final ValueChanged<String> onOpen;

  @override
  State<_KnowledgeCollectionBlock> createState() =>
      _KnowledgeCollectionBlockState();
}

class _KnowledgeCollectionBlockState extends State<_KnowledgeCollectionBlock> {
  KnowledgeViewType get _viewType {
    final raw = widget.node.attributes['knowledgeViewType']?.toString();
    return KnowledgeViewType.values
            .where((type) => type.name == raw)
            .firstOrNull ??
        KnowledgeViewType.table;
  }

  @override
  Widget build(BuildContext context) {
    final collectionId =
        widget.node.attributes['knowledgeCollectionId']?.toString() ?? '';
    final collection = widget.service.collectionById(collectionId);
    final records = widget.service.collectionRecords(collectionId);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD7E4CC)),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFF8FAF5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.view_module_outlined, color: Color(0xFF607A4D)),
              const SizedBox(width: 9),
              Expanded(
                  child: Text(collection?.name ?? 'Colección',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800))),
              PopupMenuButton<KnowledgeViewType>(
                tooltip: 'Cambiar vista',
                initialValue: _viewType,
                onSelected: (type) {
                  widget.node.updateAttributes(<String, dynamic>{
                    'knowledgeViewType': type.name,
                  });
                  setState(() {});
                },
                itemBuilder: (context) => [
                  for (final type in KnowledgeViewType.values)
                    PopupMenuItem<KnowledgeViewType>(
                      value: type,
                      child: Text(_knowledgeViewLabel(type)),
                    ),
                ],
                child: Chip(
                  avatar: Icon(_knowledgeViewIcon(_viewType), size: 17),
                  label: Text(_knowledgeViewLabel(_viewType)),
                ),
              ),
              const SizedBox(width: 8),
              Text('${records.length} páginas'),
            ],
          ),
          const SizedBox(height: 12),
          if (records.isEmpty)
            const Padding(
                padding: EdgeInsets.all(12),
                child: Text('La colección está vacía.'))
          else
            _buildRecords(records),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: collection == null
                  ? null
                  : () {
                      final page = widget.service.createPage(
                        title: 'Nuevo registro',
                        parentId: collection.pageId,
                        collectionId: collection.id,
                      );
                      widget.onOpen(page.id);
                    },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva página'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecords(List<Map<String, dynamic>> records) {
    if (_viewType == KnowledgeViewType.table) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const <DataColumn>[
            DataColumn(label: Text('Página')),
            DataColumn(label: Text('Propiedades')),
          ],
          rows: [
            for (final record in records)
              DataRow(cells: <DataCell>[
                DataCell(
                  Text(record['title'] as String),
                  onTap: () => widget.onOpen(record['id'] as String),
                ),
                DataCell(Text(
                  ((record['properties'] as Map?) ?? const <dynamic, dynamic>{})
                      .values
                      .where((value) => value != null)
                      .take(3)
                      .join(' · '),
                )),
              ]),
          ],
        ),
      );
    }
    if (_viewType == KnowledgeViewType.gallery) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final record in records)
            SizedBox(
              width: 160,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => widget.onOpen(record['id'] as String),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.image_outlined, size: 36),
                        const SizedBox(height: 8),
                        Text(record['title'] as String,
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }
    if (_viewType == KnowledgeViewType.board) {
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final record in records) {
        final properties =
            (record['properties'] as Map?) ?? const <dynamic, dynamic>{};
        final status = properties.values
                .whereType<String>()
                .where((value) => value.isNotEmpty)
                .firstOrNull ??
            'Sin grupo';
        grouped.putIfAbsent(status, () => <Map<String, dynamic>>[]).add(record);
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in grouped.entries)
              Container(
                width: 190,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(10),
                color: const Color(0xFFF0F3EC),
                child: Column(
                  children: [
                    Text(entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    for (final record in entry.value)
                      ListTile(
                        dense: true,
                        title: Text(record['title'] as String),
                        onTap: () => widget.onOpen(record['id'] as String),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    final recordsToShow = [...records];
    if (_viewType == KnowledgeViewType.calendar ||
        _viewType == KnowledgeViewType.timeline) {
      recordsToShow.sort(
          (left, right) => _recordDate(left).compareTo(_recordDate(right)));
    }
    return Column(
      children: [
        for (final record in recordsToShow)
          ListTile(
            dense: true,
            leading: Icon(switch (_viewType) {
              KnowledgeViewType.calendar => Icons.event_outlined,
              KnowledgeViewType.timeline => Icons.timeline_rounded,
              _ => Icons.description_outlined,
            }),
            title: Text(record['title'] as String),
            subtitle: _viewType == KnowledgeViewType.calendar ||
                    _viewType == KnowledgeViewType.timeline
                ? Text(_recordDate(record))
                : null,
            onTap: () => widget.onOpen(record['id'] as String),
          ),
      ],
    );
  }

  String _recordDate(Map<String, dynamic> record) {
    final properties =
        (record['properties'] as Map?) ?? const <dynamic, dynamic>{};
    return properties.values
            .whereType<String>()
            .where((value) => RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value))
            .firstOrNull ??
        'Sin fecha';
  }
}

String _knowledgeViewLabel(KnowledgeViewType type) => switch (type) {
      KnowledgeViewType.table => 'Tabla',
      KnowledgeViewType.list => 'Lista',
      KnowledgeViewType.gallery => 'Galería',
      KnowledgeViewType.board => 'Tablero',
      KnowledgeViewType.calendar => 'Calendario',
      KnowledgeViewType.timeline => 'Cronología',
    };

IconData _knowledgeViewIcon(KnowledgeViewType type) => switch (type) {
      KnowledgeViewType.table => Icons.table_chart_outlined,
      KnowledgeViewType.list => Icons.view_list_outlined,
      KnowledgeViewType.gallery => Icons.grid_view_outlined,
      KnowledgeViewType.board => Icons.view_kanban_outlined,
      KnowledgeViewType.calendar => Icons.calendar_month_outlined,
      KnowledgeViewType.timeline => Icons.timeline_rounded,
    };

class _EmptyInspectorText extends StatelessWidget {
  const _EmptyInspectorText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 9, bottom: 4),
        child: Text(text,
            style: const TextStyle(color: Color(0xFF7A746D), fontSize: 12.5)),
      );
}
