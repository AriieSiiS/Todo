part of 'app_shell.dart';

const bool _showAmbientMusic = false;

class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    required this.launchIntent,
    super.key,
  });

  final AppLaunchIntent launchIntent;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  late final HomeAssistantController _homeAssistant;
  late final AmbientMusicController _musicController;
  late final bool _shouldInitializeMusic;
  bool _launchIntentHandled = false;
  bool _openingNotificationTask = false;
  bool _quickCaptureOpen = false;
  final AudioPlayer _alarmPlayer = AudioPlayer();
  String? _playingAlarmId;
  bool _musicWasPlaying = false;

  TodoWorkspace get controller => ref.read(todoWorkspaceProvider);

  @override
  void initState() {
    super.initState();
    _homeAssistant = HomeAssistantController();
    if (Platform.isWindows && !_isWidgetTest()) {
      unawaited(_homeAssistant.initialize());
    }
    _shouldInitializeMusic = _showAmbientMusic && !_isWidgetTest();
    _musicController = AmbientMusicController(enabled: _shouldInitializeMusic);
    WidgetsBinding.instance.addObserver(this);
    if (_shouldInitializeMusic) {
      _musicController.initialize();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleLaunchIntent());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_alarmPlayer.dispose());
    _musicController.dispose();
    _homeAssistant.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && controller.cloudConnected) {
      unawaited(controller.syncWithCloud());
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(todoWorkspaceProvider);
    if (controller.pendingNotificationTaskId != null &&
        !_openingNotificationTask) {
      _openingNotificationTask = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openTaskFromNotification(),
      );
    }
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final visuals = context.visuals;
    final knowledgeItem = controller.openKnowledgeLibraryItem;
    final alarm = controller.currentImportantAlarm;
    if (_playingAlarmId != alarm?.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_syncAlarmPlayback(alarm));
      });
    }

    final scaffold = Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[visuals.backgroundStart, visuals.backgroundEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              _Sidebar(
                controller: controller,
                compact: !wide,
                musicController: _musicController,
              ),
              Expanded(
                child: Padding(
                  padding: knowledgeItem == null
                      ? const EdgeInsets.fromLTRB(20, 20, 20, 36)
                      : const EdgeInsets.fromLTRB(12, 18, 18, 24),
                  child: _ShellFrame(
                    visuals: visuals,
                    child: knowledgeItem == null
                        ? AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: _sectionView(context),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: KnowledgeWorkspacePage(
                              key: ValueKey(
                                  'knowledge-workspace-${knowledgeItem.id}'),
                              controller: controller,
                              libraryItem: knowledgeItem,
                              embedded: true,
                              onClose: controller.closeKnowledgeWorkspace,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: !wide &&
              knowledgeItem == null &&
              controller.section == AppSection.today
          ? FloatingActionButton(
              onPressed: () => showTaskEditor(context, controller),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      bottomNavigationBar: wide ? null : _MobileNav(controller: controller),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN,
            control: true, shift: true): _captureQuickNote,
      },
      child: Focus(
          autofocus: true,
          child: Stack(
            children: [
              scaffold,
              if (alarm != null)
                Positioned.fill(
                  child: _ImportantAlarmOverlay(
                    alarm: alarm,
                    remainingCount: controller.importantAlarmCount,
                    error: controller.importantAlarmError,
                    onStop: controller.stopImportantAlarm,
                    onSnooze: controller.snoozeImportantAlarm,
                    onOpenTask: () => _openImportantAlarmTask(alarm),
                  ),
                ),
            ],
          )),
    );
  }

  Future<void> _captureQuickNote() async {
    if (_quickCaptureOpen) return;
    _quickCaptureOpen = true;
    try {
      await showQuickNoteComposer(context, controller);
    } finally {
      _quickCaptureOpen = false;
    }
  }

  Future<void> _syncAlarmPlayback(ImportantAlarmOccurrence? alarm) async {
    if (_isWidgetTest()) {
      _playingAlarmId = alarm?.id;
      return;
    }
    if (alarm == null) {
      _playingAlarmId = null;
      await _alarmPlayer.stop();
      if (_musicWasPlaying) await _musicController.play();
      _musicWasPlaying = false;
      return;
    }
    _playingAlarmId = alarm.id;
    _musicWasPlaying = _musicController.isPlaying;
    if (_musicWasPlaying) await _musicController.pause();
    try {
      await _alarmPlayer.setAsset('resources/important-alarm.wav');
      await _alarmPlayer.setLoopMode(LoopMode.one);
      unawaited(_alarmPlayer.play());
    } catch (error) {
      controller.reportImportantAlarmAudioError(error);
    }
  }

  Future<void> _openImportantAlarmTask(
    ImportantAlarmOccurrence alarm,
  ) async {
    final task = controller.tasks.cast<TaskModel?>().firstWhere(
          (candidate) => candidate?.id == alarm.taskId,
          orElse: () => null,
        );
    await controller.stopImportantAlarm(keepApplicationOpen: true);
    if (mounted && task != null) {
      await showTaskEditor(context, controller, initialTask: task);
    }
  }

  Future<void> _openTaskFromNotification() async {
    final taskId = controller.takeNotificationTaskToOpen();
    if (!mounted || taskId == null) {
      _openingNotificationTask = false;
      return;
    }
    final task = controller.tasks.cast<TaskModel?>().firstWhere(
          (candidate) => candidate?.id == taskId,
          orElse: () => null,
        );
    if (task != null) {
      await showTaskEditor(context, controller, initialTask: task);
    }
    _openingNotificationTask = false;
  }

  Widget _sectionView(BuildContext context) {
    return switch (controller.section) {
      AppSection.today => TodayPage(controller: controller),
      AppSection.projects => ProjectsPage(controller: controller),
      AppSection.categories => CategoriesPage(controller: controller),
      AppSection.expenses => ExpensesPage(controller: controller),
      AppSection.calendar => CalendarPage(controller: controller),
      AppSection.library => LibraryPage(controller: controller),
      AppSection.wardrobe => WardrobePage(controller: controller),
      AppSection.household =>
        HouseholdPage(controller: controller, homeAssistant: _homeAssistant),
      AppSection.plants => PlantsPage(controller: controller),
      AppSection.recipes => RecipesPage(controller: controller),
      AppSection.inbox => InboxPage(controller: controller),
      AppSection.completed => CompletedPage(controller: controller),
      AppSection.settings =>
        SettingsPage(controller: controller, homeAssistant: _homeAssistant),
    };
  }

  bool _isWidgetTest() {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleLaunchIntent() async {
    if (_launchIntentHandled || !mounted) {
      return;
    }
    _launchIntentHandled = true;
    switch (widget.launchIntent.editorTarget) {
      case LaunchEditorTarget.none:
        return;
      case LaunchEditorTarget.task:
        await showTaskEditor(context, controller);
        return;
      case LaunchEditorTarget.project:
        await showProjectEditor(context, controller);
        return;
      case LaunchEditorTarget.category:
        await showCategoryEditor(context, controller);
        return;
    }
  }
}

class _ImportantAlarmOverlay extends StatelessWidget {
  const _ImportantAlarmOverlay({
    required this.alarm,
    required this.remainingCount,
    required this.error,
    required this.onStop,
    required this.onSnooze,
    required this.onOpenTask,
  });

  final ImportantAlarmOccurrence alarm;
  final int remainingCount;
  final String error;
  final Future<void> Function({bool keepApplicationOpen}) onStop;
  final Future<void> Function() onSnooze;
  final Future<void> Function() onOpenTask;

  @override
  Widget build(BuildContext context) {
    final hour = alarm.originalTriggerAt.hour.toString().padLeft(2, '0');
    final minute = alarm.originalTriggerAt.minute.toString().padLeft(2, '0');
    return Material(
      color: const Color(0xA6000000),
      child: Center(
        child: SizedBox(
          width: 520,
          height: 340,
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF4),
              borderRadius: BorderRadius.zero,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x52000000),
                  blurRadius: 40,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.alarm_rounded,
                        color: Color(0xFFB4422D), size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Alarma importante · $hour:$minute',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (remainingCount > 1) Text('$remainingCount pendientes'),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  alarm.taskTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'El sonido continuará hasta que confirmes esta alarma.',
                  style: TextStyle(color: Color(0xFF756D62)),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(error,
                      maxLines: 2,
                      style: const TextStyle(
                          color: Color(0xFF9D3F2C), fontSize: 12)),
                ],
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('important-alarm-stop'),
                        onPressed: () => onStop(),
                        child: const Text('Detener'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonal(
                        key: const ValueKey('important-alarm-snooze'),
                        onPressed: onSnooze,
                        child: const Text('Posponer 5 min'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('important-alarm-open-task'),
                        onPressed: onOpenTask,
                        child: const Text('Abrir tarea'),
                      ),
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
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.controller,
    required this.compact,
    required this.musicController,
  });

  final TodoWorkspace controller;
  final bool compact;
  final AmbientMusicController musicController;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    if (compact) {
      return const SizedBox.shrink();
    }
    final destinations =
        controller.visibleNavOrder.map(_sidebarDestinationFor).toList();
    return SizedBox(
      width: 230,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 0, 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: visuals.sidebar,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.transparent, width: 0),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 10, 6, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const _SidebarLogoMark(),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Todo',
                              style: TextStyle(
                                color: const Color(0xFFF5E9D8),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Un lugar, todo en orden.',
                        style: TextStyle(
                          color: const Color(0xFFB9C1B6),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: destinations.length,
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, index, animation) => Material(
                      color: Colors.transparent,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 1, end: 1.02)
                            .animate(animation),
                        child: child,
                      ),
                    ),
                    onReorder: controller.reorderNavigation,
                    itemBuilder: (context, index) {
                      final item = destinations[index];
                      final selected = controller.section == item.section;
                      return Padding(
                        key: ValueKey(item.section),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => controller.setSection(item.section),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.fromLTRB(9, 13, 7, 13),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: selected
                                  ? visuals.sidebarAccent
                                  : Colors.transparent,
                              border: null,
                            ),
                            child: Row(
                              children: [
                                Icon(item.icon,
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFFC6CEBD)),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFFF1EADC),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Icon(
                                      Icons.drag_indicator_rounded,
                                      size: 18,
                                      color: selected
                                          ? Colors.white.withValues(alpha: 0.72)
                                          : const Color(0xFFB9C1B6)
                                              .withValues(alpha: 0.58),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_showAmbientMusic) ...[
                  const SizedBox(height: 14),
                  AnimatedBuilder(
                    animation: musicController,
                    builder: (context, _) => _AmbientMusicPlayer(
                      controller: musicController,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarDestination {
  const _SidebarDestination({
    required this.section,
    required this.icon,
    required this.label,
  });

  final AppSection section;
  final IconData icon;
  final String label;
}

_SidebarDestination _sidebarDestinationFor(AppSection section) {
  return switch (section) {
    AppSection.today => const _SidebarDestination(
        section: AppSection.today,
        icon: Icons.today_rounded,
        label: 'Hoy',
      ),
    AppSection.inbox => const _SidebarDestination(
        section: AppSection.inbox,
        icon: Icons.note_alt_outlined,
        label: 'Notas',
      ),
    AppSection.projects => const _SidebarDestination(
        section: AppSection.projects,
        icon: Icons.folder_open_rounded,
        label: 'Proyectos',
      ),
    AppSection.categories => const _SidebarDestination(
        section: AppSection.categories,
        icon: Icons.category_rounded,
        label: 'Categorías',
      ),
    AppSection.expenses => const _SidebarDestination(
        section: AppSection.expenses,
        icon: Icons.receipt_long_rounded,
        label: 'Gastos y pagos',
      ),
    AppSection.calendar => const _SidebarDestination(
        section: AppSection.calendar,
        icon: Icons.calendar_month_rounded,
        label: 'Calendario',
      ),
    AppSection.library => const _SidebarDestination(
        section: AppSection.library,
        icon: Icons.local_library_rounded,
        label: 'Biblioteca',
      ),
    AppSection.wardrobe => const _SidebarDestination(
        section: AppSection.wardrobe,
        icon: Icons.checkroom_rounded,
        label: 'Ropa',
      ),
    AppSection.household => const _SidebarDestination(
        section: AppSection.household,
        icon: Icons.home_work_rounded,
        label: 'Hogar',
      ),
    AppSection.plants => const _SidebarDestination(
        section: AppSection.plants,
        icon: Icons.local_florist_rounded,
        label: 'Plantas',
      ),
    AppSection.recipes => const _SidebarDestination(
        section: AppSection.recipes,
        icon: Icons.restaurant_menu_rounded,
        label: 'Recetas',
      ),
    AppSection.completed => const _SidebarDestination(
        section: AppSection.completed,
        icon: Icons.done_all_rounded,
        label: 'Completadas',
      ),
    AppSection.settings => const _SidebarDestination(
        section: AppSection.settings,
        icon: Icons.tune_rounded,
        label: 'Ajustes',
      ),
  };
}

class _SidebarLogoMark extends StatelessWidget {
  const _SidebarLogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFF5E9D8), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/branding/todo_logo.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _MobileNav extends StatelessWidget {
  const _MobileNav({required this.controller});

  final TodoWorkspace controller;

  @override
  Widget build(BuildContext context) {
    final primarySections = const [
      AppSection.today,
      AppSection.inbox,
      AppSection.calendar,
      AppSection.projects,
    ].where(controller.visibilitySettings.sectionVisible).toList();
    if (primarySections.isEmpty) {
      return SafeArea(
        child: TextButton.icon(
          onPressed: () => _showMoreSections(context),
          icon: const Icon(Icons.menu_rounded),
          label: const Text('Secciones'),
        ),
      );
    }
    final selectedIndex = primarySections.contains(controller.section)
        ? primarySections.indexOf(controller.section)
        : primarySections.length;
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        if (index == primarySections.length) {
          _showMoreSections(context);
          return;
        }
        controller.setSection(primarySections[index]);
      },
      destinations: [
        for (final item in primarySections.map(_sidebarDestinationFor))
          NavigationDestination(icon: Icon(item.icon), label: item.label),
        const NavigationDestination(
          icon: Icon(Icons.more_horiz_rounded),
          label: 'Más',
        ),
      ],
    );
  }

  Future<void> _showMoreSections(BuildContext context) async {
    final moreSections = controller.visibleNavOrder
        .where((section) => !const {
              AppSection.today,
              AppSection.inbox,
              AppSection.calendar,
              AppSection.projects,
            }.contains(section))
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              for (final section in moreSections)
                ListTile(
                  leading: Icon(_sidebarDestinationFor(section).icon),
                  title: Text(_sidebarDestinationFor(section).label),
                  selected: controller.section == section,
                  onTap: () {
                    Navigator.of(context).pop();
                    controller.setSection(section);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AmbientMusicPlayer extends StatelessWidget {
  const _AmbientMusicPlayer({
    required this.controller,
  });

  final AmbientMusicController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = controller.duration;
    final position = controller.position > duration && duration != Duration.zero
        ? duration
        : controller.position;
    final progressMax =
        duration.inMilliseconds <= 0 ? 1.0 : duration.inMilliseconds.toDouble();
    final progressValue =
        position.inMilliseconds.clamp(0, progressMax.toInt()).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xB51C211D),
            Color(0xCC2E382A),
            Color(0xC26F533F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 20,
            offset: Offset(0, 10),
            color: Color(0x20000000),
          ),
        ],
      ),
      child: _integratedLayout(
        context,
        theme,
        progressValue,
        progressMax,
        position,
        duration,
      ),
    );
  }

  Widget _integratedLayout(
    BuildContext context,
    ThemeData theme,
    double progressValue,
    double progressMax,
    Duration position,
    Duration duration,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.album_rounded,
                color: Color(0xFFF5E9D8),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: const Color(0xFFFFF8ED)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: const Color(0xFFD7D1C6)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: controller.isReady
                  ? controller.togglePlayback
                  : controller.initialize,
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 36),
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                foregroundColor: const Color(0xFFFFF8ED),
              ),
              child: Icon(controller.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (controller.errorMessage != null) ...[
          Text(
            controller.errorMessage!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: const Color(0xFFFFD6C7)),
          ),
          const SizedBox(height: 8),
        ],
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFFFFE4BF),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
            thumbColor: const Color(0xFFFFF8ED),
            overlayColor: const Color(0x22FFF8ED),
            trackHeight: 4,
          ),
          child: Slider(
            value: progressValue,
            min: 0,
            max: progressMax,
            onChanged: controller.isReady
                ? (value) =>
                    controller.seek(Duration(milliseconds: value.round()))
                : null,
          ),
        ),
        Row(
          children: [
            Text(
              _formatDuration(position),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: const Color(0xFFE6DFD5)),
            ),
            const Spacer(),
            Text(
              _formatDuration(duration),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: const Color(0xFFE6DFD5)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          controller.isPlaying
              ? 'Sonando ahora en bucle.'
              : 'Listo para acompanar el foco.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: const Color(0xFFD7D1C6)),
        ),
      ],
    );
  }
}

class _ShellFrame extends StatelessWidget {
  const _ShellFrame({
    required this.visuals,
    required this.child,
  });

  final TodoVisuals visuals;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: visuals.pageSurface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: visuals.pageBorder),
      ),
      child: child,
    );
  }
}

extension on BuildContext {
  TodoVisuals get visuals => Theme.of(this).extension<TodoVisuals>()!;
}
