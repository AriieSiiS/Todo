part of 'app_shell.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    required this.launchIntent,
    super.key,
  });

  final AppLaunchIntent launchIntent;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final AmbientMusicController _musicController;
  late final bool _shouldInitializeMusic;
  bool _launchIntentHandled = false;

  TodoWorkspace get controller => ref.read(todoWorkspaceProvider);

  @override
  void initState() {
    super.initState();
    _shouldInitializeMusic = !_isWidgetTest();
    _musicController = AmbientMusicController(enabled: _shouldInitializeMusic);
    if (_shouldInitializeMusic) {
      _musicController.initialize();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleLaunchIntent());
  }

  @override
  void dispose() {
    _musicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(todoWorkspaceProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final visuals = context.visuals;

    return Scaffold(
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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                  child: _ShellFrame(
                    visuals: visuals,
                    child: AnimatedSwitcher(
                      duration:
                          Duration(milliseconds: visuals.isPhantom ? 180 : 220),
                      switchInCurve: visuals.isPhantom
                          ? Curves.easeOutExpo
                          : Curves.easeOutCubic,
                      switchOutCurve: visuals.isPhantom
                          ? Curves.easeInExpo
                          : Curves.easeInCubic,
                      child: _sectionView(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: wide ? null : _MobileNav(controller: controller),
    );
  }

  Widget _sectionView(BuildContext context) {
    return switch (controller.section) {
      AppSection.today => TodayPage(controller: controller),
      AppSection.projects => ProjectsPage(controller: controller),
      AppSection.categories => CategoriesPage(controller: controller),
      AppSection.expenses => ExpensesPage(controller: controller),
      AppSection.calendar => CalendarPage(controller: controller),
      AppSection.library => LibraryPage(controller: controller),
      AppSection.inbox => InboxPage(controller: controller),
      AppSection.completed => CompletedPage(controller: controller),
      AppSection.settings => SettingsPage(controller: controller),
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
    final destinations = <({AppSection section, IconData icon, String label})>[
      (section: AppSection.today, icon: Icons.today_rounded, label: 'Hoy'),
      (
        section: AppSection.inbox,
        icon: Icons.note_alt_outlined,
        label: 'Entrada'
      ),
      (
        section: AppSection.projects,
        icon: Icons.folder_open_rounded,
        label: 'Proyectos'
      ),
      (
        section: AppSection.categories,
        icon: Icons.category_rounded,
        label: 'Categorías'
      ),
      (
        section: AppSection.expenses,
        icon: Icons.receipt_long_rounded,
        label: 'Gastos y pagos'
      ),
      (
        section: AppSection.calendar,
        icon: Icons.calendar_month_rounded,
        label: 'Calendario'
      ),
      (
        section: AppSection.library,
        icon: Icons.local_library_rounded,
        label: 'Biblioteca'
      ),
      (
        section: AppSection.completed,
        icon: Icons.done_all_rounded,
        label: 'Completadas'
      ),
      (
        section: AppSection.settings,
        icon: Icons.tune_rounded,
        label: 'Ajustes'
      ),
    ];
    return SizedBox(
      width: 230,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 0, 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: visuals.sidebar,
            borderRadius: BorderRadius.circular(visuals.isPhantom ? 0 : 30),
            border: Border.all(
                color:
                    visuals.isPhantom ? visuals.pageBorder : Colors.transparent,
                width: visuals.isPhantom ? 1.6 : 0),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.home_outlined,
                            color: visuals.isPhantom
                                ? visuals.textStrong
                                : const Color(0xFFF5E9D8),
                            size: visuals.isPhantom ? 28 : 26,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Todo',
                              style: TextStyle(
                                color: visuals.isPhantom
                                    ? visuals.textStrong
                                    : const Color(0xFFF5E9D8),
                                fontSize: visuals.isPhantom ? 34 : 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: visuals.isPhantom ? 1.2 : 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        visuals.isPhantom ? 'Todo' : 'Un lugar, todo en orden.',
                        style: TextStyle(
                          color: visuals.isPhantom
                              ? visuals.textStrong
                              : const Color(0xFFB9C1B6),
                          fontSize: visuals.isPhantom ? 44 : 14,
                          fontWeight: visuals.isPhantom
                              ? FontWeight.w700
                              : FontWeight.w500,
                          letterSpacing: visuals.isPhantom ? 1.2 : 0,
                        ),
                      ),
                      if (visuals.isPhantom) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Casa, autocuidado y calendario en un solo lugar.',
                          style: TextStyle(
                            color: visuals.textMuted,
                            fontSize: 13.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: destinations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = destinations[index];
                      final selected = controller.section == item.section;
                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => controller.setSection(item.section),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                visuals.isPhantom ? 0 : 18),
                            color: selected
                                ? visuals.sidebarAccent
                                : Colors.transparent,
                            border: visuals.isPhantom && selected
                                ? Border(
                                    left: BorderSide(
                                        color: visuals.accentAlt, width: 5),
                                    bottom: BorderSide(
                                        color: visuals.textStrong, width: 1.2),
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(item.icon,
                                  color: selected
                                      ? Colors.white
                                      : (visuals.isPhantom
                                          ? visuals.textMuted
                                          : const Color(0xFFC6CEBD))),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : (visuals.isPhantom
                                            ? visuals.textStrong
                                            : const Color(0xFFF1EADC)),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: visuals.isPhantom ? 0.5 : 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                AnimatedBuilder(
                  animation: musicController,
                  builder: (context, _) => _AmbientMusicPlayer(
                    controller: musicController,
                  ),
                ),
                const SizedBox(height: 12),
                _SidebarStatus(controller: controller),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarStatus extends StatelessWidget {
  const _SidebarStatus({required this.controller});

  final TodoWorkspace controller;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final cloudLabel =
        controller.cloudConnected ? 'Cuenta conectada' : 'Cuenta pendiente';
    final calendarLabel = controller.isCalendarConnected
        ? 'Google Calendar sincronizado'
        : 'Google Calendar pendiente';
    final alertsLabel = controller.notificationSettings.notificationsEnabled
        ? 'Avisos activos'
        : 'Avisos en pausa';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: visuals.isPhantom
            ? visuals.panelAlt
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(visuals.isPhantom ? 0 : 18),
        border: Border.all(
            color: visuals.isPhantom
                ? visuals.textStrong
                : Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SidebarStatusRow(
            icon: Icons.person_rounded,
            label: cloudLabel,
            active: controller.cloudConnected,
          ),
          const SizedBox(height: 8),
          _SidebarStatusRow(
            icon: Icons.calendar_month_rounded,
            label: calendarLabel,
            active: controller.isCalendarConnected,
          ),
          const SizedBox(height: 8),
          _SidebarStatusRow(
            icon: Icons.notifications_active_rounded,
            label: alertsLabel,
            active: controller.notificationSettings.notificationsEnabled,
          ),
        ],
      ),
    );
  }
}

class _SidebarStatusRow extends StatelessWidget {
  const _SidebarStatusRow({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final textColor =
        visuals.isPhantom ? visuals.textStrong : const Color(0xFFF1EADC);
    final iconColor =
        visuals.isPhantom ? visuals.accentAlt : const Color(0xFFC6CEBD);
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: textColor, fontSize: 12.6, height: 1.25),
          ),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? const Color(0xFF8DCD67)
                : Colors.white.withValues(alpha: 0.28),
          ),
        ),
      ],
    );
  }
}

class _MobileNav extends StatelessWidget {
  const _MobileNav({required this.controller});

  final TodoWorkspace controller;

  @override
  Widget build(BuildContext context) {
    const sections = <AppSection>[
      AppSection.today,
      AppSection.inbox,
      AppSection.projects,
      AppSection.categories,
      AppSection.expenses,
      AppSection.calendar,
      AppSection.library,
      AppSection.completed,
      AppSection.settings,
    ];
    return NavigationBar(
      selectedIndex: sections.contains(controller.section)
          ? sections.indexOf(controller.section)
          : 0,
      onDestinationSelected: (index) => controller.setSection(sections[index]),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.today_rounded), label: 'Hoy'),
        NavigationDestination(
            icon: Icon(Icons.note_alt_outlined), label: 'Entrada'),
        NavigationDestination(
            icon: Icon(Icons.folder_open_rounded), label: 'Proyectos'),
        NavigationDestination(
            icon: Icon(Icons.category_rounded), label: 'Categorías'),
        NavigationDestination(
            icon: Icon(Icons.receipt_long_rounded), label: 'Gastos'),
        NavigationDestination(
            icon: Icon(Icons.calendar_month_rounded), label: 'Calendario'),
        NavigationDestination(
            icon: Icon(Icons.local_library_rounded), label: 'Biblioteca'),
        NavigationDestination(
            icon: Icon(Icons.done_all_rounded), label: 'Hechas'),
        NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Ajustes'),
      ],
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
        borderRadius: BorderRadius.circular(visuals.isPhantom ? 0 : 30),
        border: Border.all(
            color: visuals.pageBorder, width: visuals.isPhantom ? 2 : 1),
        boxShadow: visuals.isPhantom
            ? const [
                BoxShadow(
                  blurRadius: 0,
                  offset: Offset(14, 14),
                  color: Color(0xFF030303),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

extension on BuildContext {
  TodoVisuals get visuals => Theme.of(this).extension<TodoVisuals>()!;
}
