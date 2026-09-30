part of 'app_shell.dart';

final _compactNoteBlockConfiguration =
    standardBlockComponentConfiguration.copyWith(
  padding: (_) => EdgeInsets.zero,
);

final _compactNoteBlockComponentBuilders = {
  ...standardBlockComponentBuilderMap,
  ParagraphBlockKeys.type: ParagraphBlockComponentBuilder(
    configuration: _compactNoteBlockConfiguration.copyWith(
      placeholderText: (_) => AppFlowyEditorL10n.current.slashPlaceHolder,
    ),
  ),
  BulletedListBlockKeys.type: BulletedListBlockComponentBuilder(
    configuration: _compactNoteBlockConfiguration,
  ),
  NumberedListBlockKeys.type: NumberedListBlockComponentBuilder(
    configuration: _compactNoteBlockConfiguration,
  ),
};

final _directNoteBlockComponentBuilders = {
  ..._compactNoteBlockComponentBuilders,
  ParagraphBlockKeys.type: ParagraphBlockComponentBuilder(
    configuration: _compactNoteBlockConfiguration.copyWith(
      placeholderText: (_) => 'Escribe aquí…',
    ),
  ),
};

final _noteSelectionMenuItems = [
  ...standardSelectionMenuItems.where(
    (item) => item.name != AppFlowyEditorL10n.current.image,
  ),
  SelectionMenuItem(
    getName: () => 'Imagen',
    icon: (_, isSelected, style) => Icon(
      Icons.image_outlined,
      color: isSelected
          ? style.selectionMenuItemSelectedIconColor
          : style.selectionMenuItemIconColor,
      size: 18,
    ),
    keywords: const ['imagen', 'archivo', 'url', 'portapapeles'],
    handler: (editorState, _, context) {
      unawaited(_showNoteImageSelector(editorState, context));
    },
  ),
];

final _noteCharacterShortcutEvents = [
  ...standardCharacterShortcutEvents.where(
    (event) => event.key != 'show the slash menu',
  ),
  customSlashCommand(_noteSelectionMenuItems),
];

Future<void> _showNoteImageSelector(
  EditorState editorState,
  BuildContext context,
) async {
  final source = await showDialog<String>(
    context: context,
    builder: (_) => const _NoteImageSourceDialog(),
  );
  if (source != null) await editorState.insertImageNode(source);
}

class _NoteImageSourceDialog extends StatefulWidget {
  const _NoteImageSourceDialog();

  @override
  State<_NoteImageSourceDialog> createState() => _NoteImageSourceDialogState();
}

class _NoteImageSourceDialogState extends State<_NoteImageSourceDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _urlController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): () =>
            unawaited(_pasteImage()),
      },
      child: AlertDialog(
        title: const Text('Añadir imagen'),
        content: SizedBox(
          width: 520,
          height: 250,
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Archivo'),
                  Tab(text: 'URL'),
                  Tab(text: 'Portapapeles'),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    Center(
                      child: FilledButton.icon(
                        onPressed: _selectFile,
                        icon: const Icon(Icons.folder_open_rounded),
                        label: const Text('Seleccionar archivo'),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _urlController,
                          autofocus: true,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'Dirección de la imagen',
                            hintText: 'https://…',
                          ),
                          onSubmitted: (_) => _useUrl(),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _useUrl,
                          child: const Text('Usar URL'),
                        ),
                      ],
                    ),
                    Center(
                      child: FilledButton.icon(
                        onPressed: _pasteImage,
                        icon: const Icon(Icons.content_paste_rounded),
                        label: const Text('Pegar imagen'),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectFile() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Imágenes',
          extensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
        ),
      ],
    );
    if (file == null || !mounted) return;
    Navigator.of(context).pop(base64Encode(await file.readAsBytes()));
  }

  void _useUrl() {
    final url = _urlController.text.trim();
    if (Uri.tryParse(url)?.hasScheme != true) {
      setState(() => _error = 'Introduce una dirección web válida.');
      return;
    }
    Navigator.of(context).pop(url);
  }

  Future<void> _pasteImage() async {
    final result = await readClipboardImage();
    if (!mounted) return;
    if (!result.hasImage) {
      setState(() => _error = result.errorMessage);
      return;
    }
    Navigator.of(context).pop(base64Encode(result.bytes!));
  }
}

Future<void> showQuickNoteComposer(
  BuildContext context,
  TodoWorkspace controller, {
  QuickNote? initialNote,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.30),
    builder: (context) => _QuickNoteComposerDialog(
      controller: controller,
      initialNote: initialNote,
    ),
  );
}

class _QuickCaptureBar extends StatelessWidget {
  const _QuickCaptureBar({
    required this.controller,
    this.compact = false,
  });

  final TodoWorkspace controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final action = FilledButton.tonal(
      onPressed: () => showQuickNoteComposer(context, controller),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFF7F1E8),
        foregroundColor: const Color(0xFF243127),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.edit_note_rounded, size: 18),
          const SizedBox(width: 8),
          Text(compact ? 'Escribir nota' : 'Nueva nota'),
        ],
      ),
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Apunta algo rápido y lo revisas después.',
            style: TextStyle(color: visuals.textMuted, height: 1.35),
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: action),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Guarda ideas sueltas, recados o cosas por decidir sin forzarte a clasificarlas ahora.',
          style: TextStyle(color: visuals.textMuted, height: 1.4),
        ),
        const SizedBox(height: 14),
        action,
      ],
    );
  }
}

class _QuickNoteComposerDialog extends StatefulWidget {
  const _QuickNoteComposerDialog({
    required this.controller,
    this.initialNote,
  });

  final TodoWorkspace controller;
  final QuickNote? initialNote;

  @override
  State<_QuickNoteComposerDialog> createState() =>
      _QuickNoteComposerDialogState();
}

class _QuickNoteComposerDialogState extends State<_QuickNoteComposerDialog> {
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
  late EditorState _editorState;
  late String _emoji;
  late bool _isPinned;
  late List<String> _categoryIds;

  bool get _isEditing => widget.initialNote != null;

  @override
  void initState() {
    super.initState();
    final parts = _splitNoteContent(widget.initialNote?.content ?? '');
    _titleController = TextEditingController(
      text: widget.initialNote == null ? '' : parts.title,
    );
    final initialBody = parts.body ?? '';
    _editorState = initialBody.trim().isEmpty
        ? EditorState.blank()
        : EditorState(
            document: markdownToDocument(_normalizeNoteMarkdown(initialBody)),
          );
    _editorState.logConfiguration.level = AppFlowyEditorLogLevel.off;
    _emoji = widget.initialNote?.emoji ?? '';
    _isPinned = widget.initialNote?.isPinned ?? false;
    _categoryIds = List<String>.from(
      widget.initialNote?.categoryIds ?? const <String>[],
    );
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
    final dialogHeight =
        (MediaQuery.sizeOf(context).height - 44).clamp(360.0, 720.0).toDouble();
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.fromLTRB(
        32,
        22,
        32,
        MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: visuals.panel,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFFE2D5C4),
          ),
        ),
        child: SizedBox(
          width: 900,
          height: dialogHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing ? 'Editar nota' : 'Nueva nota',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Escribe libremente. Puedes decidir qué hacer con ella más adelante.',
                            style: TextStyle(color: visuals.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (!_isEditing)
                      PopupMenuButton<String>(
                        tooltip: 'Usar plantilla',
                        onSelected: _aplicarPlantilla,
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'ideas', child: Text('Ideas')),
                          PopupMenuItem(
                              value: 'reunion', child: Text('Reunión')),
                          PopupMenuItem(
                              value: 'compras', child: Text('Compras')),
                          PopupMenuItem(value: 'diario', child: Text('Diario')),
                        ],
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.auto_awesome_outlined, size: 18),
                            SizedBox(width: 6),
                            Text('Plantillas'),
                          ]),
                        ),
                      ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
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
                            child: Text(emoji,
                                style: const TextStyle(fontSize: 24)),
                          ),
                      ],
                      child: Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F0E8),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2D5C4)),
                        ),
                        child: Text(
                          _emoji.isEmpty ? '＋' : _emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _titleController,
                        autofocus: true,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
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
                        _isPinned
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                          for (final category
                              in widget.controller.categories.where(
                            (category) => _categoryIds.contains(category.id),
                          ))
                            InputChip(
                              label: Text(category.name),
                              avatar: Icon(category.icon, size: 16),
                              backgroundColor:
                                  category.color.withValues(alpha: 0.16),
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
                    key: const ValueKey('editorContenidoNota'),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFCF8),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2D5C4)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AppFlowyEditor(
                      key: ObjectKey(_editorState),
                      editorState: _editorState,
                      editable: true,
                      blockComponentBuilders:
                          _compactNoteBlockComponentBuilders,
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
                const SizedBox(height: 22),
                const Divider(height: 1),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label:
                          Text(_isEditing ? 'Guardar cambios' : 'Guardar nota'),
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

  void _save() {
    final title = _titleController.text.trim();
    final body = documentToMarkdown(_editorState.document).trim();
    if (title.isEmpty && body.isEmpty) return;
    final resolvedTitle = title.isEmpty ? 'Sin título' : title;
    final content = body.isEmpty ? resolvedTitle : '$resolvedTitle\n$body';
    if (_isEditing) {
      widget.controller.updateNote(
        widget.initialNote!.id,
        content: content,
        scheduledFor: widget.initialNote!.scheduledFor,
        emoji: _emoji,
        isPinned: _isPinned,
        categoryIds: _categoryIds,
      );
    } else {
      widget.controller.createNote(
        content,
        emoji: _emoji,
        isPinned: _isPinned,
        categoryIds: _categoryIds,
      );
    }
    Navigator.of(context).pop();
  }

  Future<void> _aplicarPlantilla(String tipo) async {
    if (_titleController.text.trim().isNotEmpty ||
        documentToMarkdown(_editorState.document).trim().isNotEmpty) {
      final sustituir = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Aplicar plantilla'),
          content: const Text(
              'La plantilla sustituirá el título y el contenido del borrador.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sustituir')),
          ],
        ),
      );
      if (sustituir != true || !mounted) return;
    }
    final fecha = widget.controller.logicalDate();
    final plantilla = switch (tipo) {
      'reunion' => (
          'Reunión',
          '📝',
          '## Participantes\n\n## Temas\n- \n\n## Acuerdos\n- \n\n## Próximos pasos\n- [ ] '
        ),
      'compras' => (
          'Lista de compra',
          '🛒',
          '## Productos\n- [ ] \n\n## Tiendas\n- \n\n## Presupuesto\n'
        ),
      'diario' => (
          'Diario · ${fecha.day}/${fecha.month}/${fecha.year}',
          '📚',
          '## Cómo me encuentro\n\n## Lo que ha pasado\n\n## Algo que agradezco\n\n## Para mañana\n- '
        ),
      _ => (
          'Ideas',
          '💡',
          '## La idea\n\n## Por qué me interesa\n\n## Qué necesito\n- \n\n## Primer paso\n- [ ] '
        ),
    };
    final anterior = _editorState;
    setState(() {
      _titleController.text = plantilla.$1;
      _emoji = plantilla.$2;
      _editorState = EditorState(document: markdownToDocument(plantilla.$3));
      _editorState.logConfiguration.level = AppFlowyEditorLogLevel.off;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => anterior.dispose());
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

class _NoteFormattingToolbar extends StatelessWidget {
  const _NoteFormattingToolbar({required this.editorState});

  final EditorState editorState;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Selection?>(
      valueListenable: editorState.selectionNotifier,
      builder: (context, selection, _) {
        return Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F0E8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _NoteFormatButton(
                icon: Icons.format_bold_rounded,
                tooltip: 'Negrita',
                active: _isTextStyleActive(
                  selection,
                  AppFlowyRichTextKeys.bold,
                ),
                onPressed: () =>
                    editorState.toggleAttribute(AppFlowyRichTextKeys.bold),
              ),
              _NoteFormatButton(
                icon: Icons.format_italic_rounded,
                tooltip: 'Cursiva',
                active: _isTextStyleActive(
                  selection,
                  AppFlowyRichTextKeys.italic,
                ),
                onPressed: () =>
                    editorState.toggleAttribute(AppFlowyRichTextKeys.italic),
              ),
              const VerticalDivider(indent: 9, endIndent: 9),
              PopupMenuButton<int>(
                tooltip: 'Estilo de texto',
                onSelected: _setHeading,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 0, child: Text('Texto normal')),
                  PopupMenuItem(value: 1, child: Text('Título grande')),
                  PopupMenuItem(value: 2, child: Text('Título mediano')),
                  PopupMenuItem(value: 3, child: Text('Título pequeño')),
                ],
                icon: const Icon(Icons.title_rounded),
              ),
              _NoteFormatButton(
                icon: Icons.check_box_outlined,
                tooltip: 'Lista de tareas',
                onPressed: () => _toggleBlock(TodoListBlockKeys.type),
              ),
              _NoteFormatButton(
                icon: Icons.format_list_bulleted_rounded,
                tooltip: 'Lista con viñetas',
                onPressed: () => _toggleBlock(BulletedListBlockKeys.type),
              ),
              _NoteFormatButton(
                icon: Icons.format_list_numbered_rounded,
                tooltip: 'Lista numerada',
                onPressed: () => _toggleBlock(NumberedListBlockKeys.type),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isTextStyleActive(Selection? selection, String key) {
    if (selection == null) return editorState.toggledStyle.containsKey(key);
    if (selection.isCollapsed) return editorState.toggledStyle.containsKey(key);
    final nodes = editorState.getNodesInSelection(selection);
    return nodes.allSatisfyInSelection(
      selection,
      (delta) => delta.everyAttributes(
        (attributes) => attributes[key] == true,
      ),
    );
  }

  void _setHeading(int level) {
    editorState.formatNode(null, (node) {
      if (level == 0) return node.copyWith(type: ParagraphBlockKeys.type);
      return node.copyWith(
        type: HeadingBlockKeys.type,
        attributes: {...node.attributes, HeadingBlockKeys.level: level},
      );
    });
  }

  void _toggleBlock(String type) {
    editorState.formatNode(null, (node) {
      final nextType = node.type == type ? ParagraphBlockKeys.type : type;
      return node.copyWith(
        type: nextType,
        attributes: {
          ...node.attributes,
          if (nextType == TodoListBlockKeys.type)
            TodoListBlockKeys.checked: false,
        },
      );
    });
  }
}

class _NoteFormatButton extends StatelessWidget {
  const _NoteFormatButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: active ? const Color(0xFFDCE8D3) : Colors.transparent,
        foregroundColor: const Color(0xFF31472F),
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFE5D8C7),
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 20,
            color: Color(0x10000000),
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({
    required this.label,
    this.icon,
    this.color,
  });

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.14) ?? const Color(0xFFF0E7DA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color ?? const Color(0xFF5A5A57)),
            const SizedBox(width: 6),
          ],
          Text(label, style: const TextStyle(letterSpacing: 0)),
        ],
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 154, minHeight: 48),
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: FilledButton.styleFrom(
          minimumSize: const Size(154, 48),
          backgroundColor: const Color(0xFF263625),
          foregroundColor: const Color(0xFFFFFCF8),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _HeaderSecondaryButton extends StatelessWidget {
  const _HeaderSecondaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 154, minHeight: 48),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(154, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          backgroundColor: Colors.white.withValues(alpha: 0.62),
          side: const BorderSide(color: Color(0xFFE8DCCB)),
          foregroundColor: const Color(0xFF2D2A25),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _CatalogSearchField extends StatelessWidget {
  const _CatalogSearchField({
    required this.label,
    required this.hint,
    required this.onChanged,
    this.controller,
    super.key,
  });

  final String label;
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        labelText: label,
        hintText: hint,
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
    this.compact = false,
    this.pinTrailingToEdge = false,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool compact;
  final bool pinTrailingToEdge;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final narrow = MediaQuery.sizeOf(context).width < 760;
    final heading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            title,
            style: compact
                ? Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(fontSize: 40, height: 1)
                : Theme.of(context).textTheme.displaySmall,
          ),
        ),
      ],
    );
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(color: visuals.textMuted)),
          ],
          if (trailing != null) const SizedBox(height: 14),
          if (trailing != null) trailing!,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(color: visuals.textMuted)),
              ],
            ],
          ),
        ),
        if (trailing != null) const SizedBox(width: 12),
        if (trailing != null)
          if (pinTrailingToEdge) trailing! else Flexible(child: trailing!),
      ],
    );
  }
}

class _SectionTabBar extends StatelessWidget {
  const _SectionTabBar({required this.labels, this.onTap});

  final List<String> labels;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return TabBar(
      onTap: onTap,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(
          color: const Color(0xFF70835D),
          width: 2,
        ),
      ),
      labelColor: const Color(0xFF51693E),
      unselectedLabelColor: visuals.textMuted,
      labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      unselectedLabelStyle:
          const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      labelPadding: const EdgeInsets.only(right: 26),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      tabs: [
        for (final label in labels)
          Tab(
              height: 36,
              child:
                  Align(alignment: Alignment.centerLeft, child: Text(label))),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F1DD) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: visuals.pageBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: const Color(0xFF61764C),
              ),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                color: visuals.textStrong,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
