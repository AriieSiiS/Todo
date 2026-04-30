part of 'editors.dart';

class _CategoryEditorDialog extends StatefulWidget {
  const _CategoryEditorDialog({
    required this.controller,
    this.initialCategory,
  });

  final TodoWorkspace controller;
  final CategoryModel? initialCategory;

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late int _colorValue;
  late IconData _icon;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.initialCategory?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.initialCategory?.description ?? '');
    _colorValue = widget.initialCategory?.colorValue ??
        const Color(0xFF9AAF7E).toARGB32();
    _icon = widget.initialCategory?.icon ?? Icons.spa_outlined;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _nameController.text.trim().isEmpty
        ? 'Autocuidado'
        : _nameController.text.trim();
    final description = _descriptionController.text.trim().isEmpty
        ? 'Rutinas y tareas para sentirme bien y cuidar de mí: ducha, crema facial, descanso y pequeños hábitos.'
        : _descriptionController.text.trim();
    final tasksCount = widget.initialCategory == null
        ? 5
        : widget.controller.tasksByCategory(widget.initialCategory!.id).length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.fromLTRB(
          32, 22, 32, MediaQuery.of(context).viewInsets.bottom + 22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFE2D5C4)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 1180,
            maxHeight: MediaQuery.sizeOf(context).height - 44,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
            child: Column(
              children: [
                _dialogHeader(
                  context,
                  title: widget.initialCategory == null
                      ? 'Nueva categoría'
                      : 'Editar categoría',
                  subtitle:
                      'Crea una categoría permanente para organizar tareas, rutinas y proyectos.',
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ScrollConfiguration(
                    behavior: const MaterialScrollBehavior()
                        .copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 980;
                          final form = _buildCategoryForm(
                              context, title, description, tasksCount);
                          final aside = _buildCategoryAside(
                              context, title, description, tasksCount);
                          if (!wide) {
                            return Column(
                              children: [
                                form,
                                const SizedBox(height: 18),
                                aside,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: form),
                              const SizedBox(width: 22),
                              SizedBox(width: 340, child: aside),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _dialogFooter(
                  primaryLabel: widget.initialCategory == null
                      ? 'Guardar categoría'
                      : 'Guardar cambios',
                  secondaryLabel: widget.initialCategory == null
                      ? 'Guardar y crear otra'
                      : 'Guardar y seguir',
                  onPrimary: () => _save(closeAfter: true),
                  onSecondary: () => _save(
                      closeAfter: widget.initialCategory != null,
                      resetAfter: widget.initialCategory == null),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryForm(
      BuildContext context, String title, String description, int tasksCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Nombre de la categoría'),
        const SizedBox(height: 6),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'Autocuidado',
            suffixIcon: _nameController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () => setState(() => _nameController.clear()),
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        _sectionLabel('Descripción'),
        const SizedBox(height: 6),
        TextField(
          controller: _descriptionController,
          minLines: 3,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Rutinas y tareas para sentirme bien y cuidar de mí.',
            suffixText: '${_descriptionController.text.length}/200',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        _sectionLabel('Icono'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final icon in const <IconData>[
              Icons.spa_outlined,
              Icons.favorite_border_rounded,
              Icons.auto_awesome_outlined,
              Icons.local_florist_outlined,
              Icons.water_drop_outlined,
              Icons.dark_mode_outlined,
              Icons.sentiment_satisfied_alt_outlined,
            ])
              InkWell(
                onTap: () => setState(() => _icon = icon),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 54,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _icon == icon
                        ? Color(_colorValue).withValues(alpha: 0.12)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _icon == icon
                          ? Color(_colorValue)
                          : const Color(0xFFE2D5C4),
                    ),
                  ),
                  child: Icon(icon, color: const Color(0xFF2D2A25)),
                ),
              ),
            InkWell(
              onTap: () async {
                final selected = await _showIconPicker(context);
                if (selected != null) {
                  setState(() => _icon = selected);
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 54,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2D5C4)),
                ),
                child: const Icon(Icons.more_horiz_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _sectionLabel('Color'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ColorPicker(
                selected: _colorValue,
                onSelected: (value) => setState(() => _colorValue = value),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final color = await _showColorPickerDialog(
                  context,
                  initialColor: _colorValue,
                  title: 'Elegir color',
                  subtitle: 'Escoge un color para esta categoría.',
                );
                if (color != null) {
                  setState(() => _colorValue = color);
                }
              },
              icon: const Icon(Icons.palette_outlined, size: 18),
              label: const Text('Elegir color'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: _softBorderBox(),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Color(_colorValue),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _hexFromColorValue(_colorValue),
                  style: const TextStyle(fontWeight: FontWeight.w400),
                ),
              ),
              const Icon(Icons.copy_rounded, size: 18),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionLabel('Vista previa'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: _softBorderBox(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Color(_colorValue).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, color: const Color(0xFF233122)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Color(_colorValue),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                          color: Theme.of(context)
                              .extension<TodoVisuals>()!
                              .textMuted,
                          height: 1.45),
                    ),
                    const SizedBox(height: 10),
                    Text('$tasksCount tareas'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryAside(
      BuildContext context, String title, String description, int tasksCount) {
    final colorName = _categoryColorName(Color(_colorValue));
    return Column(
      children: [
        _AsideCard(
          title: 'Resumen',
          subtitle: 'Así se guardará tu categoría.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Color(_colorValue).withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(_icon, color: const Color(0xFF233122), size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(title,
                                style:
                                    Theme.of(context).textTheme.headlineSmall)),
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                              color: Color(_colorValue),
                              shape: BoxShape.circle),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _summaryLine(Icons.event_note_outlined, 'Categoría permanente'),
              _summaryLine(Icons.calendar_month_outlined,
                  'Se verá en tareas y calendario'),
              _summaryLine(Icons.palette_outlined, 'Color suave $colorName'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _AsideCard(
          title: 'Así se verá',
          subtitle: 'Ejemplo en tus tareas y proyectos.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: _softBorderBox(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Color(_colorValue).withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_icon,
                              color: const Color(0xFF233122), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(title,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600))),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: Color(_colorValue),
                              shape: BoxShape.circle),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: TextStyle(
                          color: Theme.of(context)
                              .extension<TodoVisuals>()!
                              .textMuted,
                          height: 1.45),
                    ),
                    const SizedBox(height: 10),
                    Text('$tasksCount tareas'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {},
                  label: const Text('Ver más ejemplos'),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _save({
    required bool closeAfter,
    bool resetAfter = false,
  }) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    if (widget.initialCategory == null) {
      widget.controller.createCategory(
        name: name,
        description: _descriptionController.text.trim(),
        colorValue: _colorValue,
        icon: _icon,
      );
    } else {
      widget.controller.updateCategory(
        widget.initialCategory!.copyWith(
          name: name,
          description: _descriptionController.text.trim(),
          colorValue: _colorValue,
          icon: _icon,
        ),
      );
    }
    if (resetAfter) {
      setState(() {
        _nameController.clear();
        _descriptionController.clear();
        _colorValue = const Color(0xFF9AAF7E).toARGB32();
        _icon = Icons.spa_outlined;
      });
      return;
    }
    if (closeAfter && mounted) {
      Navigator.of(context).pop();
    }
  }

  String _categoryColorName(Color color) {
    final red = (color.r * 255.0).round().clamp(0, 255);
    final green = (color.g * 255.0).round().clamp(0, 255);
    final blue = (color.b * 255.0).round().clamp(0, 255);
    if (green >= red && green >= blue) return 'verde';
    if (blue >= red && blue >= green) return 'azul';
    if (red >= green && red >= blue) return 'coral';
    return 'suave';
  }
}
