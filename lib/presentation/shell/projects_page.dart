part of 'app_shell.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({required this.controller, super.key});

  final TodoWorkspace controller;

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  String? _selectedProjectId;
  ProjectStatus? _statusFilter;

  TodoWorkspace get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final allProjects = controller.projects;
    final projects = _statusFilter == null
        ? allProjects
        : allProjects
            .where((project) => project.status == _statusFilter)
            .toList();
    final selectedProject = _resolveSelectedProject(projects);
    final selectedTasks = selectedProject == null
        ? const <TaskModel>[]
        : _projectTasks(selectedProject);
    final wide = MediaQuery.sizeOf(context).width >= 1240;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReferenceProjectsHeader(
            filterActive: _statusFilter != null,
            onCreateProject: () => showProjectEditor(context, controller),
            onOpenFilter: _showStatusFilterMenu,
            onReorder: _sortProjectsByUrgency,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            Expanded(
                              child: _ReferenceProjectsBoard(
                                controller: controller,
                                projects: projects,
                                selectedProjectId: selectedProject?.id,
                                onSelectProject: (projectId) {
                                  setState(() {
                                    _selectedProjectId = projectId;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (selectedProject != null)
                              _ReferenceProjectDetailPanel(
                                controller: controller,
                                project: selectedProject,
                                tasks: selectedTasks,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Align(
                        alignment: Alignment.topCenter,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: 320,
                            child: Column(
                              children: [
                                _ReferenceProjectSummaryPanel(
                                    controller: controller,
                                    projects: allProjects),
                                const SizedBox(height: 12),
                                _ReferenceProjectMilestonesPanel(
                                  controller: controller,
                                  projects: allProjects,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    children: [
                      _ReferenceProjectsBoard(
                        controller: controller,
                        projects: projects,
                        selectedProjectId: selectedProject?.id,
                        onSelectProject: (projectId) {
                          setState(() {
                            _selectedProjectId = projectId;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      if (selectedProject != null)
                        _ReferenceProjectDetailPanel(
                          controller: controller,
                          project: selectedProject,
                          tasks: selectedTasks,
                        ),
                      const SizedBox(height: 14),
                      _ReferenceProjectSummaryPanel(
                          controller: controller, projects: allProjects),
                      const SizedBox(height: 12),
                      _ReferenceProjectMilestonesPanel(
                          controller: controller, projects: allProjects),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  ProjectModel? _resolveSelectedProject(List<ProjectModel> projects) {
    if (projects.isEmpty) {
      return null;
    }
    final selected = _selectedProjectId == null
        ? null
        : controller.projectById(_selectedProjectId!);
    if (selected != null &&
        projects.any((project) => project.id == selected.id)) {
      return selected;
    }
    return projects.first;
  }

  List<TaskModel> _projectTasks(ProjectModel project) {
    return controller.tasks
        .where((task) =>
            task.projectIds.contains(project.id) && task.parentTaskId == null)
        .toList()
      ..sort((left, right) {
        final leftTime = left.scheduledAt ?? DateTime(9999);
        final rightTime = right.scheduledAt ?? DateTime(9999);
        return leftTime.compareTo(rightTime);
      });
  }

  Future<void> _showStatusFilterMenu() async {
    final selected = await showMenu<ProjectStatus?>(
      context: context,
      position: const RelativeRect.fromLTRB(0, 120, 24, 0),
      items: [
        CheckedPopupMenuItem<ProjectStatus?>(
          value: null,
          checked: _statusFilter == null,
          child: const Text('Todos'),
        ),
        ...ProjectStatus.values.map(
          (status) => CheckedPopupMenuItem<ProjectStatus?>(
            value: status,
            checked: _statusFilter == status,
            child: Text(_projectStatusLabel(status)),
          ),
        ),
      ],
    );
    if (!mounted || selected == _statusFilter) {
      return;
    }
    setState(() {
      _statusFilter = selected;
    });
  }

  void _sortProjectsByUrgency() {
    final sorted = [...controller.projects]..sort((left, right) {
        final leftDate = _projectDueDate(left) ?? DateTime(9999);
        final rightDate = _projectDueDate(right) ?? DateTime(9999);
        return leftDate.compareTo(rightDate);
      });
    if (sorted.isNotEmpty) {
      setState(() {
        _selectedProjectId = sorted.first.id;
      });
    }
  }

  DateTime? _projectDueDate(ProjectModel project) {
    final scheduled = controller.tasks
        .where((task) =>
            task.projectIds.contains(project.id) &&
            task.status == TaskStatus.active &&
            task.scheduledAt != null)
        .map((task) => task.scheduledAt!)
        .toList()
      ..sort();
    return scheduled.isEmpty ? null : scheduled.first;
  }
}

class _ReferenceProjectsHeader extends StatelessWidget {
  const _ReferenceProjectsHeader({
    required this.filterActive,
    required this.onCreateProject,
    required this.onOpenFilter,
    required this.onReorder,
  });

  final bool filterActive;
  final VoidCallback onCreateProject;
  final VoidCallback onOpenFilter;
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
              Text('Proyectos',
                  style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 6),
              Text(
                'Organiza objetivos temporales, planes y agrupaciones activas.',
                style: TextStyle(
                    color: context.visuals.textMuted,
                    fontSize: 15,
                    height: 1.2),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _HeaderActionButton(
              label: 'Nuevo proyecto',
              icon: Icons.add_rounded,
              onPressed: onCreateProject,
            ),
            OutlinedButton.icon(
              onPressed: onOpenFilter,
              icon: const Icon(Icons.filter_alt_outlined, size: 18),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              label: Text(filterActive ? 'Filtrar · Activo' : 'Filtrar'),
            ),
            OutlinedButton.icon(
              onPressed: onReorder,
              icon: const Icon(Icons.swap_vert_rounded, size: 18),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              label: const Text('Ordenar'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReferenceProjectsBoard extends StatelessWidget {
  const _ReferenceProjectsBoard({
    required this.controller,
    required this.projects,
    required this.selectedProjectId,
    required this.onSelectProject,
  });

  final TodoWorkspace controller;
  final List<ProjectModel> projects;
  final String? selectedProjectId;
  final ValueChanged<String> onSelectProject;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Row(
              children: [
                Text(
                  'Mis proyectos',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontSize: 21),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.visuals.panelAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${projects.length}',
                      style: TextStyle(color: context.visuals.textMuted)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (projects.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No hay proyectos para este filtro.',
                  style: TextStyle(color: context.visuals.textMuted),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(10),
                itemCount: projects.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final project = projects[index];
                  return _ReferenceProjectRow(
                    controller: controller,
                    project: project,
                    selected: project.id == selectedProjectId,
                    onTap: () => onSelectProject(project.id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ReferenceProjectRow extends StatelessWidget {
  const _ReferenceProjectRow({
    required this.controller,
    required this.project,
    required this.selected,
    required this.onTap,
  });

  final TodoWorkspace controller;
  final ProjectModel project;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tasks = controller.tasks
        .where((task) =>
            task.projectIds.contains(project.id) && task.parentTaskId == null)
        .toList();
    final activeTasks =
        tasks.where((task) => task.status == TaskStatus.active).toList();
    final doneTasks =
        tasks.where((task) => task.status == TaskStatus.completed).length;
    final progress = tasks.isEmpty ? 0.0 : doneTasks / tasks.length;
    final dueDate = tasks
        .where((task) =>
            task.status == TaskStatus.active && task.scheduledAt != null)
        .map((task) => task.scheduledAt!)
        .fold<DateTime?>(
            null,
            (current, value) =>
                current == null || value.isBefore(current) ? value : current);
    final category = project.categoryIds.isNotEmpty
        ? controller.categoryById(project.categoryIds.first)
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF93A37C) : const Color(0xFFE5D8C7),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: project.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(project.icon, color: project.color, size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    project.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: context.visuals.textMuted, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            SizedBox(
              width: 86,
              child: Column(
                children: [
                  Text('${(progress * 100).round()}%',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      value: progress.clamp(0, 1),
                      backgroundColor: const Color(0xFFE8E1D6),
                      valueColor: AlwaysStoppedAnimation<Color>(project.color),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            SizedBox(
              width: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${activeTasks.length} / ${tasks.length}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('tareas abiertas',
                      style: TextStyle(color: context.visuals.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 18),
            SizedBox(
              width: 118,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 16, color: context.visuals.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dueDate == null
                              ? 'Sin fecha'
                              : _weekdayLabel(dueDate),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dueDate == null
                        ? 'limite'
                        : '${dueDate.day} de ${_monthName(dueDate.month)}',
                    style: TextStyle(color: context.visuals.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 90,
              child: category == null
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: _ReferenceTagChip(
                        label: category.name,
                        color: category.color.withValues(alpha: 0.14),
                        textColor: category.color,
                      ),
                    ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (value) async {
                if (value == 'edit') {
                  await showProjectEditor(context, controller,
                      initialProject: project);
                } else if (value == 'complete') {
                  controller.completeProject(project.id);
                } else if (value == 'pause') {
                  controller.setProjectStatus(project.id, ProjectStatus.paused);
                } else if (value == 'cancel') {
                  controller.cancelProject(project.id);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'complete', child: Text('Completar')),
                PopupMenuItem(value: 'pause', child: Text('Pausar')),
                PopupMenuItem(value: 'cancel', child: Text('Cancelar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceProjectDetailPanel extends StatelessWidget {
  const _ReferenceProjectDetailPanel({
    required this.controller,
    required this.project,
    required this.tasks,
  });

  final TodoWorkspace controller;
  final ProjectModel project;
  final List<TaskModel> tasks;

  @override
  Widget build(BuildContext context) {
    final activeTasks =
        tasks.where((task) => task.status == TaskStatus.active).toList();
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: project.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(project.icon, color: project.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(project.name,
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _ReferenceTagChip(
                            label: _projectStatusLabel(project.status),
                            color: _projectStatusColor(project.status)
                                .withValues(alpha: 0.16),
                            textColor: _projectStatusColor(project.status),
                          ),
                          const SizedBox(width: 18),
                          ...const [
                            Text('Tareas'),
                            SizedBox(width: 20),
                            Text('Detalles'),
                            SizedBox(width: 20),
                            Text('Notas'),
                            SizedBox(width: 20),
                            Text('Archivos'),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => showProjectEditor(context, controller,
                      initialProject: project),
                  child: const Text('Ver proyecto completo'),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      showProjectEditor(context, controller,
                          initialProject: project);
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Row(
              children: [
                Text(
                  'Tareas del proyecto',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontSize: 18),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.visuals.panelAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${tasks.length}',
                      style: TextStyle(color: context.visuals.textMuted)),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => showTaskEditor(context, controller),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Añadir tarea'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...activeTasks.take(4).map(
                (task) => Column(
                  children: [
                    _ReferenceProjectTaskRow(
                        controller: controller, task: task),
                    if (task != activeTasks.take(4).last)
                      const Divider(height: 1),
                  ],
                ),
              ),
          InkWell(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Row(
                children: [
                  Expanded(
                      child: Text('Ver todas las tareas (${tasks.length})',
                          style: TextStyle(color: context.visuals.textMuted))),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceProjectTaskRow extends StatelessWidget {
  const _ReferenceProjectTaskRow({
    required this.controller,
    required this.task,
  });

  final TodoWorkspace controller;
  final TaskModel task;

  @override
  Widget build(BuildContext context) {
    final category = task.categoryIds.isNotEmpty
        ? controller.categoryById(task.categoryIds.first)
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Row(
        children: [
          Checkbox(
              value: task.status == TaskStatus.completed,
              onChanged: (_) => controller.completeTask(task.id)),
          Expanded(
            child: Text(task.title, style: const TextStyle(fontSize: 17)),
          ),
          SizedBox(
            width: 132,
            child: category == null
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.centerLeft,
                    child: _ReferenceTagChip(
                      label: category.name,
                      color: category.color.withValues(alpha: 0.14),
                      textColor: category.color,
                    ),
                  ),
          ),
          SizedBox(
            width: 110,
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16),
                const SizedBox(width: 8),
                Text(task.scheduledAt == null
                    ? 'Sin fecha'
                    : _friendlyTaskDay(task.scheduledAt!)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _ReferencePriorityFlag(priority: task.priority),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar')),
            ],
            onSelected: (value) {
              if (value == 'edit') {
                showTaskEditor(context, controller, initialTask: task);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ReferenceProjectSummaryPanel extends StatelessWidget {
  const _ReferenceProjectSummaryPanel({
    required this.controller,
    required this.projects,
  });

  final TodoWorkspace controller;
  final List<ProjectModel> projects;

  @override
  Widget build(BuildContext context) {
    final active = projects
        .where((project) => project.status == ProjectStatus.active)
        .length;
    final paused = projects
        .where((project) => project.status == ProjectStatus.paused)
        .length;
    final finished = projects
        .where((project) => project.status == ProjectStatus.completed)
        .length;
    final upcoming = projects.where((project) {
      final due = controller.tasks
          .where((task) =>
              task.projectIds.contains(project.id) &&
              task.status == TaskStatus.active &&
              task.scheduledAt != null)
          .map((task) => task.scheduledAt!)
          .toList()
        ..sort();
      if (due.isEmpty) {
        return false;
      }
      return due.first
          .isBefore(controller.logicalDate().add(const Duration(days: 7)));
    }).length;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen de proyectos',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontSize: 21)),
          const SizedBox(height: 10),
          _ReferenceSummaryLine(
            icon: Icons.play_circle_outline_rounded,
            tone: const Color(0xFF70835D),
            title: 'Activos',
            subtitle: 'Proyectos en curso',
            value: '$active',
          ),
          const Divider(height: 24),
          _ReferenceSummaryLine(
            icon: Icons.pause_circle_outline_rounded,
            tone: const Color(0xFFF0AA2B),
            title: 'En pausa',
            subtitle: 'Temporalmente detenidos',
            value: '$paused',
          ),
          const Divider(height: 24),
          _ReferenceSummaryLine(
            icon: Icons.check_circle_outline_rounded,
            tone: const Color(0xFF7D7A73),
            title: 'Finalizados',
            subtitle: 'Completados',
            value: '$finished',
          ),
          const Divider(height: 24),
          _ReferenceSummaryLine(
            icon: Icons.calendar_today_outlined,
            tone: const Color(0xFF8D8A84),
            title: 'Próximos a vencer',
            subtitle: 'En los próximos 7 días',
            value: '$upcoming',
          ),
        ],
      ),
    );
  }
}

class _ReferenceSummaryLine extends StatelessWidget {
  const _ReferenceSummaryLine({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String subtitle;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: tone),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(color: context.visuals.textMuted)),
            ],
          ),
        ),
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ReferenceProjectMilestonesPanel extends StatelessWidget {
  const _ReferenceProjectMilestonesPanel({
    required this.controller,
    required this.projects,
  });

  final TodoWorkspace controller;
  final List<ProjectModel> projects;

  @override
  Widget build(BuildContext context) {
    final milestones = controller.tasks
        .where((task) =>
            task.projectIds.isNotEmpty && task.status == TaskStatus.active)
        .toList()
      ..sort((left, right) {
        final leftTime = left.scheduledAt ?? DateTime(9999);
        final rightTime = right.scheduledAt ?? DateTime(9999);
        return leftTime.compareTo(rightTime);
      });
    final visible = milestones.take(4).toList();

    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text('Próximos hitos',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontSize: 21)),
                ),
                const Text('Esta semana'),
                const SizedBox(width: 6),
                const Icon(Icons.expand_more_rounded),
              ],
            ),
          ),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Text('No hay hitos previstos.',
                  style: TextStyle(color: context.visuals.textMuted)),
            )
          else
            ...visible.map(
              (task) {
                final project = task.projectIds.isEmpty
                    ? null
                    : controller.projectById(task.projectIds.first);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: (project?.color ?? const Color(0xFFEDE5D8))
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(project?.icon ?? Icons.flag_rounded,
                                color: project?.color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(project?.name ?? task.title,
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(task.title,
                                    style: TextStyle(
                                        color: context.visuals.textMuted)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(task.scheduledAt == null
                                  ? 'Sin fecha'
                                  : _milestoneDate(task.scheduledAt!)),
                              const SizedBox(height: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _priorityColor(task.priority),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (task != visible.last) const Divider(height: 1),
                  ],
                );
              },
            ),
          InkWell(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Row(
                children: [
                  Expanded(
                      child: Text('Ver todos los hitos',
                          style: TextStyle(color: context.visuals.textMuted))),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _projectStatusLabel(ProjectStatus status) => switch (status) {
      ProjectStatus.active => 'Activo',
      ProjectStatus.paused => 'En pausa',
      ProjectStatus.completed => 'Finalizado',
      ProjectStatus.cancelled => 'Cancelado',
    };

Color _projectStatusColor(ProjectStatus status) => switch (status) {
      ProjectStatus.active => const Color(0xFF70835D),
      ProjectStatus.paused => const Color(0xFFF0AA2B),
      ProjectStatus.completed => const Color(0xFF7D7A73),
      ProjectStatus.cancelled => const Color(0xFFE06B58),
    };

String _monthName(int month) => const [
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
    ][month];

String _friendlyTaskDay(DateTime value) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(value.year, value.month, value.day);
  final difference = target.difference(today).inDays;
  if (difference == 0) {
    return 'Hoy';
  }
  if (difference == 1) {
    return 'Mañana';
  }
  return '${_weekdayLabel(value)} ${value.day} ${_monthName(value.month)}';
}

String _milestoneDate(DateTime value) =>
    '${_weekdayLabel(value)} ${value.day} ${_monthName(value.month)}';

Color _priorityColor(TaskPriority priority) => switch (priority) {
      TaskPriority.urgent => const Color(0xFFE54A44),
      TaskPriority.high => const Color(0xFFF2A633),
      TaskPriority.medium => const Color(0xFF6E94E7),
      TaskPriority.low => const Color(0xFF70835D),
    };
