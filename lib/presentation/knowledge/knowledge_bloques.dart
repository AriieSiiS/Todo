part of 'knowledge_workspace_page.dart';

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

class _KnowledgeCharacterBlockBuilder extends BlockComponentBuilder {
  _KnowledgeCharacterBlockBuilder(this.service);

  final KnowledgeService service;

  @override
  BlockComponentWidget build(BlockComponentContext context) =>
      _KnowledgeCharacterBlock(
        key: context.node.key,
        node: context.node,
        configuration: configuration,
        service: service,
      );

  @override
  BlockComponentValidate get validate => (node) => node.children.isEmpty;
}

class _KnowledgeCharacterBlock extends BlockComponentStatefulWidget {
  const _KnowledgeCharacterBlock({
    required super.key,
    required super.node,
    required super.configuration,
    required this.service,
  });

  final KnowledgeService service;

  @override
  State<_KnowledgeCharacterBlock> createState() =>
      _KnowledgeCharacterBlockState();
}

class _KnowledgeCharacterBlockState extends State<_KnowledgeCharacterBlock> {
  StreamSubscription<String>? _subscription;

  String get _rootPageId =>
      widget.node.attributes['knowledgeRootPageId']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _subscription = widget.service.progressChanges.listen((rootPageId) {
      if (mounted && rootPageId == _rootPageId) setState(() {});
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attributes = widget.node.attributes;
    final name =
        attributes['knowledgeCharacterName']?.toString() ?? 'Personaje';
    final progressKey =
        attributes['knowledgeCharacterProgressKey']?.toString() ?? '';
    final unlocked = attributes['knowledgeCharacterInitiallyUnlocked'] ==
            true ||
        widget.service.progressByKey(_rootPageId, progressKey)?.isCompleted ==
            true;
    final stats =
        (attributes['knowledgeCharacterStats'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList();
    final startingItems =
        (attributes['knowledgeCharacterStartingItems'] as List? ??
                const <dynamic>[])
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList();
    final assetId = attributes['knowledgeAssetId']?.toString();
    final asset = assetId == null ? null : widget.service.assetById(assetId);
    final assetPath =
        asset == null ? '' : widget.service.absoluteAssetPath(asset);

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(name,
                  style: const TextStyle(
                      fontSize: 25, fontWeight: FontWeight.w900)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: unlocked
                    ? const Color(0xFFDDECD3)
                    : const Color(0xFFEDE9E2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                unlocked ? 'Desbloqueado' : 'Bloqueado',
                style: TextStyle(
                  color: unlocked
                      ? const Color(0xFF416231)
                      : const Color(0xFF675F55),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          attributes['knowledgeCharacterUnlock']?.toString() ?? '',
          style: const TextStyle(color: Color(0xFF6D655C), height: 1.35),
        ),
        const SizedBox(height: 11),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _characterFactChip(
              Icons.favorite_rounded,
              attributes['knowledgeCharacterHealth']?.toString() ??
                  'Salud especial',
            ),
            for (final stat in stats)
              _characterFactChip(
                Icons.tune_rounded,
                '${stat['label']}: ${stat['value']}',
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            style: const TextStyle(
                color: Color(0xFF403B35), fontSize: 14.5, height: 1.38),
            children: [
              const TextSpan(
                  text: 'Empieza con: ',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(
                  text: startingItems.isEmpty
                      ? 'sin objetos adicionales'
                      : startingItems.join(' · ')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          attributes['knowledgeCharacterStyle']?.toString() ?? '',
          style: const TextStyle(fontSize: 14.5, height: 1.42),
        ),
        const SizedBox(height: 7),
        Text(
          attributes['knowledgeCharacterTip']?.toString() ?? '',
          style: const TextStyle(
            color: Color(0xFF526943),
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
      ],
    );

    return Container(
      key: const ValueKey('knowledge-character-profile'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2DCD2)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final portrait = _characterPortrait(assetPath, name);
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [portrait, const SizedBox(height: 12), details],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              portrait,
              const SizedBox(width: 18),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }

  Widget _characterPortrait(String path, String name) {
    return Container(
      width: 92,
      height: 92,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xFFE7E0CF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC9BFAE)),
      ),
      child: path.isNotEmpty && File(path).existsSync()
          ? Image.file(
              File(path),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
              errorBuilder: (_, __, ___) => _portraitFallback(name),
            )
          : _portraitFallback(name),
    );
  }

  Widget _portraitFallback(String name) => Center(
        child: Text(
          name.isEmpty ? '?' : name.characters.first,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
        ),
      );

  Widget _characterFactChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .78),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE3DDD3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF6B805B)),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _KnowledgeProgressBlockBuilder extends BlockComponentBuilder {
  _KnowledgeProgressBlockBuilder(
    this.service,
    this.onOpen, {
    required this.progressVersion,
  });

  final KnowledgeService service;
  final ValueChanged<String> onOpen;
  final ValueListenable<int> progressVersion;

  @override
  BlockComponentWidget build(BlockComponentContext context) =>
      _KnowledgeProgressBlock(
        key: context.node.key,
        node: context.node,
        configuration: configuration,
        service: service,
        onOpen: onOpen,
        progressVersion: progressVersion,
      );

  @override
  BlockComponentValidate get validate => (node) => node.children.isEmpty;
}

class _KnowledgeProgressBlock extends BlockComponentStatefulWidget {
  const _KnowledgeProgressBlock({
    required super.key,
    required super.node,
    required super.configuration,
    required this.service,
    required this.onOpen,
    required this.progressVersion,
  });

  final KnowledgeService service;
  final ValueChanged<String> onOpen;
  final ValueListenable<int> progressVersion;

  @override
  State<_KnowledgeProgressBlock> createState() =>
      _KnowledgeProgressBlockState();
}

class _KnowledgeProgressBlockState extends State<_KnowledgeProgressBlock> {
  String get _rootPageId =>
      widget.node.attributes['knowledgeRootPageId']?.toString() ?? '';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.progressVersion,
      builder: (context, _, __) {
        final display =
            widget.node.attributes['knowledgeProgressDisplay']?.toString() ??
                'check';
        if (display == 'summary') return _buildSummary();
        if (display == 'marks') return _buildMarks();
        return _buildCheck();
      },
    );
  }

  Widget _buildCheck() {
    final singleKey =
        widget.node.attributes['knowledgeProgressKey']?.toString() ?? '';
    final listedKeys =
        (widget.node.attributes['knowledgeProgressKeys'] as List? ??
                const <dynamic>[])
            .map((value) => value.toString())
            .where((value) => value.isNotEmpty);
    final keys = <String>{
      if (singleKey.isNotEmpty) singleKey,
      ...listedKeys,
    }.toList();
    final entries = keys
        .map((key) => widget.service.progressByKey(_rootPageId, key))
        .toList();
    final minimum = (widget.node.attributes['knowledgeProgressMinimum'] as num?)
        ?.toDouble();
    final checked = keys.isNotEmpty &&
        entries.every((entry) {
          if (minimum == null) return entry?.isCompleted == true;
          final value = entry?.value;
          return value is num && value.toDouble() >= minimum;
        });
    final readOnly =
        widget.node.attributes['knowledgeProgressReadOnly'] == true ||
            entries.any((entry) => entry != null && entry.source != 'manual');
    final targetPageId =
        widget.node.attributes['knowledgeTargetPageId']?.toString();
    final rewardPageId = widget.node.attributes['rewardPageId']?.toString();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 0,
      color: checked ? const Color(0xFFE8F2E1) : const Color(0xFFF8F6F1),
      child: ListTile(
        leading: Checkbox(
          value: checked,
          onChanged: readOnly || keys.isEmpty
              ? null
              : (value) {
                  for (final key in keys) {
                    widget.service.setProgress(
                      rootPageId: _rootPageId,
                      key: key,
                      value: value ?? false,
                    );
                  }
                },
        ),
        title: Text(
          widget.node.attributes['knowledgeProgressLabel']?.toString() ??
              keys.join(', '),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            decoration: checked ? TextDecoration.lineThrough : null,
          ),
        ),
        onTap: targetPageId == null || targetPageId.isEmpty
            ? null
            : () => widget.onOpen(targetPageId),
        trailing: rewardPageId == null || rewardPageId.isEmpty
            ? null
            : TextButton.icon(
                onPressed: () => widget.onOpen(rewardPageId),
                icon: const Icon(Icons.card_giftcard_rounded, size: 17),
                label: const Text('Recompensa'),
              ),
      ),
    );
  }

  Widget _buildSummary() {
    final keys = (widget.node.attributes['knowledgeProgressKeys'] as List? ??
            const <dynamic>[])
        .map((value) => value.toString())
        .toList();
    final completed =
        widget.service.progressSnapshot(_rootPageId).completedCount(keys);
    final ratio = keys.isEmpty ? 0.0 : completed / keys.length;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8EF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7E4CC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.node.attributes['knowledgeProgressLabel']?.toString() ??
                'Progreso',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 9),
          LinearProgressIndicator(value: ratio),
          const SizedBox(height: 7),
          Text('$completed de ${keys.length} completados'),
        ],
      ),
    );
  }

  Widget _buildMarks() {
    final marks =
        (widget.node.attributes['knowledgeCompletionMarks'] as List? ??
                const <dynamic>[])
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8EF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7E4CC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Completion marks',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mark in marks) _markChip(mark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _markChip(Map<String, dynamic> mark) {
    final key = mark['key']?.toString() ?? '';
    final entry = widget.service.progressByKey(_rootPageId, key);
    final difficulty = switch (entry?.value) {
      final num number => number.toInt(),
      true => 1,
      _ => 0,
    };
    final rewardPageId = mark['rewardPageId']?.toString();
    return ActionChip(
      avatar: Icon(
        difficulty >= 2 ? Icons.workspace_premium : Icons.radio_button_checked,
        size: 17,
        color: difficulty >= 2
            ? const Color(0xFF9B312D)
            : difficulty == 1
                ? const Color(0xFF607A4D)
                : Colors.grey,
      ),
      label: Text(mark['label']?.toString() ?? key),
      onPressed: rewardPageId == null || rewardPageId.isEmpty
          ? null
          : () => widget.onOpen(rewardPageId),
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
  static const _pageSize = 48;
  final _searchController = TextEditingController();
  int _page = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
    final allRecords = widget.service.collectionRecords(collectionId);
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? allRecords
        : allRecords.where((record) {
            final haystack =
                '${record['title']} ${jsonEncode(record['properties'])}'
                    .toLowerCase();
            return haystack.contains(query);
          }).toList();
    final pageCount = (filtered.length / _pageSize).ceil().clamp(1, 1 << 20);
    if (_page >= pageCount) _page = pageCount - 1;
    final records = filtered.skip(_page * _pageSize).take(_pageSize).toList();
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
              Text('${filtered.length} páginas'),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Buscar en esta colección',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _page = 0),
          ),
          const SizedBox(height: 12),
          if (records.isEmpty)
            const Padding(
                padding: EdgeInsets.all(12),
                child: Text('La colección está vacía.'))
          else
            _buildRecords(records),
          if (filtered.length > _pageSize)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Página anterior',
                  onPressed: _page == 0 ? null : () => setState(() => _page--),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text('${_page + 1} / $pageCount'),
                IconButton(
                  tooltip: 'Página siguiente',
                  onPressed: _page + 1 >= pageCount
                      ? null
                      : () => setState(() => _page++),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
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
                        _recordThumbnail(record),
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

  Widget _recordThumbnail(Map<String, dynamic> record) {
    final assetId = record['coverAssetId']?.toString();
    final asset = assetId == null ? null : widget.service.assetById(assetId);
    if (asset == null || asset.kind != KnowledgeAssetKind.image) {
      return const Icon(Icons.image_outlined, size: 36);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: _knowledgeImageWidget(
        widget.service.absoluteAssetPath(asset),
        width: 128,
        height: 82,
        cacheWidth: 256,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, __, ___) => const SizedBox(
            height: 82, child: Icon(Icons.broken_image_outlined)),
      ),
    );
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
