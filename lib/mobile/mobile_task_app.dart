import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../domain/models.dart';
import 'mobile_task_controller.dart';
import 'mobile_wardrobe_pages.dart';

class MobileTaskApp extends StatefulWidget {
  const MobileTaskApp({super.key});

  @override
  State<MobileTaskApp> createState() => _MobileTaskAppState();
}

class _MobileTaskAppState extends State<MobileTaskApp>
    with WidgetsBindingObserver {
  late final MobileTaskController controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = MobileTaskController();
    unawaited(controller.initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && controller.paired) {
      unawaited(controller.syncAll());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6D815A),
          surface: const Color(0xFFFFFCF8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5EEE3),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          color: Color(0xFFFFFCF8),
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
      ),
      locale: const Locale('es', 'ES'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES')],
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.initializing) return const _MobileLoadingPage();
          if (!controller.paired) {
            return _PairingPage(controller: controller);
          }
          return _MobileTaskShell(controller: controller);
        },
      ),
    );
  }
}

class _MobileLoadingPage extends StatelessWidget {
  const _MobileLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando tus tareas…'),
          ],
        ),
      ),
    );
  }
}

class _PairingPage extends StatefulWidget {
  const _PairingPage({required this.controller});

  final MobileTaskController controller;

  @override
  State<_PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<_PairingPage> {
  final TextEditingController _manualController = TextEditingController();

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conectar con Todo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phonelink_rounded, size: 42),
            ),
            const SizedBox(height: 24),
            Text(
              'Tus tareas, también en el móvil',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Abre Ajustes → Conexión Android en el ordenador y escanea el código. La conexión es local, cifrada y de solo lectura.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: widget.controller.syncing
                  ? null
                  : () => _openScanner(context),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Escanear código del ordenador'),
            ),
            const SizedBox(height: 18),
            ExpansionTile(
              title: const Text('Introducir código manualmente'),
              childrenPadding: const EdgeInsets.only(bottom: 12),
              children: [
                TextField(
                  controller: _manualController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Contenido del código de emparejamiento',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: widget.controller.syncing
                      ? null
                      : () => _pair(_manualController.text),
                  child: const Text('Conectar'),
                ),
              ],
            ),
            if (widget.controller.syncing) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
            ],
            if (widget.controller.error.isNotEmpty) ...[
              const SizedBox(height: 20),
              _InfoBanner(
                icon: Icons.error_outline_rounded,
                text: widget.controller.error,
                error: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openScanner(BuildContext context) async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _QrScannerPage()),
    );
    if (value != null && mounted) await _pair(value);
  }

  Future<void> _pair(String raw) async {
    if (raw.trim().isEmpty) return;
    try {
      await widget.controller.pair(raw.trim(), deviceName: 'Android personal');
      if (!mounted) return;
      await widget.controller.requestNotificationPermissions();
    } catch (_) {}
  }
}

class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear código')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_handled) return;
              final raw = capture.barcodes.isEmpty
                  ? null
                  : capture.barcodes.first.rawValue;
              if (raw == null || raw.isEmpty) return;
              _handled = true;
              Navigator.of(context).pop(raw);
            },
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 36,
            child: Text(
              'Apunta al código que aparece en Ajustes de Todo para Windows.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileTaskShell extends StatefulWidget {
  const _MobileTaskShell({required this.controller});

  final MobileTaskController controller;

  @override
  State<_MobileTaskShell> createState() => _MobileTaskShellState();
}

class _MobileTaskShellState extends State<_MobileTaskShell> {
  int _index = 0;
  bool _openingTask = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final pending = controller.takeTaskToOpen();
    if (pending != null && !_openingTask) {
      _openingTask = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final task = controller.taskById(pending);
        if (mounted && task != null) await _showTask(context, task);
        _openingTask = false;
      });
    }

    final pages = [
      _TaskListPage(
        title: 'Hoy',
        subtitle: _todayLabel(context, controller),
        tasks: controller.todayTasks,
        controller: controller,
      ),
      _TaskListPage(
        title: 'Próximas',
        subtitle: 'La siguiente fecha de cada tarea',
        tasks: controller.upcomingTasks,
        controller: controller,
        groupByDate: true,
      ),
      _TaskListPage(
        title: 'Todas',
        subtitle: '${controller.allTasks.length} tareas activas',
        tasks: controller.allTasks,
        controller: controller,
      ),
      MobileWardrobePage(controller: controller),
      MobilePackingPage(controller: controller),
    ];

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Todo'),
            actions: [
              if (controller.syncing)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: controller.syncAll,
                  icon: const Icon(Icons.sync_rounded),
                ),
              IconButton(
                tooltip: 'Ajustes',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Ajustes')),
                      body: _MobileSettingsPage(controller: controller),
                    ),
                  ),
                ),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: Column(
            children: [
              if (controller.stale || controller.error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _InfoBanner(
                    icon: controller.error.isEmpty
                        ? Icons.history_rounded
                        : Icons.wifi_off_rounded,
                    text: controller.error.isEmpty
                        ? 'Esta es la última copia disponible. Conecta el móvil a la misma Wi-Fi que el PC para actualizar.'
                        : controller.error,
                    error: controller.error.isNotEmpty,
                  ),
                ),
              Expanded(child: IndexedStack(index: _index, children: pages)),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.today_outlined),
                selectedIcon: Icon(Icons.today_rounded),
                label: 'Hoy',
              ),
              NavigationDestination(
                icon: Icon(Icons.upcoming_outlined),
                selectedIcon: Icon(Icons.upcoming_rounded),
                label: 'Próximas',
              ),
              NavigationDestination(
                icon: Icon(Icons.list_alt_outlined),
                selectedIcon: Icon(Icons.list_alt_rounded),
                label: 'Todas',
              ),
              NavigationDestination(
                icon: Icon(Icons.checkroom_outlined),
                selectedIcon: Icon(Icons.checkroom_rounded),
                label: 'Ropa',
              ),
              NavigationDestination(
                icon: Icon(Icons.luggage_outlined),
                selectedIcon: Icon(Icons.luggage_rounded),
                label: 'Maletas',
              ),
            ],
          ),
        ),
        if (controller.activeAlarm != null)
          Positioned.fill(
            child: _MobileAlarmOverlay(
              title: controller.activeAlarm!.title,
              body: controller.activeAlarm!.body,
              onStop: controller.stopActiveAlarm,
              onSnooze: controller.snoozeActiveAlarm,
              onOpen: controller.openActiveAlarmTask,
            ),
          ),
      ],
    );
  }

  Future<void> _showTask(BuildContext context, TaskModel task) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _TaskDetailSheet(
          task: task,
          controller: widget.controller,
        ),
      );

  String _todayLabel(BuildContext context, MobileTaskController controller) {
    final date = controller.snapshot?.logicalDate() ?? DateTime.now();
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }
}

class _TaskListPage extends StatelessWidget {
  const _TaskListPage({
    required this.title,
    required this.subtitle,
    required this.tasks,
    required this.controller,
    this.groupByDate = false,
  });

  final String title;
  final String subtitle;
  final List<TaskModel> tasks;
  final MobileTaskController controller;
  final bool groupByDate;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.sync,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          if (tasks.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyTasks(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
              sliver: SliverList.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final previous = index == 0 ? null : tasks[index - 1];
                  final showDate = groupByDate &&
                      task.scheduledAt != null &&
                      (previous?.scheduledAt == null ||
                          !_sameDay(task.scheduledAt!, previous!.scheduledAt!));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showDate)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
                          child: Text(
                            MaterialLocalizations.of(context)
                                .formatMediumDate(task.scheduledAt!),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      _TaskCard(
                        task: task,
                        controller: controller,
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => _TaskDetailSheet(
                            task: task,
                            controller: controller,
                          ),
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
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.controller,
    required this.onTap,
  });

  final TaskModel task;
  final MobileTaskController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.snapshot;
    final categories = task.categoryIds
        .map((id) => snapshot?.categoryById(id))
        .whereType<CategoryModel>()
        .toList();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 48,
                decoration: BoxDecoration(
                  color: categories.isEmpty
                      ? _priorityColor(task.priority)
                      : categories.first.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (task.scheduledAt != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        _dateTimeLabel(context, task.scheduledAt!),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (categories.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        children: categories
                            .map(
                              (category) => Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(category.name),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              if (task.reminderRules.any((rule) => rule.enabled))
                Icon(
                  task.reminderRules.any((rule) => rule.isImportant)
                      ? Icons.alarm_rounded
                      : Icons.notifications_none_rounded,
                  color: task.reminderRules.any((rule) => rule.isImportant)
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskDetailSheet extends StatelessWidget {
  const _TaskDetailSheet({required this.task, required this.controller});

  final TaskModel task;
  final MobileTaskController controller;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.snapshot;
    final projects = task.projectIds
        .map((id) => snapshot?.projectById(id))
        .whereType<ProjectModel>()
        .toList();
    final categories = task.categoryIds
        .map((id) => snapshot?.categoryById(id))
        .whereType<CategoryModel>()
        .toList();
    final subtasks = snapshot?.subtasksOf(task) ?? const <TaskModel>[];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 36),
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(task.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          const Chip(
            avatar: Icon(Icons.lock_outline_rounded, size: 17),
            label: Text('Solo lectura'),
          ),
          if (task.description?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 18),
            Text(task.description!),
          ],
          if (task.scheduledAt != null)
            _DetailRow(
              icon: Icons.schedule_rounded,
              label: _dateTimeLabel(context, task.scheduledAt!),
            ),
          if (projects.isNotEmpty)
            _DetailRow(
              icon: Icons.folder_open_rounded,
              label: projects.map((value) => value.name).join(', '),
            ),
          if (categories.isNotEmpty)
            _DetailRow(
              icon: Icons.label_outline_rounded,
              label: categories.map((value) => value.name).join(', '),
            ),
          if (task.recurrence.isRecurring)
            _DetailRow(
              icon: Icons.repeat_rounded,
              label: _recurrenceLabel(task.recurrence),
            ),
          if (task.reminderRules.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('Avisos', style: TextStyle(fontWeight: FontWeight.w700)),
            for (final reminder in task.reminderRules)
              _DetailRow(
                icon: reminder.isImportant
                    ? Icons.alarm_rounded
                    : Icons.notifications_none_rounded,
                label: _reminderLabel(reminder),
              ),
          ],
          if (subtasks.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('Subtareas',
                style: TextStyle(fontWeight: FontWeight.w700)),
            for (final subtask in subtasks)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: subtask.status == TaskStatus.completed,
                onChanged: null,
                title: Text(subtask.title),
              ),
          ],
          if (task.checklist.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('Lista', style: TextStyle(fontWeight: FontWeight.w700)),
            for (final item in task.checklist)
              _DetailRow(
                  icon: Icons.check_box_outline_blank_rounded, label: item),
          ],
          if (task.materials.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('Materiales',
                style: TextStyle(fontWeight: FontWeight.w700)),
            for (final item in task.materials)
              _DetailRow(icon: Icons.inventory_2_outlined, label: item),
          ],
        ],
      ),
    );
  }
}

class _MobileSettingsPage extends StatelessWidget {
  const _MobileSettingsPage({required this.controller});

  final MobileTaskController controller;

  @override
  Widget build(BuildContext context) {
    final config = controller.config;
    final permissions = controller.permissions;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Text('Ajustes', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ordenador emparejado',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(config?.endpoint ?? 'Sin dirección'),
                const SizedBox(height: 4),
                Text(
                  config?.lastSyncAt == null
                      ? 'Todavía no se ha sincronizado.'
                      : 'Última sincronización: ${_dateTimeLabel(context, config!.lastSyncAt!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                FilledButton.tonalIcon(
                  onPressed: controller.syncing ? null : controller.syncAll,
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Actualizar ahora'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alarmas y recordatorios',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  permissions == null
                      ? 'Comprueba los permisos para recibir avisos y mostrar alarmas importantes sobre la pantalla bloqueada.'
                      : permissions.fullyGranted
                          ? 'Todos los permisos necesarios están concedidos.'
                          : 'Falta algún permiso especial. Las alarmas se mostrarán como notificaciones destacadas cuando Android no permita la pantalla completa.',
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: controller.requestNotificationPermissions,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Comprobar permisos'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => _confirmDisconnect(context),
          icon: const Icon(Icons.link_off_rounded),
          label: const Text('Desconectar este móvil'),
        ),
      ],
    );
  }

  Future<void> _confirmDisconnect(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desconectar móvil'),
        content: const Text(
          'Se eliminarán de este móvil las tareas, la ropa descargada, las marcas de uso de las maletas, la credencial y los avisos programados. Los datos del ordenador no cambiarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.disconnect();
  }
}

class _MobileAlarmOverlay extends StatelessWidget {
  const _MobileAlarmOverlay({
    required this.title,
    required this.body,
    required this.onStop,
    required this.onSnooze,
    required this.onOpen,
  });

  final String title;
  final String body;
  final Future<void> Function() onStop;
  final Future<void> Function() onSnooze;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xEE241E1A),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.alarm_rounded, size: 76, color: Colors.white),
              const SizedBox(height: 28),
              const Text(
                'Alarma importante',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(body, style: const TextStyle(color: Colors.white70)),
              ],
              const SizedBox(height: 38),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Detener'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style:
                      OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: onSnooze,
                  icon: const Icon(Icons.snooze_rounded),
                  label: const Text('Posponer 5 minutos'),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: onOpen,
                child: const Text('Ver tarea'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.text,
    this.error = false,
  });

  final IconData icon;
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.secondaryContainer;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt_rounded, size: 58),
            SizedBox(height: 14),
            Text('No hay tareas en esta vista.'),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

String _dateTimeLabel(BuildContext context, DateTime value) {
  final date = MaterialLocalizations.of(context).formatMediumDate(value);
  if (value.hour == 0 && value.minute == 0) return date;
  final time = MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(value),
  );
  return '$date · $time';
}

String _reminderLabel(ReminderRule reminder) {
  final timing = reminder.minutesBefore == 0
      ? 'A la hora exacta'
      : reminder.minutesBefore < 60
          ? '${reminder.minutesBefore} minutos antes'
          : reminder.minutesBefore == 60
              ? '1 hora antes'
              : '${reminder.minutesBefore ~/ 60} horas antes';
  return reminder.isImportant ? '$timing · Importante' : timing;
}

String _recurrenceLabel(RecurrenceRule recurrence) => switch (recurrence.type) {
      RecurrenceType.none => 'Sin repetición',
      RecurrenceType.daily => 'Todos los días',
      RecurrenceType.everyXDays => 'Cada ${recurrence.interval} días',
      RecurrenceType.weekly => recurrence.interval == 1
          ? 'Cada semana'
          : 'Cada ${recurrence.interval} semanas',
      RecurrenceType.monthly => recurrence.interval == 1
          ? 'Cada mes'
          : 'Cada ${recurrence.interval} meses',
      RecurrenceType.yearly => recurrence.interval == 1
          ? 'Cada año'
          : 'Cada ${recurrence.interval} años',
    };

Color _priorityColor(TaskPriority priority) => switch (priority) {
      TaskPriority.low => const Color(0xFF6D815A),
      TaskPriority.medium => const Color(0xFFB18A51),
      TaskPriority.high => const Color(0xFFB46E54),
      TaskPriority.urgent => const Color(0xFF9D4436),
    };

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;
