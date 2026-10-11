part of 'knowledge_workspace_page.dart';

class _KnowledgePageIcon extends StatelessWidget {
  const _KnowledgePageIcon({
    required this.service,
    required this.pageId,
    this.coverAssetId,
    this.icon,
    this.size = 20,
  });

  final KnowledgeService service;
  final String pageId;
  final String? coverAssetId;
  final String? icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final assetId = coverAssetId;
    final asset = assetId == null ? null : service.assetById(assetId);
    final path = asset == null ? '' : service.absoluteAssetPath(asset);
    if (asset?.kind == KnowledgeAssetKind.image &&
        path.isNotEmpty &&
        File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          key: ValueKey('knowledge-page-icon-$pageId'),
          File(path),
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.description_outlined, size: size * .82),
        ),
      );
    }
    final fallbackIcon = icon?.trim();
    if (fallbackIcon != null && fallbackIcon.isNotEmpty) {
      return Text(fallbackIcon, style: TextStyle(fontSize: size * .8));
    }
    return Icon(Icons.description_outlined, size: size * .82);
  }
}

class _KnowledgeTreePanel extends StatefulWidget {
  const _KnowledgeTreePanel({
    required this.service,
    required this.rootPageId,
    required this.activePageId,
    required this.editable,
    required this.onOpen,
    required this.onOpenNewTab,
    required this.onAddChild,
    required this.onAddPage,
    required this.onShowTrash,
    required this.metadataVersion,
  });

  final KnowledgeService service;
  final String rootPageId;
  final String? activePageId;
  final bool editable;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onOpenNewTab;
  final Future<void> Function(String pageId) onAddChild;
  final VoidCallback onAddPage;
  final VoidCallback onShowTrash;
  final ValueListenable<int> metadataVersion;

  @override
  State<_KnowledgeTreePanel> createState() => _KnowledgeTreePanelState();
}

class _KnowledgeTreePanelState extends State<_KnowledgeTreePanel> {
  final TextEditingController _controller = TextEditingController();
  final Set<String> _expanded = <String>{};
  List<KnowledgeSearchResult> _results = const <KnowledgeSearchResult>[];
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _expanded.add(widget.rootPageId);
    _expandActiveAncestors();
    widget.metadataVersion.addListener(_refreshMetadata);
  }

  @override
  void didUpdateWidget(covariant _KnowledgeTreePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metadataVersion != widget.metadataVersion) {
      oldWidget.metadataVersion.removeListener(_refreshMetadata);
      widget.metadataVersion.addListener(_refreshMetadata);
    }
    if (oldWidget.rootPageId != widget.rootPageId) {
      _expanded
        ..clear()
        ..add(widget.rootPageId);
    }
    if (oldWidget.activePageId != widget.activePageId) {
      _expandActiveAncestors();
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    widget.metadataVersion.removeListener(_refreshMetadata);
    _controller.dispose();
    super.dispose();
  }

  void _refreshMetadata() {
    if (mounted) setState(_expandActiveAncestors);
  }

  void _expandActiveAncestors() {
    final activePageId = widget.activePageId;
    if (activePageId == null) return;
    _expanded.addAll(
      widget.service.treeIndex(widget.rootPageId).ancestorsOf(activePageId),
    );
  }

  void _search(String value) {
    _searchTimer?.cancel();
    setState(() {});
    if (value.trim().isEmpty) {
      _results = const <KnowledgeSearchResult>[];
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 220), () {
      final results = widget.service.search(
        value,
        limit: 20,
        rootPageId: widget.rootPageId,
      );
      if (mounted && value == _controller.text) {
        setState(() => _results = results);
      }
    });
  }

  List<_KnowledgeTreeRow> _visibleRows(KnowledgeTreeIndex index) {
    final result = <_KnowledgeTreeRow>[];
    void visit(KnowledgePageOutline page, int depth) {
      result.add(_KnowledgeTreeRow(page: page, depth: depth));
      if (!_expanded.contains(page.id)) return;
      for (final child in index.childrenOf(page.id)) {
        visit(child, depth + 1);
      }
    }

    final root = index.page(widget.rootPageId);
    if (root != null) visit(root, 0);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final searching = _controller.text.trim().isNotEmpty;
    final index = widget.service.treeIndex(widget.rootPageId);
    final rows = searching ? const <_KnowledgeTreeRow>[] : _visibleRows(index);
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
                  onPressed: widget.editable ? widget.onAddPage : null,
                  tooltip: 'Nueva subpágina',
                  icon: const Icon(Icons.add_rounded, size: 20),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _controller,
              onChanged: _search,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Buscar páginas y contenido...',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: searching
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return ListTile(
                        dense: true,
                        leading: _KnowledgePageIcon(
                          service: widget.service,
                          pageId: result.page.id,
                          coverAssetId: result.page.coverAssetId,
                          icon: result.page.icon,
                          size: 22,
                        ),
                        title: Text(result.page.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: result.snippet.isEmpty
                            ? null
                            : Text(result.snippet,
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => widget.onOpenNewTab(result.page.id),
                      );
                    },
                  )
                : ListView.builder(
                    key: const ValueKey('knowledge-virtual-tree'),
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    itemCount: rows.length,
                    itemExtent: 42,
                    itemBuilder: (context, rowIndex) {
                      final row = rows[rowIndex];
                      final page = row.page;
                      final active = widget.activePageId == page.id;
                      return Padding(
                        padding: EdgeInsets.only(left: row.depth * 16.0),
                        child: InkWell(
                          onTap: () => widget.onOpen(page.id),
                          onDoubleTap: () => widget.onOpenNewTab(page.id),
                          borderRadius: BorderRadius.circular(7),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(0xFFDDE8D5)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 26,
                                  child: page.hasChildren
                                      ? IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => setState(() {
                                            if (!_expanded.remove(page.id)) {
                                              _expanded.add(page.id);
                                            }
                                          }),
                                          icon: Icon(
                                            _expanded.contains(page.id)
                                                ? Icons.expand_more_rounded
                                                : Icons.chevron_right_rounded,
                                            size: 18,
                                          ),
                                        )
                                      : _KnowledgePageIcon(
                                          service: widget.service,
                                          pageId: page.id,
                                          coverAssetId: page.coverAssetId,
                                          icon: page.icon,
                                          size: 21,
                                        ),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(page.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                if (widget.editable)
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 28, minHeight: 28),
                                    onPressed: () => widget.onAddChild(page.id),
                                    tooltip: 'Añadir subpágina',
                                    icon:
                                        const Icon(Icons.add_rounded, size: 17),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: const Icon(Icons.delete_outline_rounded, size: 19),
            title: const Text('Papelera'),
            onTap: widget.onShowTrash,
          ),
        ],
      ),
    );
  }
}

class _KnowledgeTreeRow {
  const _KnowledgeTreeRow({required this.page, required this.depth});

  final KnowledgePageOutline page;
  final int depth;
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
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.page.parentId == null || _containsActivePage();
  }

  @override
  void didUpdateWidget(covariant _PageTreeNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activePageId != widget.activePageId &&
        _containsActivePage()) {
      _expanded = true;
    }
  }

  bool _containsActivePage() {
    var current = widget.activePageId == null
        ? null
        : widget.service.pageById(widget.activePageId!);
    while (current != null) {
      if (current.id == widget.page.id) return true;
      current = current.parentId == null
          ? null
          : widget.service.pageById(current.parentId!);
    }
    return false;
  }

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
                      ? _KnowledgePageIcon(
                          service: widget.service,
                          pageId: widget.page.id,
                          coverAssetId: widget.page.coverAssetId,
                          icon: widget.page.icon,
                          size: 21,
                        )
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
