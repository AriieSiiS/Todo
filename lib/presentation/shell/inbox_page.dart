part of 'app_shell.dart';

enum _InboxSort { manual, newest, oldest }

enum _InboxViewMode { list, grid }

class InboxPage extends StatefulWidget {
  const InboxPage({required this.controller, super.key});

  final TodoWorkspace controller;

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  late final TextEditingController _searchController;
  String _query = '';
  String? _selectedNoteId;
  String? _editingNoteId;
  String? _selectedCategoryId;
  _InboxSort _sort = _InboxSort.manual;
  _InboxViewMode _viewMode = _InboxViewMode.list;

  TodoWorkspace get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = controller.inboxNotes();
    final filteredNotes = notes.where((note) {
      if (_selectedCategoryId != null &&
          !note.categoryIds.contains(_selectedCategoryId)) {
        return false;
      }
      if (_query.trim().isEmpty) {
        return true;
      }
      return note.content.toLowerCase().contains(_query.trim().toLowerCase());
    }).toList();
    if (_sort != _InboxSort.manual) {
      filteredNotes.sort(
        (left, right) {
          if (left.isPinned != right.isPinned) return left.isPinned ? -1 : 1;
          return _sort == _InboxSort.newest
              ? right.effectiveUpdatedAt.compareTo(left.effectiveUpdatedAt)
              : left.effectiveUpdatedAt.compareTo(right.effectiveUpdatedAt);
        },
      );
    }
    final selectedNote = _resolveSelectedNote(filteredNotes);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InboxHeader(
            noteCount: notes.length,
            onCreate: () async {
              await showQuickNoteComposer(context, controller);
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 18),
          _InboxToolbar(
            searchController: _searchController,
            categories: controller.categories
                .where((category) => category.active)
                .toList(),
            selectedCategoryId: _selectedCategoryId,
            sort: _sort,
            viewMode: _viewMode,
            onSearchChanged: (value) => setState(() => _query = value),
            onCategoryChanged: (value) =>
                setState(() => _selectedCategoryId = value),
            onSortChanged: (value) => setState(() => _sort = value),
            onViewChanged: (value) => setState(() => _viewMode = value),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showDetail = constraints.maxWidth >= 980;
                final list = _InboxNotesList(
                  notes: filteredNotes,
                  categories: controller.categories,
                  viewMode: _viewMode,
                  selectedNoteId: showDetail ? selectedNote?.id : null,
                  onSelect: showDetail ? _selectNote : _editNoteInDialog,
                  onOpen: showDetail ? _startEditingNote : _editNoteInDialog,
                  onCreateTask: _createTaskFromNote,
                  onCreateProject: _createProjectFromNote,
                  onCreateEvent: _createEventFromNote,
                  onArchive: _archiveNote,
                  onDelete: _deleteNote,
                  onTogglePin: _togglePinned,
                  onDragStarted: (note) =>
                      setState(() => _selectedNoteId ??= selectedNote?.id),
                  onReorder: (ids) {
                    controller.reorderNotes(ids);
                    setState(() => _sort = _InboxSort.manual);
                  },
                );
                if (!showDetail) return list;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: constraints.maxWidth * 0.43, child: list),
                    const SizedBox(width: 16),
                    Expanded(
                      child: selectedNote != null &&
                              _editingNoteId == selectedNote.id
                          ? _InboxNoteInlineEditor(
                              key: ValueKey(
                                'editorNotaEnPanel-${selectedNote.id}',
                              ),
                              controller: controller,
                              note: selectedNote,
                              onCancel: _stopEditingNote,
                              onSaved: _finishEditingNote,
                            )
                          : _InboxNoteDetail(
                              note: selectedNote,
                              categories: controller.categories,
                              onBodyChanged: _updateNoteBody,
                              onEdit: _startEditingNote,
                              onEditCategories: _editNoteCategories,
                              onCreateTask: _createTaskFromNote,
                              onCreateProject: _createProjectFromNote,
                              onCreateEvent: _createEventFromNote,
                              onArchive: _archiveNote,
                              onDelete: _deleteNote,
                              onTogglePin: _togglePinned,
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  QuickNote? _resolveSelectedNote(List<QuickNote> notes) {
    if (notes.isEmpty) return null;
    for (final note in notes) {
      if (note.id == _selectedNoteId) return note;
    }
    return notes.first;
  }

  void _selectNote(QuickNote note) {
    setState(() {
      _selectedNoteId = note.id;
      if (_editingNoteId != note.id) _editingNoteId = null;
    });
  }

  Future<void> _startEditingNote(QuickNote note) async {
    setState(() {
      _selectedNoteId = note.id;
      _editingNoteId = note.id;
    });
  }

  void _stopEditingNote() {
    setState(() => _editingNoteId = null);
  }

  void _finishEditingNote() {
    setState(() => _editingNoteId = null);
  }

  void _updateNoteBody(QuickNote note, String body) {
    final current = controller.noteById(note.id);
    if (current == null) return;
    final title = _splitNoteContent(current.content).title;
    final normalizedBody = body.trim();
    final content = normalizedBody.isEmpty ? title : '$title\n$normalizedBody';
    if (content == current.content) return;
    controller.updateNote(
      current.id,
      content: content,
      scheduledFor: current.scheduledFor,
    );
  }

  Future<void> _editNoteInDialog(QuickNote note) async {
    await showQuickNoteComposer(context, controller, initialNote: note);
    if (mounted) setState(() {});
  }

  Future<void> _createTaskFromNote(QuickNote note) {
    return showTaskEditor(
      context,
      controller,
      initialTitle: _noteTitleFromContent(note.content),
      initialDescription: _noteDescriptionFromContent(note.content),
      initialDateOverride: note.scheduledFor,
    );
  }

  Future<void> _createProjectFromNote(QuickNote note) {
    return showProjectEditor(
      context,
      controller,
      initialName: _noteTitleFromContent(note.content),
      initialDescription: _noteDescriptionFromContent(note.content),
    );
  }

  Future<void> _createEventFromNote(QuickNote note) async {
    final base = note.scheduledFor ?? controller.logicalDate();
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: base.subtract(const Duration(days: 365)),
      lastDate: base.add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    controller.convertNoteToCalendarEvent(
      note.id,
      startAt: DateTime(picked.year, picked.month, picked.day, 10),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Evento creado. La nota sigue en Notas.')),
    );
  }

  Future<void> _archiveNote(QuickNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archivar nota'),
        content: const Text('La nota dejará de aparecer en Notas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    controller.archiveNote(note.id);
    setState(() {
      if (_selectedNoteId == note.id) _selectedNoteId = null;
      if (_editingNoteId == note.id) _editingNoteId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Nota archivada.'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => controller.restoreNote(note.id),
        ),
      ),
    );
  }

  Future<void> _deleteNote(QuickNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar nota'),
        content: const Text('Esta nota se eliminará definitivamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    controller.deleteNote(note.id);
    setState(() {
      if (_selectedNoteId == note.id) _selectedNoteId = null;
      if (_editingNoteId == note.id) _editingNoteId = null;
    });
  }

  Future<void> _togglePinned(QuickNote note) async {
    controller.toggleNotePinned(note.id);
    if (mounted) setState(() {});
  }

  Future<void> _editNoteCategories(QuickNote note) async {
    final categories =
        controller.categories.where((category) => category.active).toList();
    final draft = note.categoryIds.toSet();
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Categorías de la nota'),
          content: SizedBox(
            width: 480,
            child: categories.isEmpty
                ? const Text(
                    'Todavía no hay categorías activas. Puedes crearlas desde la sección Categorías.',
                  )
                : Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final category in categories)
                        FilterChip(
                          selected: draft.contains(category.id),
                          avatar: Icon(category.icon, size: 17),
                          label: Text(category.name),
                          selectedColor: category.color.withValues(alpha: 0.22),
                          checkmarkColor: category.color,
                          onSelected: (value) => setDialogState(() {
                            if (value) {
                              draft.add(category.id);
                            } else {
                              draft.remove(category.id);
                            }
                          }),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(draft),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    controller.updateNote(
      note.id,
      content: note.content,
      scheduledFor: note.scheduledFor,
      emoji: note.emoji,
      colorValue: note.colorValue,
      clearColor: note.colorValue == null,
      isPinned: note.isPinned,
      categoryIds: selected.toList(),
    );
    setState(() {});
  }
}

class _InboxHeader extends StatelessWidget {
  const _InboxHeader({required this.noteCount, required this.onCreate});

  final int noteCount;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return LayoutBuilder(
      builder: (context, constraints) {
        final showQuote = constraints.maxWidth >= 880;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notas',
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(fontSize: 40, height: 1),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '$noteCount ${noteCount == 1 ? 'nota' : 'notas'}',
                    style: TextStyle(color: visuals.textMuted),
                  ),
                ],
              ),
            ),
            if (showQuote) ...[
              Container(
                width: 1,
                height: 50,
                color: visuals.panelBorder,
              ),
              const SizedBox(width: 22),
              SizedBox(
                width: 250,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '“Las grandes ideas empiezan\ncon una nota.”',
                      style: TextStyle(
                        color: visuals.textMuted,
                        fontSize: 13.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 34,
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFF607A5A),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(width: 20),
            _HeaderActionButton(
              label: 'Nueva nota',
              icon: Icons.add_rounded,
              onPressed: onCreate,
            ),
          ],
        );
      },
    );
  }
}

class _InboxToolbar extends StatelessWidget {
  const _InboxToolbar({
    required this.searchController,
    required this.categories,
    required this.selectedCategoryId,
    required this.sort,
    required this.viewMode,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onSortChanged,
    required this.onViewChanged,
  });

  final TextEditingController searchController;
  final List<CategoryModel> categories;
  final String? selectedCategoryId;
  final _InboxSort sort;
  final _InboxViewMode viewMode;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<_InboxSort> onSortChanged;
  final ValueChanged<_InboxViewMode> onViewChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1040;
        final search = _CatalogSearchField(
          key: const ValueKey('inbox-search'),
          controller: searchController,
          onChanged: onSearchChanged,
          label: 'Buscar en notas',
          hint: 'Buscar en notas…',
        );
        final controls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InboxCategoryFilter(
              categories: categories,
              selectedCategoryId: selectedCategoryId,
              onChanged: onCategoryChanged,
            ),
            const SizedBox(width: 10),
            _InboxSortButton(value: sort, onChanged: onSortChanged),
            const SizedBox(width: 10),
            _InboxViewToggle(value: viewMode, onChanged: onViewChanged),
          ],
        );
        if (compact) {
          return Column(
            children: [
              search,
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: controls),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: 12),
            controls,
          ],
        );
      },
    );
  }
}

class _InboxCategoryFilter extends StatelessWidget {
  const _InboxCategoryFilter({
    required this.categories,
    required this.selectedCategoryId,
    required this.onChanged,
  });

  final List<CategoryModel> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = categories.cast<CategoryModel?>().firstWhere(
          (category) => category?.id == selectedCategoryId,
          orElse: () => null,
        );
    return PopupMenuButton<String>(
      tooltip: 'Filtrar por categoría',
      initialValue: selectedCategoryId ?? '',
      onSelected: (value) => onChanged(value.isEmpty ? null : value),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: '',
          child: Text('Todas las categorías'),
        ),
        for (final category in categories)
          PopupMenuItem(
            value: category.id,
            child: Row(
              children: [
                Icon(category.icon, size: 18, color: category.color),
                const SizedBox(width: 9),
                Text(category.name),
              ],
            ),
          ),
      ],
      child: _InboxToolbarButton(
        icon: Icons.sell_outlined,
        label: selected?.name ?? 'Todas las categorías',
        trailing: Icons.keyboard_arrow_down_rounded,
      ),
    );
  }
}

class _InboxViewToggle extends StatelessWidget {
  const _InboxViewToggle({required this.value, required this.onChanged});

  final _InboxViewMode value;
  final ValueChanged<_InboxViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: context.visuals.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3D7C8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _InboxViewButton(
            icon: Icons.format_list_bulleted_rounded,
            tooltip: 'Vista de lista',
            selected: value == _InboxViewMode.list,
            onPressed: () => onChanged(_InboxViewMode.list),
          ),
          _InboxViewButton(
            icon: Icons.grid_view_rounded,
            tooltip: 'Vista de cuadrícula',
            selected: value == _InboxViewMode.grid,
            onPressed: () => onChanged(_InboxViewMode.grid),
          ),
        ],
      ),
    );
  }
}

class _InboxViewButton extends StatelessWidget {
  const _InboxViewButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 42,
          height: 46,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE8F0E3) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color:
                selected ? const Color(0xFF3F5B3B) : context.visuals.textMuted,
          ),
        ),
      ),
    );
  }
}

class _InboxToolbarButton extends StatelessWidget {
  const _InboxToolbarButton({
    required this.icon,
    required this.label,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      constraints: const BoxConstraints(minWidth: 178, maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.visuals.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3D7C8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Icon(trailing, size: 20),
          ],
        ],
      ),
    );
  }
}

class _InboxSortButton extends StatelessWidget {
  const _InboxSortButton({required this.value, required this.onChanged});

  final _InboxSort value;
  final ValueChanged<_InboxSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_InboxSort>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (context) => const [
        PopupMenuItem(value: _InboxSort.manual, child: Text('Orden manual')),
        PopupMenuItem(
          value: _InboxSort.newest,
          child: Text('Última edición'),
        ),
        PopupMenuItem(
          value: _InboxSort.oldest,
          child: Text('Más antiguas'),
        ),
      ],
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: context.visuals.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3D7C8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 20),
            const SizedBox(width: 10),
            Text(
              switch (value) {
                _InboxSort.manual => 'Orden manual',
                _InboxSort.newest => 'Última edición',
                _InboxSort.oldest => 'Más antiguas',
              },
            ),
            const SizedBox(width: 10),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _InboxNotesList extends StatelessWidget {
  const _InboxNotesList({
    required this.notes,
    required this.categories,
    required this.viewMode,
    required this.selectedNoteId,
    required this.onSelect,
    required this.onOpen,
    required this.onCreateTask,
    required this.onCreateProject,
    required this.onCreateEvent,
    required this.onArchive,
    required this.onDelete,
    required this.onTogglePin,
    required this.onDragStarted,
    required this.onReorder,
  });

  final List<QuickNote> notes;
  final List<CategoryModel> categories;
  final _InboxViewMode viewMode;
  final String? selectedNoteId;
  final void Function(QuickNote) onSelect;
  final Future<void> Function(QuickNote) onOpen;
  final Future<void> Function(QuickNote) onCreateTask;
  final Future<void> Function(QuickNote) onCreateProject;
  final Future<void> Function(QuickNote) onCreateEvent;
  final Future<void> Function(QuickNote) onArchive;
  final Future<void> Function(QuickNote) onDelete;
  final Future<void> Function(QuickNote) onTogglePin;
  final ValueChanged<QuickNote> onDragStarted;
  final ValueChanged<List<String>> onReorder;

  void _reorderGroup(List<QuickNote> group, int source, int destination) {
    if (destination > source) destination--;
    if (source == destination) return;
    final ordered = group.map((note) => note.id).toList();
    ordered.insert(destination, ordered.removeAt(source));
    onReorder(ordered);
  }

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    if (notes.isEmpty) {
      return _SurfaceCard(
        child: Center(
          child: Text(
            'Todavía no has guardado ninguna nota.',
            style: TextStyle(color: visuals.textMuted),
          ),
        ),
      );
    }
    final pinned = notes.where((note) => note.isPinned).toList();
    final regular = notes.where((note) => !note.isPinned).toList();
    if (viewMode == _InboxViewMode.grid) {
      return _buildGrid(context);
    }
    return CustomScrollView(
      key: const ValueKey('lista-notas-arrastrable'),
      slivers: [
        for (final group in [pinned, regular])
          if (group.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 10),
                child: Row(children: [
                  Icon(
                      group.first.isPinned
                          ? Icons.push_pin_rounded
                          : Icons.notes_rounded,
                      size: 18,
                      color: const Color(0xFF31472F)),
                  const SizedBox(width: 8),
                  Text(group.first.isPinned ? 'Fijadas' : 'Todas',
                      style: TextStyle(
                          color: visuals.textStrong,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  Text('${group.length}',
                      style: TextStyle(color: visuals.textMuted)),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(right: 14, bottom: 4),
              sliver: SliverReorderableList(
                itemCount: group.length,
                onReorderStart: (index) => onDragStarted(group[index]),
                onReorder: (source, destination) =>
                    _reorderGroup(group, source, destination),
                proxyDecorator: (child, index, animation) => Material(
                  color: Colors.transparent,
                  child: ScaleTransition(
                    scale:
                        Tween<double>(begin: 1, end: 1.02).animate(animation),
                    child: child,
                  ),
                ),
                itemBuilder: (context, index) => Padding(
                  key: ValueKey('nota-${group[index].id}'),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildListCard(
                      context,
                      group[index],
                      ReorderableDragStartListener(
                        key: ValueKey('arrastrar-nota-${group[index].id}'),
                        index: index,
                        child: const _InboxDragHandle(),
                      )),
                ),
              ),
            ),
          ],
      ],
    );
  }

  Widget _buildListCard(
      BuildContext context, QuickNote note, Widget dragHandle) {
    final visuals = context.visuals;
    final parts = _splitNoteContent(note.content);
    final selected = selectedNoteId == note.id;
    final noteCategories = categories
        .where((category) => note.categoryIds.contains(category.id))
        .take(3)
        .toList();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (details) => _showActions(
        context,
        details.globalPosition,
        note,
      ),
      onLongPressStart: (details) => _showActions(
        context,
        details.globalPosition,
        note,
      ),
      child: Material(
        color: selected ? const Color(0xFFF2F6ED) : visuals.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? const Color(0xFF90A884) : const Color(0xFFE3D7C8),
            width: selected ? 1.4 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onSelect(note),
          onDoubleTap: () => onOpen(note),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFDDE9D2)
                        : const Color(0xFFF5F0E8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: note.emoji.isNotEmpty
                      ? Center(
                          child: Text(
                            note.emoji,
                            style: const TextStyle(fontSize: 21),
                          ),
                        )
                      : Icon(
                          Icons.description_outlined,
                          size: 21,
                          color: selected
                              ? const Color(0xFF506A49)
                              : visuals.textMuted,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              parts.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: visuals.textStrong,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (note.isPinned) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.push_pin_rounded,
                              size: 16,
                              color: Color(0xFF607A5A),
                            ),
                          ],
                        ],
                      ),
                      if (parts.body != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          _collapseNoteText(parts.body!),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: visuals.textMuted,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (noteCategories.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final category in noteCategories)
                              _InboxCategoryChip(category: category),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatInboxCreatedAt(note.effectiveUpdatedAt),
                      style: TextStyle(
                        color: visuals.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      dragHandle,
                      PopupMenuButton<String>(
                        tooltip: 'Opciones de la nota',
                        icon: const Icon(Icons.more_horiz_rounded, size: 20),
                        itemBuilder: (_) => _inboxActionItems(note),
                        onSelected: (action) => _runAction(action, note),
                      ),
                    ]),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 540 ? 2 : 1;
        return _AnimatedCatalogGrid<QuickNote>(
          itemId: (note) => note.id,
          groupKey: (note) => note.isPinned,
          dragHandle: const _InboxDragHandle(),
          keyPrefix: 'nota',
          items: [
            ...notes.where((note) => note.isPinned),
            ...notes.where((note) => !note.isPinned)
          ],
          columns: columns,
          onDragStarted: onDragStarted,
          onReorder: onReorder,
          cardBuilder: (note, dragHandle) => _InboxNoteGridCard(
            note: note,
            categories: categories,
            selected: selectedNoteId == note.id,
            onSelect: onSelect,
            onOpen: onOpen,
            onAction: _runAction,
            dragHandle: dragHandle,
          ),
        );
      },
    );
  }

  Future<void> _showActions(
    BuildContext context,
    Offset position,
    QuickNote note,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: _inboxActionItems(note),
    );
    await _runAction(selected, note);
  }

  Future<void> _runAction(String? selected, QuickNote note) async {
    switch (selected) {
      case 'edit':
        await onOpen(note);
        return;
      case 'pin':
        await onTogglePin(note);
        return;
      case 'task':
        await onCreateTask(note);
        return;
      case 'project':
        await onCreateProject(note);
        return;
      case 'event':
        await onCreateEvent(note);
        return;
      case 'archive':
        await onArchive(note);
        return;
      case 'delete':
        await onDelete(note);
        return;
      case null:
        return;
    }
  }
}

class _InboxDragHandle extends StatelessWidget {
  const _InboxDragHandle();

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Arrastrar nota',
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(Icons.drag_indicator_rounded,
                size: 18, color: context.visuals.textMuted),
          ),
        ),
      );
}

class _InboxNoteGridCard extends StatelessWidget {
  const _InboxNoteGridCard({
    required this.note,
    required this.categories,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
    required this.onAction,
    required this.dragHandle,
  });

  final QuickNote note;
  final List<CategoryModel> categories;
  final bool selected;
  final void Function(QuickNote) onSelect;
  final Future<void> Function(QuickNote) onOpen;
  final Future<void> Function(String?, QuickNote) onAction;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final parts = _splitNoteContent(note.content);
    final noteCategories = categories
        .where((category) => note.categoryIds.contains(category.id))
        .take(2)
        .toList();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (details) => _showActions(
        context,
        details.globalPosition,
      ),
      child: Material(
        color: selected ? const Color(0xFFF2F6ED) : visuals.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? const Color(0xFF90A884) : const Color(0xFFE3D7C8),
            width: selected ? 1.4 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onSelect(note),
          onDoubleTap: () => onOpen(note),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 10, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F0E8),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: note.emoji.isEmpty
                          ? const Icon(Icons.description_outlined, size: 19)
                          : Text(note.emoji,
                              style: const TextStyle(fontSize: 19)),
                    ),
                    const Spacer(),
                    if (note.isPinned)
                      const Icon(
                        Icons.push_pin_rounded,
                        size: 16,
                        color: Color(0xFF607A5A),
                      ),
                    dragHandle,
                    PopupMenuButton<String>(
                      tooltip: 'Opciones de la nota',
                      icon: const Icon(Icons.more_horiz_rounded, size: 20),
                      itemBuilder: (_) => _inboxActionItems(note),
                      onSelected: (action) => onAction(action, note),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  parts.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: visuals.textStrong,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: Text(
                    parts.body == null
                        ? 'Sin contenido adicional.'
                        : _collapseNoteText(parts.body!),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: visuals.textMuted,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 5,
                        children: [
                          for (final category in noteCategories)
                            _InboxCategoryChip(
                              category: category,
                              compact: true,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatInboxCreatedAt(note.effectiveUpdatedAt),
                      style: TextStyle(color: visuals.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context, Offset position) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selectedAction = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: _inboxActionItems(note),
    );
    await onAction(selectedAction, note);
  }
}

class _InboxCategoryChip extends StatelessWidget {
  const _InboxCategoryChip({required this.category, this.compact = false});

  final CategoryModel category;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: category.color.withValues(alpha: 0.16)),
      ),
      child: Text(
        category.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Color.lerp(category.color, Colors.black, 0.30),
          fontSize: compact ? 10.5 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InboxNoteInlineEditor extends StatefulWidget {
  const _InboxNoteInlineEditor({
    required this.controller,
    required this.note,
    required this.onCancel,
    required this.onSaved,
    super.key,
  });

  final TodoWorkspace controller;
  final QuickNote note;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  @override
  State<_InboxNoteInlineEditor> createState() => _InboxNoteInlineEditorState();
}

class _InboxNoteInlineEditorState extends State<_InboxNoteInlineEditor> {
  static const _emojis = <String>[
    '💡',
    '📌',
    '📝',
    '🎯',
    '✨',
    '❤️',
    '🏠',
    '🎬',
    '📚',
    '💻',
    '🛒',
    '🌱',
  ];

  late final TextEditingController _titleController;
  late final EditorState _editorState;
  late String _emoji;
  late bool _isPinned;
  late List<String> _categoryIds;

  @override
  void initState() {
    super.initState();
    final parts = _splitNoteContent(widget.note.content);
    _titleController = TextEditingController(text: parts.title);
    final body = parts.body ?? '';
    _editorState = body.trim().isEmpty
        ? EditorState.blank()
        : EditorState(
            document: markdownToDocument(_normalizeNoteMarkdown(body)));
    _editorState.logConfiguration.level = AppFlowyEditorLogLevel.off;
    _emoji = widget.note.emoji;
    _isPinned = widget.note.isPinned;
    _categoryIds = List<String>.from(widget.note.categoryIds);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _editorState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.edit_note_rounded,
                size: 19,
                color: Color(0xFF607A5A),
              ),
              const SizedBox(width: 8),
              const Text(
                'Editando nota',
                style: TextStyle(
                  color: Color(0xFF607A5A),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                key: const ValueKey('cancelarEdicionNotaSuperior'),
                tooltip: 'Cancelar edición',
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              PopupMenuButton<String>(
                tooltip: 'Elegir emoji',
                onSelected: (value) => setState(() {
                  _emoji = value == 'none' ? '' : value;
                }),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'none',
                    child: Text('Sin emoji'),
                  ),
                  for (final emoji in _emojis)
                    PopupMenuItem(
                      value: emoji,
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                ],
                child: Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F0E8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2D5C4)),
                  ),
                  child: Text(
                    _emoji.isEmpty ? '＋' : _emoji,
                    style: const TextStyle(fontSize: 23),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const ValueKey('tituloNotaEnPanel'),
                  controller: _titleController,
                  autofocus: true,
                  maxLines: 2,
                  minLines: 1,
                  style: const TextStyle(
                    fontSize: 25,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Título de la nota',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: _isPinned ? 'Desfijar nota' : 'Fijar nota',
                onPressed: () => setState(() => _isPinned = !_isPinned),
                icon: Icon(
                  _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Categorías',
                style: TextStyle(color: visuals.textMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in widget.controller.categories.where(
                      (category) => _categoryIds.contains(category.id),
                    ))
                      InputChip(
                        label: Text(category.name),
                        avatar: Icon(category.icon, size: 16),
                        backgroundColor: category.color.withValues(alpha: 0.16),
                        side: BorderSide(
                          color: category.color.withValues(alpha: 0.38),
                        ),
                        onDeleted: () => setState(
                          () => _categoryIds.remove(category.id),
                        ),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 17),
                      label: const Text('Añadir categoría'),
                      onPressed: _pickCategories,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NoteFormattingToolbar(editorState: _editorState),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF8),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2D5C4)),
              ),
              clipBehavior: Clip.antiAlias,
              child: AppFlowyEditor(
                key: const ValueKey('contenidoNotaEnPanel'),
                editorState: _editorState,
                editable: true,
                blockComponentBuilders: _compactNoteBlockComponentBuilders,
                commandShortcutEvents: standardCommandShortcutEvents,
                characterShortcutEvents: _noteCharacterShortcutEvents,
                editorStyle: EditorStyle.desktop(
                  padding: const EdgeInsets.all(18),
                  cursorColor: const Color(0xFF607A4D),
                  selectionColor: const Color(0xFFD8E4CF),
                  textStyleConfiguration: const TextStyleConfiguration(
                    text: TextStyle(
                      fontSize: 16,
                      height: 1.15,
                      color: Color(0xFF2D2A25),
                    ),
                    lineHeight: 1.15,
                    bold: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                key: const ValueKey('cancelarEdicionNota'),
                onPressed: widget.onCancel,
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                key: const ValueKey('guardarEdicionNota'),
                onPressed: _save,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Guardar cambios'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _save() {
    final title = _titleController.text.trim();
    final body = documentToMarkdown(_editorState.document).trim();
    if (title.isEmpty && body.isEmpty) return;
    final resolvedTitle = title.isEmpty ? 'Sin título' : title;
    final content = body.isEmpty ? resolvedTitle : '$resolvedTitle\n$body';
    widget.controller.updateNote(
      widget.note.id,
      content: content,
      scheduledFor: widget.note.scheduledFor,
      emoji: _emoji,
      isPinned: _isPinned,
      categoryIds: _categoryIds,
    );
    widget.onSaved();
  }

  Future<void> _pickCategories() async {
    final categories = widget.controller.categories
        .where((category) => category.active)
        .toList();
    final draft = _categoryIds.toSet();
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Categorías de la nota'),
          content: SizedBox(
            width: 480,
            child: categories.isEmpty
                ? const Text(
                    'Todavía no hay categorías activas. Puedes crearlas desde la sección Categorías.',
                  )
                : Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final category in categories)
                        FilterChip(
                          selected: draft.contains(category.id),
                          avatar: Icon(category.icon, size: 17),
                          label: Text(category.name),
                          selectedColor: category.color.withValues(alpha: 0.22),
                          checkmarkColor: category.color,
                          onSelected: (value) => setDialogState(() {
                            if (value) {
                              draft.add(category.id);
                            } else {
                              draft.remove(category.id);
                            }
                          }),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(draft),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _categoryIds = selected.toList());
  }
}

class _InboxNoteDetail extends StatelessWidget {
  const _InboxNoteDetail({
    required this.note,
    required this.categories,
    required this.onBodyChanged,
    required this.onEdit,
    required this.onEditCategories,
    required this.onCreateTask,
    required this.onCreateProject,
    required this.onCreateEvent,
    required this.onArchive,
    required this.onDelete,
    required this.onTogglePin,
  });

  final QuickNote? note;
  final List<CategoryModel> categories;
  final void Function(QuickNote, String) onBodyChanged;
  final Future<void> Function(QuickNote) onEdit;
  final Future<void> Function(QuickNote) onEditCategories;
  final Future<void> Function(QuickNote) onCreateTask;
  final Future<void> Function(QuickNote) onCreateProject;
  final Future<void> Function(QuickNote) onCreateEvent;
  final Future<void> Function(QuickNote) onArchive;
  final Future<void> Function(QuickNote) onDelete;
  final Future<void> Function(QuickNote) onTogglePin;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final selected = note;
    if (selected == null) {
      return _SurfaceCard(
        child: Center(
          child: Text(
            'Selecciona una nota para verla.',
            style: TextStyle(color: visuals.textMuted),
          ),
        ),
      );
    }
    final parts = _splitNoteContent(selected.content);
    final noteCategories = categories
        .where((category) => selected.categoryIds.contains(category.id))
        .toList();
    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                selected.isPinned
                    ? Icons.push_pin_rounded
                    : Icons.description_outlined,
                size: 17,
                color: selected.isPinned
                    ? const Color(0xFFC77B30)
                    : const Color(0xFF607A5A),
              ),
              const SizedBox(width: 8),
              Text(
                selected.isPinned ? 'Nota fijada' : 'Nota',
                style: TextStyle(
                  color: selected.isPinned
                      ? const Color(0xFF9A5C22)
                      : const Color(0xFF607A5A),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: 'Opciones de la nota',
                icon: const Icon(Icons.more_horiz_rounded),
                itemBuilder: (_) => _inboxActionItems(selected),
                onSelected: (action) => _runAction(action, selected),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  parts.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 30,
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatInboxCreatedAt(selected.effectiveUpdatedAt),
                    style: TextStyle(
                      color: visuals.textStrong,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Última edición',
                    style: TextStyle(color: visuals.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final category in noteCategories)
                _InboxCategoryChip(category: category),
              Tooltip(
                message: 'Añadir categoría',
                child: InkWell(
                  onTap: () => onEditCategories(selected),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF2F0EC),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_rounded, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Divider(height: 1),
          const SizedBox(height: 22),
          Expanded(
            child: _InboxDirectNoteEditor(
              key: ValueKey('escrituraDirectaNota-${selected.id}'),
              markdown: parts.body ?? '',
              onChanged: (body) => onBodyChanged(selected, body),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => onEdit(selected),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar nota'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => onArchive(selected),
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('Archivar'),
              ),
              TextButton.icon(
                onPressed: () => onDelete(selected),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Eliminar'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF9A4E43),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _runAction(String? action, QuickNote selected) async {
    switch (action) {
      case 'edit':
        await onEdit(selected);
        return;
      case 'pin':
        await onTogglePin(selected);
        return;
      case 'task':
        await onCreateTask(selected);
        return;
      case 'project':
        await onCreateProject(selected);
        return;
      case 'event':
        await onCreateEvent(selected);
        return;
      case 'archive':
        await onArchive(selected);
        return;
      case 'delete':
        await onDelete(selected);
        return;
      case null:
        return;
    }
  }
}

class _InboxDirectNoteEditor extends StatefulWidget {
  const _InboxDirectNoteEditor({
    required this.markdown,
    required this.onChanged,
    super.key,
  });

  final String markdown;
  final ValueChanged<String> onChanged;

  @override
  State<_InboxDirectNoteEditor> createState() => _InboxDirectNoteEditorState();
}

class _InboxDirectNoteEditorState extends State<_InboxDirectNoteEditor> {
  late EditorState _editorState;
  StreamSubscription<EditorTransactionValue>? _transactionSubscription;
  Timer? _saveTimer;
  late String _sourceMarkdown;

  @override
  void initState() {
    super.initState();
    _sourceMarkdown = widget.markdown.trim();
    _createEditorState();
  }

  @override
  void didUpdateWidget(covariant _InboxDirectNoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.markdown.trim();
    if (incoming == _sourceMarkdown) return;
    final current = documentToMarkdown(_editorState.document).trim();
    _sourceMarkdown = incoming;
    if (incoming == current) return;
    _saveTimer?.cancel();
    unawaited(_transactionSubscription?.cancel());
    _editorState.dispose();
    _createEditorState();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveNow();
    unawaited(_transactionSubscription?.cancel());
    _editorState.dispose();
    super.dispose();
  }

  void _createEditorState() {
    _editorState = _sourceMarkdown.isEmpty
        ? EditorState.blank()
        : EditorState(
            document: markdownToDocument(
              _normalizeNoteMarkdown(_sourceMarkdown),
            ),
          );
    _editorState.logConfiguration.level = AppFlowyEditorLogLevel.off;
    _transactionSubscription = _editorState.transactionStream.listen((event) {
      if (event.$1 != TransactionTime.after) return;
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(milliseconds: 500), _saveNow);
    });
  }

  void _saveNow() {
    _saveTimer?.cancel();
    final markdown = documentToMarkdown(_editorState.document).trim();
    if (markdown == _sourceMarkdown) return;
    _sourceMarkdown = markdown;
    widget.onChanged(markdown);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (!hasFocus) _saveNow();
      },
      child: AppFlowyEditor(
        key: const ValueKey('contenidoNotaDirecto'),
        editorState: _editorState,
        editable: true,
        blockComponentBuilders: _directNoteBlockComponentBuilders,
        commandShortcutEvents: standardCommandShortcutEvents,
        characterShortcutEvents: _noteCharacterShortcutEvents,
        editorStyle: EditorStyle.desktop(
          padding: EdgeInsets.zero,
          cursorColor: const Color(0xFF607A4D),
          selectionColor: const Color(0xFFD8E4CF),
          textStyleConfiguration: const TextStyleConfiguration(
            text: TextStyle(
              fontSize: 17,
              height: 1.55,
              color: Color(0xFF2D2A25),
            ),
            bold: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

List<PopupMenuEntry<String>> _inboxActionItems(QuickNote note) => [
      PopupMenuItem(
        value: 'pin',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
          ),
          title: Text(note.isPinned ? 'Desfijar nota' : 'Fijar nota'),
        ),
      ),
      const PopupMenuItem(
        value: 'edit',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.edit_outlined),
          title: Text('Editar nota'),
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'task',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.task_alt_rounded),
          title: Text('Crear una tarea'),
        ),
      ),
      const PopupMenuItem(
        value: 'project',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.folder_open_rounded),
          title: Text('Crear un proyecto'),
        ),
      ),
      const PopupMenuItem(
        value: 'event',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.calendar_month_rounded),
          title: Text('Crear un evento'),
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'archive',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.inventory_2_outlined),
          title: Text('Archivar'),
        ),
      ),
      const PopupMenuItem(
        value: 'delete',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.delete_outline_rounded),
          title: Text('Eliminar'),
        ),
      ),
    ];

class _NoteContentParts {
  const _NoteContentParts(this.title, this.body);

  final String title;
  final String? body;
}

_NoteContentParts _splitNoteContent(String content) {
  final lines = content
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.isEmpty) return const _NoteContentParts('Nota vacía', null);

  var title = lines.first;
  final bodyParts = lines.skip(1).toList();
  if (title.length > 72) {
    var splitAt = title.lastIndexOf(' ', 72);
    if (splitAt < 36) splitAt = 72;
    bodyParts.insert(0, title.substring(splitAt).trim());
    title = title.substring(0, splitAt).trim();
  }
  final body = bodyParts.isEmpty ? null : bodyParts.join('\n\n');
  return _NoteContentParts(title, body);
}

String _normalizeNoteMarkdown(String markdown) => markdown.replaceAllMapped(
      RegExp(r'!\[\]\(([A-Za-z]:\\[^\r\n)]*)\)'),
      (match) => '![](${match.group(1)!.replaceAll('\\', '/')})',
    );

String _collapseNoteText(String content) => content
    .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
    .replaceAll(RegExp(r'^[-*]\s+\[[xX ]\]\s+', multiLine: true), '')
    .replaceAll(RegExp(r'^[-*]\s+', multiLine: true), '')
    .replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '')
    .replaceAll(RegExp(r'\*\*|__|~~|`'), '')
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .join(' ');

String _noteTitleFromContent(String content) {
  return _splitNoteContent(content).title;
}

String? _noteDescriptionFromContent(String content) {
  return _splitNoteContent(content).body;
}

String _formatInboxCreatedAt(DateTime value) {
  final now = DateTime.now();
  if (_sameDay(value, now)) {
    return 'Hoy, ${_timeLabel(value)}';
  }
  if (_sameDay(value, now.subtract(const Duration(days: 1)))) {
    return 'Ayer, ${_timeLabel(value)}';
  }
  return '${_weekdayShort(value)} ${value.day} ${_monthShortInbox(value.month)}';
}

String _formatInboxDate(DateTime value) {
  return '${_weekdayShort(value)} ${value.day} ${_monthShortInbox(value.month)}';
}

String _monthShortInbox(int month) {
  const names = <String>[
    '',
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return names[month];
}
