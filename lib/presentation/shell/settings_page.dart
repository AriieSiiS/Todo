part of 'app_shell.dart';

Future<void> _showVisibilityPreferences(
    BuildContext context, TodoWorkspace controller) {
  return showDialog<void>(
    context: context,
    builder: (context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) => AlertDialog(
        title: const Text('Secciones y pestañas'),
        content: SizedBox(
          width: 700,
          height: 600,
          child: ListView(
            children: [
              const Text(
                  'Ajustes estará siempre disponible. Cada sección conservará al menos una pestaña.'),
              const SizedBox(height: 12),
              for (final section in controller.navOrder)
                CheckboxListTile(
                  key: ValueKey('visible-section-${section.name}'),
                  title: Text(_sidebarDestinationFor(section).label),
                  value: controller.visibilitySettings.sectionVisible(section),
                  onChanged: section == AppSection.settings
                      ? null
                      : (value) =>
                          controller.setSectionVisible(section, value!),
                ),
              const Divider(height: 24),
              for (final entry in AppVisibilitySettings.tabs.entries)
                ExpansionTile(
                  key: ValueKey('visible-tabs-${entry.key.name}'),
                  title: Text(
                      'Pestañas de ${_sidebarDestinationFor(entry.key).label}'),
                  children: [
                    for (final tab in entry.value.entries)
                      CheckboxListTile(
                        key: ValueKey(
                            'visible-tab-${entry.key.name}-${tab.key}'),
                        title: Text(tab.value),
                        value: controller.visibilitySettings
                            .visibleTabs(entry.key)
                            .contains(tab.key),
                        onChanged: controller.visibilitySettings
                                        .visibleTabs(entry.key)
                                        .length ==
                                    1 &&
                                controller.visibilitySettings
                                    .visibleTabs(entry.key)
                                    .contains(tab.key)
                            ? null
                            : (value) => controller.setTabVisible(
                                entry.key, tab.key, value!),
                      ),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'))
        ],
      ),
    ),
  );
}

class _LanSyncNotice extends StatelessWidget {
  const _LanSyncNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.visuals.panelAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.visuals.panelBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: context.visuals.accent),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.controller,
    this.homeAssistant,
    this.backupService,
    super.key,
  });

  final TodoWorkspace controller;
  final HomeAssistantController? homeAssistant;
  final FullBackupService? backupService;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final FullBackupService _backupService;
  late final LanSyncDesktopService _lanSyncService;
  FullBackupOverview? _backupOverview;
  LanSyncDesktopStatus _lanSyncStatus =
      const LanSyncDesktopStatus.unavailable();
  bool _backupBusy = false;
  bool _lanSyncBusy = false;
  bool _kindleBackground = false;

  TodoWorkspace get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _backupService = widget.backupService ?? FullBackupService();
    _lanSyncService = LanSyncDesktopService();
    unawaited(_loadBackupOverview());
    if (!_isSettingsWidgetTest()) {
      unawaited(_loadLanSyncStatus());
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationSettings = controller.notificationSettings;
    final notificationScheduleLabel =
        _notificationScheduleLabel(controller, notificationSettings);
    final contentCount = controller.tasks.length +
        controller.projects.length +
        controller.categories.length +
        controller.notes.length +
        controller.expenses.length +
        controller.libraryItems.length +
        controller.libraryGoals.length +
        controller.wardrobeItems.length +
        controller.householdItems.length +
        controller.recipes.length +
        controller.weeklyMenus.length;
    final lastSavedAt = controller.lastSavedAt;

    final dayRules = _SettingsSectionCard(
      icon: Icons.schedule_rounded,
      title: 'Regla del día',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SettingsHourField(
                  key: const ValueKey('settings-day-end-hour'),
                  label: 'El día termina a las',
                  value: controller.daySettings.dayEndsAtHour,
                  firstHour: 0,
                  lastHour: 12,
                  onChanged: (value) => controller.updateSettings(
                    controller.daySettings.copyWith(dayEndsAtHour: value),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SettingsHourField(
                  key: const ValueKey('settings-next-day-hour'),
                  label: 'Adelantar el próximo día desde',
                  value: controller.daySettings.nextDayVisibleAtHour,
                  firstHour: 5,
                  lastHour: 14,
                  onChanged: (value) => controller.updateSettings(
                    controller.daySettings
                        .copyWith(nextDayVisibleAtHour: value),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 34),
          _settingsActionRow(
            title: controller.hasManualLogicalDate
                ? 'Día cambiado manualmente'
                : 'Cambiar el día actual',
            buttonLabel: 'Día siguiente',
            icon: Icons.skip_next_rounded,
            onPressed: controller.advanceToNextLogicalDay,
            previousButtonLabel: 'Día anterior',
            previousIcon: Icons.skip_previous_rounded,
            onPreviousPressed: controller.moveToPreviousLogicalDay,
            secondaryButtonLabel:
                controller.hasManualLogicalDate ? 'Volver a automático' : null,
            secondaryIcon: Icons.undo_rounded,
            onSecondaryPressed: controller.hasManualLogicalDate
                ? controller.clearManualLogicalDate
                : null,
          ),
        ],
      ),
    );

    final wardrobe = _SettingsSectionCard(
      icon: Icons.checkroom_outlined,
      title: 'Ropa',
      child: _settingsToggleRow(
        title: 'Mostrar número de usos',
        value: controller.wardrobeDisplaySettings.showUsageCount,
        onChanged: (value) {
          controller.updateWardrobeDisplaySettings(
            controller.wardrobeDisplaySettings.copyWith(showUsageCount: value),
          );
          setState(() {});
        },
      ),
    );

    final visibility = _SettingsSectionCard(
      icon: Icons.visibility_outlined,
      title: 'Secciones y pestañas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Personalizar'),
            onPressed: () => _showVisibilityPreferences(context, controller),
          ),
        ],
      ),
    );

    final steam = _SettingsSectionCard(
      icon: Icons.sports_esports_outlined,
      title: 'Steam',
      child: SteamSettingsPanel(service: controller.steam),
    );

    final notifications = _SettingsSectionCard(
      icon: Icons.notifications_active_outlined,
      title: 'Notificaciones',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _settingsToggleRow(
            title: 'Activar recordatorios',
            value: notificationSettings.notificationsEnabled,
            onChanged: (value) async {
              if (value) {
                final granted =
                    await controller.requestNotificationPermissions();
                if (!granted || !context.mounted) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          controller.notificationError.isEmpty
                              ? 'No se han podido activar las notificaciones.'
                              : controller.notificationError,
                        ),
                      ),
                    );
                  }
                  return;
                }
              }
              await controller.updateNotificationSettings(
                controller.notificationSettings.copyWith(
                  notificationsEnabled: value,
                ),
              );
            },
          ),
          if (notificationSettings.notificationsEnabled) ...[
            const Divider(height: 30),
            _settingsToggleRow(
              title: 'Comienzo del día',
              value: notificationSettings.dayStartReminderEnabled,
              onChanged: (value) => controller.updateNotificationSettings(
                controller.notificationSettings.copyWith(
                  dayStartReminderEnabled: value,
                ),
              ),
            ),
            const Divider(height: 30),
            _settingsToggleRow(
              title: 'Cierre del día',
              value: notificationSettings.dayEndReminderEnabled,
              onChanged: (value) => controller.updateNotificationSettings(
                controller.notificationSettings.copyWith(
                  dayEndReminderEnabled: value,
                ),
              ),
            ),
            const Divider(height: 30),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recordatorio predeterminado',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<int>(
                    key: const ValueKey('settings-default-reminder'),
                    isExpanded: true,
                    initialValue: notificationSettings.defaultMinutesBeforeTask,
                    items: const [
                      DropdownMenuItem(
                          value: 0, child: Text('A la hora exacta')),
                      DropdownMenuItem(value: 5, child: Text('5 minutos')),
                      DropdownMenuItem(value: 15, child: Text('15 minutos')),
                      DropdownMenuItem(value: 30, child: Text('30 minutos')),
                      DropdownMenuItem(value: 60, child: Text('1 hora')),
                      DropdownMenuItem(value: 1440, child: Text('1 día')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        controller.updateNotificationSettings(
                          controller.notificationSettings.copyWith(
                            defaultMinutesBeforeTask: value,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                key: const ValueKey('settings-test-notification'),
                onPressed: controller.notificationBusy
                    ? null
                    : () async {
                        final shown = await controller.sendTestNotification();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              shown
                                  ? 'Notificación de prueba enviada.'
                                  : 'No se pudo mostrar la notificación.',
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('Enviar prueba'),
              ),
              FilledButton.icon(
                key: const ValueKey('settings-test-important-alarm'),
                onPressed: controller.notificationBusy
                    ? null
                    : () async {
                        await controller.showImportantAlarmTest();
                        if (!context.mounted ||
                            controller.importantAlarmError.isEmpty) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(controller.importantAlarmError),
                          ),
                        );
                      },
                icon: const Icon(Icons.alarm_rounded, size: 18),
                label: const Text('Probar alarma importante'),
              ),
              Text(
                controller.notificationError.isNotEmpty
                    ? controller.notificationError
                    : notificationScheduleLabel,
                style: TextStyle(
                  color: controller.notificationError.isEmpty
                      ? context.visuals.textMuted
                      : const Color(0xFF9D5D3A),
                  fontSize: 13,
                ),
              ),
              if (controller.notificationError.contains('Windows'))
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse('ms-settings:notifications'),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('Abrir ajustes de Windows'),
                ),
            ],
          ),
        ],
      ),
    );

    final data = _SettingsSectionCard(
      icon: Icons.storage_rounded,
      title: 'Datos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => _showExport(context),
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: const Text('Exportar datos'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _showImport(context),
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('Importar datos'),
              ),
              OutlinedButton.icon(
                onPressed: () => _confirmReset(context),
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('Reiniciar datos'),
              ),
            ],
          ),
        ],
      ),
    );

    final androidConnection = _SettingsSectionCard(
      icon: Icons.phonelink_rounded,
      title: 'Conexión Android',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_lanSyncBusy)
            const Center(child: CircularProgressIndicator())
          else if (!_lanSyncStatus.running)
            _LanSyncNotice(
              icon: Icons.sync_problem_rounded,
              text: _lanSyncStatus.error.isEmpty
                  ? 'El agente local no está disponible.'
                  : _lanSyncStatus.error,
            )
          else ...[
            _LanSyncNotice(
              icon: Icons.lock_rounded,
              text: _lanSyncStatus.endpoint.isEmpty
                  ? 'Agente activo; esperando una dirección de red privada.'
                  : 'Agente cifrado activo en ${_lanSyncStatus.endpoint}',
            ),
            const SizedBox(height: 16),
            if (_lanSyncStatus.pairingAvailable) ...[
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(
                    data: _lanSyncStatus.qrPayload,
                    size: 210,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'Escanea este código desde Todo en Android. Caduca a las ${_timeLabel(_lanSyncStatus.pairingExpiresAt!)}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.visuals.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: _lanSyncStatus.qrPayload),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Código manual copiado.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copiar código manual'),
                ),
              ),
            ] else
              const _LanSyncNotice(
                icon: Icons.hourglass_empty_rounded,
                text:
                    'El código está renovándose. Actualiza dentro de unos segundos.',
              ),
            if (_lanSyncStatus.devices.any((device) => device.profile == 'android')) ...[
              const Divider(height: 30),
              const Text(
                'Dispositivos emparejados',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final device in _lanSyncStatus.devices.where((device) => device.profile == 'android'))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.smartphone_rounded),
                  title: Text(device.name),
                  subtitle: Text(
                    device.pairedAt == null
                        ? 'Emparejado'
                        : 'Emparejado el ${_dateLabel(device.pairedAt!)}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Revocar acceso',
                    onPressed: () => _revokeLanSyncDevice(device),
                    icon: const Icon(Icons.link_off_rounded),
                  ),
                ),
            ],
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _lanSyncBusy ? null : _loadLanSyncStatus,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Actualizar estado'),
          ),
        ],
      ),
    );

    final kindleConnection = _SettingsSectionCard(
      icon: Icons.menu_book_rounded,
      title: 'Conexión Kindle',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Conexión Kindle con Todo cerrado'),
          value: _kindleBackground,
          onChanged: _lanSyncBusy ? null : (enabled) async {
            await _lanSyncService.setKindleBackgroundEnabled(enabled);
            if (mounted) setState(() => _kindleBackground = enabled);
          },
        ),
        for (final device in _lanSyncStatus.devices.where((device) => device.profile == 'kindle'))
          ListTile(contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.menu_book_rounded), title: Text(device.name),
            trailing: IconButton(tooltip: 'Revocar acceso',
              onPressed: () => _revokeLanSyncDevice(device), icon: const Icon(Icons.link_off_rounded))),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.usb_rounded), label: const Text('Instalar o actualizar por USB'),
          onPressed: _lanSyncBusy ? null : _installKindle,
        ),
      ]),
    );

    final backup = _SettingsSectionCard(
      icon: Icons.backup_outlined,
      title: 'Copias de seguridad',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackupStatusPanel(
            overview: _backupOverview,
            destinationPath: _backupService.destinationRoot.path,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const ValueKey('settings-create-full-backup'),
                onPressed: !_backupService.isSupported || _backupBusy
                    ? null
                    : _confirmFullBackup,
                icon: _backupBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_to_drive_outlined, size: 18),
                label: Text(_backupBusy ? 'Preparando…' : 'Crear copia ahora'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('settings-open-backup-folder'),
                onPressed: _backupService.isSupported && !_backupBusy
                    ? _openBackupFolder
                    : null,
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                label: const Text('Abrir carpeta'),
              ),
            ],
          ),
        ],
      ),
    );

    final status = _SettingsAsideCard(
      title: 'Estado del sistema',
      icon: Icons.shield_outlined,
      children: [
        _SettingsStatusItem(
          icon: Icons.save_outlined,
          title: 'Guardado local',
          subtitle: lastSavedAt == null
              ? 'Guardado automático activo'
              : 'Último guardado: ${_timeLabel(lastSavedAt)}',
          active: true,
        ),
        _SettingsStatusItem(
          icon: Icons.inventory_2_outlined,
          title: 'Contenido cargado',
          subtitle: '$contentCount elementos en la app',
          active: true,
        ),
        _SettingsStatusItem(
          icon: Icons.backup_outlined,
          title: 'Copia completa',
          subtitle: _backupStatusSubtitle(_backupOverview),
          active: _backupOverview?.latest != null &&
              _backupOverview?.errorMessage == null,
        ),
        _SettingsStatusItem(
          icon: Icons.notifications_none_rounded,
          title: 'Avisos del sistema',
          subtitle: notificationSettings.notificationsEnabled
              ? controller.notificationError.isEmpty
                  ? notificationScheduleLabel
                  : 'Necesita atención'
              : 'Desactivados',
          active: notificationSettings.notificationsEnabled &&
              controller.notificationError.isEmpty,
        ),
      ],
    );

    const tips = _SettingsAsideCard(
      title: 'Consejos y atajos',
      icon: Icons.tips_and_updates_outlined,
      children: [
        _SettingsHintRow(
          icon: Icons.keyboard_rounded,
          text: 'Ctrl + Mayús + N abre una nota desde cualquier sección.',
        ),
        _SettingsHintRow(
          icon: Icons.bolt_rounded,
          text:
              'Ctrl + Alt + N abre la nota rápida desde cualquier programa de Windows.',
        ),
        _SettingsHintRow(
          icon: Icons.picture_in_picture_alt_rounded,
          text:
              'El botón de modo mini, junto al nombre de Todo, deja Hoy a un lado de la pantalla.',
        ),
        _SettingsHintRow(
          icon: Icons.open_with_rounded,
          text: 'Arrastra las tareas de Hoy para cambiar su orden.',
        ),
        _SettingsHintRow(
          icon: Icons.mouse_outlined,
          text:
              'En Biblioteca, usa el clic derecho para editar o completar rápidamente.',
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: const _PageHeader(
              title: 'Ajustes',
              subtitle: '',
              compact: true,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 1040) {
                  return ListView(
                    children: [
                      dayRules,
                      const SizedBox(height: 16),
                      notifications,
                      const SizedBox(height: 16),
                      androidConnection,
                      const SizedBox(height: 16),
                      kindleConnection,
                      const SizedBox(height: 16),
                      steam,
                      const SizedBox(height: 16),
                      wardrobe,
                      const SizedBox(height: 16),
                      visibility,
                      const SizedBox(height: 16),
                      backup,
                      const SizedBox(height: 16),
                      data,
                      const SizedBox(height: 16),
                      status,
                      const SizedBox(height: 16),
                      tips,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          dayRules,
                          const SizedBox(height: 16),
                          notifications,
                          const SizedBox(height: 16),
                          androidConnection,
                          const SizedBox(height: 16),
                          kindleConnection,
                          const SizedBox(height: 16),
                          steam,
                          const SizedBox(height: 16),
                          backup,
                          const SizedBox(height: 16),
                          data,
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    SizedBox(
                      width: 360,
                      child: ListView(
                        children: [
                          wardrobe,
                          const SizedBox(height: 16),
                          visibility,
                          const SizedBox(height: 16),
                          status,
                          const SizedBox(height: 16),
                          tips,
                        ],
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

  Future<void> _loadBackupOverview() async {
    final overview = await _backupService.loadOverview();
    if (!mounted) return;
    setState(() => _backupOverview = overview);
  }

  Future<void> _loadLanSyncStatus() async {
    if (!Platform.isWindows || _isSettingsWidgetTest()) return;
    setState(() => _lanSyncBusy = true);
    final status = await _lanSyncService.loadStatus();
    final resident = await _lanSyncService.kindleBackgroundEnabled();
    if (!mounted) return;
    setState(() {
      _lanSyncStatus = status;
      _kindleBackground = resident;
      _lanSyncBusy = false;
    });
  }

  bool _isSettingsWidgetTest() {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  Future<void> _installKindle() async {
    final directory = await getDirectoryPath(confirmButtonText: 'Seleccionar Kindle');
    if (directory == null || !mounted) return;
    setState(() => _lanSyncBusy = true);
    try {
      await _lanSyncService.loadStatus();
      await _lanSyncService.installKindle(directory);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:
          Text('Complemento copiado y verificado. Expulsa el Kindle y abre Todo desde KOReader para comprobar la conexión.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) await _loadLanSyncStatus();
    }
  }

  Future<void> _revokeLanSyncDevice(LanSyncPairedDevice device) async {
    await _lanSyncService.revokeDevice(device.id);
    await _loadLanSyncStatus();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Acceso revocado para ${device.name}.')),
    );
  }

  Future<void> _confirmFullBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Crear copia de seguridad'),
        content: const Text(
          'Todo guardará los cambios pendientes, se cerrará y creará una copia completa verificada. La aplicación volverá a abrirse en Ajustes cuando termine.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.backup_outlined, size: 18),
            label: const Text('Cerrar y crear copia'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _backupBusy = true);
    try {
      await controller.flushPendingChanges();
      await _backupService.scheduleAfterAppCloses();
      await SystemNavigator.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _backupBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo iniciar la copia: ${_friendlyBackupError(error)}',
          ),
        ),
      );
      await _loadBackupOverview();
    }
  }

  Future<void> _openBackupFolder() async {
    try {
      await _backupService.openBackupFolder();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo abrir la carpeta: ${_friendlyBackupError(error)}',
          ),
        ),
      );
    }
  }

  void _showExport(BuildContext context) {
    final snapshot = controller.exportSnapshot().toPrettyJson();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exportar JSON'),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(child: SelectableText(snapshot)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Guarda una copia del estado actual antes de un cambio grande. Si no se
  /// puede guardar, avisa y devuelve `null` para que no se siga adelante.
  Future<File?> _saveCopyBeforeChange(String label) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      return await _backupService.saveSnapshotBeforeChange(
        controller.exportSnapshot().toPrettyJson(),
        label: label,
      );
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'No se ha cambiado nada: no se pudo guardar la copia previa. $error',
          ),
        ),
      );
      return null;
    }
  }

  Future<bool> _confirmDataReplacement({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(
          '$message\n\nAntes se guardará una copia del estado actual en '
          '«${_backupService.snapshotsBeforeChangesDirectory.path}».',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('confirm-data-replacement'),
            style: FilledButton.styleFrom(
              backgroundColor: dialogContext.visuals.danger,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  void _showImport(BuildContext context) {
    final importController = TextEditingController();
    String? error;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Importar JSON'),
          content: SizedBox(
            width: 720,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: importController,
                  minLines: 12,
                  maxLines: 20,
                  decoration: const InputDecoration(
                    hintText: 'Pega aquí un snapshot completo en JSON',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!,
                      style: TextStyle(color: dialogContext.visuals.danger)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const ValueKey('import-json-continue'),
              onPressed: () async {
                final raw = importController.text;
                try {
                  AppStateSnapshot.fromJson(
                    (jsonDecode(raw) as Map<dynamic, dynamic>)
                        .cast<String, dynamic>(),
                  );
                } catch (_) {
                  setDialogState(() => error =
                      'Ese texto no es un snapshot JSON válido. No se ha cambiado nada.');
                  return;
                }
                final confirmed = await _confirmDataReplacement(
                  title: 'Sustituir todos los datos',
                  message:
                      'Todos los datos actuales se sustituirán por los del JSON pegado.',
                  confirmLabel: 'Sustituir',
                );
                if (!confirmed || !mounted) return;
                final copy = await _saveCopyBeforeChange('importar-json');
                if (copy == null || !mounted) return;
                final ok = controller.importStateFromJson(raw);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Estado importado. La copia previa está en ${copy.path}.'
                        : 'No se pudo importar ese JSON. No se ha cambiado nada.'),
                  ),
                );
              },
              child: const Text('Importar'),
            ),
          ],
        ),
      ),
    ).whenComplete(importController.dispose);
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await _confirmDataReplacement(
      title: 'Reiniciar datos',
      message:
          'Esto sustituirá tu estado actual por la base inicial de la app.',
      confirmLabel: 'Reiniciar',
    );
    if (!confirmed || !mounted) return;
    final copy = await _saveCopyBeforeChange('reiniciar-datos');
    if (copy == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(this.context);
    await controller.resetToSeed();
    messenger.showSnackBar(
      SnackBar(
        content:
            Text('Datos reiniciados. La copia previa está en ${copy.path}.'),
      ),
    );
  }
}

class _SettingsHourField extends StatelessWidget {
  const _SettingsHourField({
    required this.label,
    required this.value,
    required this.firstHour,
    required this.lastHour,
    required this.onChanged,
    super.key,
  });

  final String label;
  final int value;
  final int firstHour;
  final int lastHour;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [for (var hour = firstHour; hour <= lastHour; hour++) hour];
    final selected = options.contains(value) ? value : options.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: selected,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.schedule_rounded),
          ),
          items: [
            for (final hour in options)
              DropdownMenuItem(
                value: hour,
                child: Text('${hour.toString().padLeft(2, '0')}:00'),
              ),
          ],
          onChanged: (next) {
            if (next != null) {
              onChanged(next);
            }
          },
        ),
      ],
    );
  }
}

String _notificationScheduleLabel(
  TodoWorkspace controller,
  DeviceNotificationSettings settings,
) {
  if (!settings.notificationsEnabled) {
    return 'Desactivados';
  }
  final parts = <String>[];
  final taskCount = controller.scheduledTaskNotificationCount;
  if (taskCount > 0) {
    parts.add(
        taskCount == 1 ? '1 aviso de tarea' : '$taskCount avisos de tareas');
  }
  final dailyCount = (settings.dayStartReminderEnabled ? 1 : 0) +
      (settings.dayEndReminderEnabled ? 1 : 0);
  if (dailyCount > 0) {
    parts.add(dailyCount == 1
        ? '1 aviso diario activo'
        : '$dailyCount avisos diarios activos');
  }
  return parts.isEmpty ? 'No hay avisos programados' : parts.join(' · ');
}

class _BackupStatusPanel extends StatelessWidget {
  const _BackupStatusPanel({
    required this.overview,
    required this.destinationPath,
  });

  final FullBackupOverview? overview;
  final String destinationPath;

  @override
  Widget build(BuildContext context) {
    final current = overview;
    final summary = current?.latest;
    final loading = current == null;
    final hasError = current?.errorMessage != null;
    final color = hasError ? const Color(0xFF9D5D3A) : const Color(0xFF5E6B50);
    final background =
        hasError ? const Color(0xFFFFF3EA) : const Color(0xFFF5F8F0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError ? const Color(0xFFE8C7AF) : const Color(0xFFD9E4CC),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              hasError
                  ? Icons.warning_amber_rounded
                  : summary == null
                      ? Icons.cloud_off_outlined
                      : Icons.verified_outlined,
              color: color,
              size: 23,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loading
                      ? 'Consultando las copias…'
                      : current.inProgress
                          ? 'Copia en curso'
                          : hasError
                              ? 'La última copia necesita atención'
                              : summary == null
                                  ? 'Todavía no hay una copia completa'
                                  : 'Última copia verificada',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loading
                      ? destinationPath
                      : hasError
                          ? current.errorMessage!
                          : summary == null
                              ? 'Se guardará en $destinationPath'
                              : '${_backupDateLabel(summary.createdAt)} · '
                                  '${summary.verifiedFiles} archivos · '
                                  '${_backupSizeLabel(summary.totalBytes)}',
                  style: TextStyle(
                    color: hasError ? color : context.visuals.textMuted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _backupStatusSubtitle(FullBackupOverview? overview) {
  if (overview == null) return 'Consultando…';
  if (overview.inProgress) return 'Copia en curso';
  if (overview.errorMessage != null) return 'Necesita atención';
  final latest = overview.latest;
  if (latest == null) return 'Todavía no creada';
  return _backupDateLabel(latest.createdAt);
}

String _backupDateLabel(DateTime value) {
  final local = value.toLocal();
  final date = '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
  return '$date a las ${_timeLabel(local)}';
}

String _backupSizeLabel(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kibibytes = bytes / 1024;
  if (kibibytes < 1024) return '${kibibytes.toStringAsFixed(1)} KB';
  final mebibytes = kibibytes / 1024;
  if (mebibytes < 1024) return '${mebibytes.toStringAsFixed(1)} MB';
  return '${(mebibytes / 1024).toStringAsFixed(1)} GB';
}

String _friendlyBackupError(Object error) {
  final message = error.toString();
  const prefixes = <String>[
    'Bad state: ',
    'Unsupported operation: ',
    'FileSystemException: ',
  ];
  for (final prefix in prefixes) {
    if (message.startsWith(prefix)) return message.substring(prefix.length);
  }
  return message;
}

class _SettingsSectionCard extends StatefulWidget {
  const _SettingsSectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  State<_SettingsSectionCard> createState() => _SettingsSectionCardState();
}

class _SettingsSectionCardState extends State<_SettingsSectionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return _SettingsPanelCard(
      padding: EdgeInsets.fromLTRB(20, 14, 20, _expanded ? 20 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0DE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon,
                        color: const Color(0xFF70835D), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF8D8377)),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 18),
            widget.child,
          ],
        ],
      ),
    );
  }
}

class _SettingsAsideCard extends StatefulWidget {
  const _SettingsAsideCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  State<_SettingsAsideCard> createState() => _SettingsAsideCardState();
}

class _SettingsAsideCardState extends State<_SettingsAsideCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return _SettingsPanelCard(
      padding: EdgeInsets.fromLTRB(20, 14, 20, _expanded ? 18 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0DE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon,
                        color: const Color(0xFF70835D), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF8D8377)),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE7D9C8)),
            const SizedBox(height: 14),
            ...widget.children,
          ],
        ],
      ),
    );
  }
}

class _SettingsPanelCard extends StatelessWidget {
  const _SettingsPanelCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE7D9C8)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            color: Color(0x0A000000),
            offset: Offset(0, 4),
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

class _SettingsStatusItem extends StatelessWidget {
  const _SettingsStatusItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7D9C8)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF5E6B50)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(color: context.visuals.textMuted)),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF79A14C) : const Color(0xFFD2C8B9),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsHintRow extends StatelessWidget {
  const _SettingsHintRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7D9C8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF6E7F5D)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style:
                    TextStyle(color: context.visuals.textStrong, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

Widget _settingsToggleRow({
  required String title,
  String subtitle = '',
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitle,
                  style:
                      const TextStyle(color: Color(0xFF7E7568), height: 1.35)),
            ],
          ],
        ),
      ),
      const SizedBox(width: 18),
      Switch(value: value, onChanged: onChanged),
    ],
  );
}

Widget _settingsActionRow({
  required String title,
  String subtitle = '',
  required String buttonLabel,
  required IconData icon,
  required VoidCallback onPressed,
  String? previousButtonLabel,
  IconData? previousIcon,
  VoidCallback? onPreviousPressed,
  String? secondaryButtonLabel,
  IconData? secondaryIcon,
  VoidCallback? onSecondaryPressed,
}) {
  return Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitle,
                  style:
                      const TextStyle(color: Color(0xFF7E7568), height: 1.35)),
            ],
          ],
        ),
      ),
      const SizedBox(width: 18),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          if (previousButtonLabel != null && onPreviousPressed != null)
            OutlinedButton.icon(
              onPressed: onPreviousPressed,
              icon: Icon(previousIcon ?? Icons.skip_previous_rounded, size: 18),
              label: Text(previousButtonLabel),
            ),
          if (secondaryButtonLabel != null && onSecondaryPressed != null)
            OutlinedButton.icon(
              onPressed: onSecondaryPressed,
              icon: Icon(secondaryIcon ?? Icons.undo_rounded, size: 18),
              label: Text(secondaryButtonLabel),
            ),
          FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: Text(buttonLabel),
          ),
        ],
      ),
    ],
  );
}

String _activityWhenLabel(DateTime value, DateTime today) {
  if (_sameDay(value, today)) {
    return 'hoy';
  }
  if (_sameDay(value, today.subtract(const Duration(days: 1)))) {
    return 'ayer';
  }
  return 'esta semana';
}

String _weekdayLabel(DateTime date) {
  const names = <String>['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  final index = date.weekday - 1;
  return '${names[index]} ${date.day}';
}

String _weekdayShort(DateTime date) {
  const names = <String>['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  return names[date.weekday - 1];
}

String _weekdayLong(DateTime date) {
  const names = <String>[
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo'
  ];
  return names[date.weekday - 1];
}

String _monthLong(int month) {
  const names = <String>[
    '',
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return names[month];
}

String _timeLabel(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

bool _hasVisibleTime(DateTime date) => date.hour != 0 || date.minute != 0;

String _formatDuration(Duration value) {
  if (value <= Duration.zero) {
    return '0:00';
  }
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }
  return '${value.inMinutes}:$seconds';
}

bool _sameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

bool _isAllDayRange(DateTime start, DateTime end) {
  return start.hour == 0 &&
      start.minute == 0 &&
      end.hour == 0 &&
      end.minute == 0 &&
      end.difference(start).inHours >= 23;
}
