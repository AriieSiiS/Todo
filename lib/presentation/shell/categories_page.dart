part of 'app_shell.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({required this.controller, super.key});

  final TodoWorkspace controller;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  String _query = '';
  String? _selectedCategoryId;

  TodoWorkspace get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final categories = controller.categories
        .where((category) =>
            category.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    final selected = _resolveSelectedCategory(categories);
    final wide = MediaQuery.sizeOf(context).width >= 1260;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReferenceCategoriesHeader(
            query: _query,
            onQueryChanged: (value) => setState(() => _query = value),
            onCreateCategory: () => showCategoryEditor(context, controller),
            onReorder: _reorderCategories,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ReferenceCategoryGrid(
                          controller: controller,
                          categories: categories,
                          selectedCategoryId: selected?.id,
                          onSelect: (id) =>
                              setState(() => _selectedCategoryId = id),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 452,
                        child: selected == null
                            ? const SizedBox.shrink()
                            : SingleChildScrollView(
                                child: _ReferenceCategoryDetailPanel(
                                  controller: controller,
                                  category: selected,
                                  onEditCategory: () => showCategoryEditor(
                                    context,
                                    controller,
                                    initialCategory: selected,
                                  ),
                                  onDeleteCategory: () =>
                                      _deleteCategory(selected),
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 254,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _ReferenceCategoryUnassignedPanel(
                                  controller: controller),
                              const SizedBox(height: 14),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    children: [
                      _ReferenceCategoryGrid(
                        controller: controller,
                        categories: categories,
                        selectedCategoryId: selected?.id,
                        onSelect: (id) =>
                            setState(() => _selectedCategoryId = id),
                      ),
                      const SizedBox(height: 14),
                      if (selected != null)
                        _ReferenceCategoryDetailPanel(
                          controller: controller,
                          category: selected,
                          onEditCategory: () => showCategoryEditor(
                            context,
                            controller,
                            initialCategory: selected,
                          ),
                          onDeleteCategory: () => _deleteCategory(selected),
                        ),
                      const SizedBox(height: 14),
                      _ReferenceCategoryUnassignedPanel(controller: controller),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  CategoryModel? _resolveSelectedCategory(List<CategoryModel> categories) {
    if (categories.isEmpty) {
      return null;
    }
    final selected = _selectedCategoryId == null
        ? null
        : categories
            .where((category) => category.id == _selectedCategoryId)
            .firstOrNull;
    return selected ?? categories.first;
  }

  void _reorderCategories() {
    setState(() {});
  }

  Future<void> _deleteCategory(CategoryModel category) async {
    final tasks = controller.tasksByCategory(category.id).length;
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (context) => AlertDialog(
        title: const Text('Borrar categoria'),
        content: Text(
          tasks == 0
              ? 'La categoria se borrara de forma permanente.'
              : 'La categoria se borrara y se quitara de $tasks tareas. Las tareas no se eliminaran.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) {
      return;
    }
    controller.deleteCategory(category.id);
    setState(() {
      _selectedCategoryId = null;
    });
  }
}

class _ReferenceCategoriesHeader extends StatelessWidget {
  const _ReferenceCategoriesHeader({
    required this.query,
    required this.onQueryChanged,
    required this.onCreateCategory,
    required this.onReorder,
  });

  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onCreateCategory;
  final VoidCallback onReorder;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Categorías',
                  style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 6),
              Text(
                'Organiza tus tareas por áreas permanentes de tu vida y tu casa.',
                style: TextStyle(
                    color: context.visuals.textMuted,
                    fontSize: 15,
                    height: 1.2),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _HeaderActionButton(
              label: 'Nueva categoría',
              icon: Icons.add_rounded,
              onPressed: onCreateCategory,
            ),
            OutlinedButton.icon(
              onPressed: onReorder,
              icon: const Icon(Icons.swap_vert_rounded, size: 18),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              label: const Text('Ordenar'),
            ),
            SizedBox(
              height: 48,
              width: 270,
              child: TextField(
                controller: TextEditingController(text: query)
                  ..selection = TextSelection.collapsed(offset: query.length),
                onChanged: onQueryChanged,
                decoration: const InputDecoration(
                  hintText: 'Buscar categorías...',
                  suffixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReferenceCategoryGrid extends StatelessWidget {
  const _ReferenceCategoryGrid({
    required this.controller,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelect,
  });

  final TodoWorkspace controller;
  final List<CategoryModel> categories;
  final String? selectedCategoryId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return _SurfaceCard(
        child: Center(
          child: Text('No hay categorías para esta búsqueda.',
              style: TextStyle(color: context.visuals.textMuted)),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.12,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final tasks = controller.tasksByCategory(category.id);
        final metrics = (
          active:
              tasks.where((task) => task.status == TaskStatus.active).length,
          recurring: tasks.where((task) => task.recurrence.isRecurring).length,
          completed:
              tasks.where((task) => task.status == TaskStatus.completed).length,
        );
        final selected = category.id == selectedCategoryId;

        return InkWell(
          onTap: () => onSelect(category.id),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? const Color(0xFF93A37C)
                    : const Color(0xFFE5D8C7),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(category.icon, color: category.color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(category.name,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            category.description.isNotEmpty
                                ? category.description
                                : _categoryDescription(category.name),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: context.visuals.textMuted, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF70835D), size: 22),
                  ],
                ),
                const Spacer(),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _CategoryMetric(
                            value: '${metrics.active}',
                            label: 'Tareas activas')),
                    Expanded(
                        child: _CategoryMetric(
                            value: '${metrics.recurring}', label: 'Rutinas')),
                    Expanded(
                        child: _CategoryMetric(
                            value: '${metrics.completed}',
                            label: 'Completadas\nesta semana')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CategoryMetric extends StatelessWidget {
  const _CategoryMetric({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.visuals.textMuted, height: 1.15),
        ),
      ],
    );
  }
}

class _ReferenceCategoryDetailPanel extends StatelessWidget {
  const _ReferenceCategoryDetailPanel({
    required this.controller,
    required this.category,
    required this.onEditCategory,
    required this.onDeleteCategory,
  });

  final TodoWorkspace controller;
  final CategoryModel category;
  final VoidCallback onEditCategory;
  final VoidCallback onDeleteCategory;

  @override
  Widget build(BuildContext context) {
    final tasks = controller.tasksByCategory(category.id);
    final sampleTasks =
        tasks.where((task) => task.parentTaskId == null).take(4).toList();
    final recurringTasks =
        tasks.where((task) => task.recurrence.isRecurring).take(2).toList();
    final relatedProjects = controller.projects
        .where((project) => project.categoryIds.contains(category.id))
        .take(3)
        .toList();

    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Detalle de categoría',
                          style: TextStyle(
                              color: context.visuals.textMuted, fontSize: 15)),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: category.color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(category.icon, color: category.color),
                          ),
                          const SizedBox(width: 14),
                          Text(category.name,
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(width: 10),
                          _ReferenceTagChip(
                            label: 'Categoría permanente',
                            color: const Color(0xFFEFF3E6),
                            textColor: const Color(0xFF70835D),
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: onEditCategory,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Editar'),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_horiz_rounded),
                            onSelected: (value) {
                              if (value == 'delete') {
                                onDeleteCategory();
                              } else if (value == 'toggle') {
                                controller.toggleCategory(category.id);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(category.active
                                    ? 'Pausar categoria'
                                    : 'Activar categoria'),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                  value: 'delete', child: Text('Borrar')),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        category.description.isNotEmpty
                            ? category.description
                            : 'Las categorías son permanentes y representan áreas clave de tu vida y tu casa. Los proyectos cambian, pero las categorías siempre están aquí.',
                        style: TextStyle(
                            color: context.visuals.textStrong, height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _CategoryDetailSection(
            icon: Icons.thumb_up_off_alt_rounded,
            title: 'Tareas',
            trailing: IconButton(
                onPressed: () => showTaskEditor(context, controller),
                icon: const Icon(Icons.add_rounded)),
            child: Column(
              children: sampleTasks.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 2, 0, 2),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('No hay tareas todavía.',
                              style:
                                  TextStyle(color: context.visuals.textMuted)),
                        ),
                      ),
                    ]
                  : sampleTasks
                      .map(
                        (task) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: context.visuals.panelBorder),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(task.title,
                                      style: const TextStyle(fontSize: 16))),
                              if (task.recurrence.isRecurring)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: _ReferenceTagChip(
                                    label: 'Rutina',
                                    color: Color(0xFFE3F4F3),
                                    textColor: Color(0xFF5E9B97),
                                  ),
                                ),
                              _ReferenceTagChip(
                                label: task.recurrence.isRecurring
                                    ? 'Semanal'
                                    : 'Tarea única',
                                color: const Color(0xFFF4F1EC),
                                textColor: const Color(0xFF7D7A73),
                              ),
                              IconButton(
                                  onPressed: () => showTaskEditor(
                                      context, controller,
                                      initialTask: task),
                                  icon: const Icon(Icons.more_horiz_rounded)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          const Divider(height: 1),
          _CategoryDetailSection(
            icon: Icons.event_note_rounded,
            title: 'Rutinas',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...recurringTasks.map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 18,
                          height: 52,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                  color: context.visuals.panelBorder),
                              bottom: BorderSide(
                                  color: context.visuals.panelBorder),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(task.title,
                                  style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                task.scheduledAt == null
                                    ? 'Semanal'
                                    : 'Semanal · ${_weekdayLabel(task.scheduledAt!)} ${_timeLabel(task.scheduledAt!)}',
                                style:
                                    TextStyle(color: context.visuals.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  'Ver todas las rutinas (${recurringTasks.length})',
                  style: TextStyle(color: context.visuals.textMuted),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _CategoryDetailSection(
            icon: Icons.folder_open_rounded,
            title: 'Proyectos',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...relatedProjects.map(
                  (project) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 52,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                  color: context.visuals.panelBorder),
                              bottom: BorderSide(
                                  color: context.visuals.panelBorder),
                            ),
                          ),
                        ),
                        Expanded(
                            child: Text(project.name,
                                style: const TextStyle(fontSize: 16))),
                        _ReferenceTagChip(
                          label: _projectStatusLabel(project.status),
                          color: _projectStatusColor(project.status)
                              .withValues(alpha: 0.14),
                          textColor: _projectStatusColor(project.status),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  'Ver todos los proyectos (${relatedProjects.length})',
                  style: TextStyle(color: context.visuals.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDetailSection extends StatelessWidget {
  const _CategoryDetailSection({
    required this.icon,
    required this.title,
    this.trailing,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: context.visuals.accent),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600))),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ReferenceCategoryUnassignedPanel extends StatelessWidget {
  const _ReferenceCategoryUnassignedPanel({required this.controller});

  final TodoWorkspace controller;

  @override
  Widget build(BuildContext context) {
    final uncategorized = controller.tasks
        .where((task) =>
            task.categoryIds.isEmpty && task.status == TaskStatus.active)
        .length;
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline_rounded, size: 18),
              const SizedBox(width: 8),
              Text('Sin asignar / revisar',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 18),
          Text('$uncategorized',
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(fontSize: 26)),
          const SizedBox(height: 4),
          Text('Tareas sin categoría',
              style: TextStyle(color: context.visuals.textMuted)),
          const SizedBox(height: 12),
          Text(
            'Revisa y asigna a la categoría que mejor corresponda.',
            style: TextStyle(color: context.visuals.textStrong, height: 1.35),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: () {},
            child: const Text('Revisar tareas'),
          ),
        ],
      ),
    );
  }
}

String _categoryDescription(String name) => switch (name.toLowerCase()) {
      'baño' => 'Limpieza, orden y cuidado del baño.',
      'cocina' => 'Preparación de alimentos, limpieza y organización.',
      'salón' => 'Limpieza, orden y mantenimiento general.',
      'comedor' => 'Orden, limpieza y decoración del comedor.',
      'patio' => 'Jardín, exteriores y mantenimiento.',
      'recibidor' => 'Entrada de la casa, orden y primeras impresiones.',
      'gimnasio' => 'Entrenamiento, equipo y recuperación.',
      'autocuidado' => 'Rutinas personales, bienestar y descanso.',
      'compras' => 'Lista de compras, seguimiento y planificación.',
      'calendario' => 'Citas, eventos y compromisos.',
      'otros' => 'Tareas varias que no encajan en otras categorías.',
      _ => 'Área estable para organizar tareas y rutinas.',
    };

enum _CalendarViewMode { month, week, agenda }
