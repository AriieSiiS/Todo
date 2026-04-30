// ignore_for_file: unused_element

part of 'app_shell.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.controller, super.key});

  final TodoWorkspace controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _webClientController;
  late final TextEditingController _desktopClientController;
  late final TextEditingController _desktopSecretController;

  TodoWorkspace get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _webClientController =
        TextEditingController(text: controller.calendarSettings.webClientId);
    _desktopClientController = TextEditingController(
        text: controller.calendarSettings.desktopClientId);
    _desktopSecretController = TextEditingController(
        text: controller.calendarSettings.desktopClientSecret);
  }

  @override
  void dispose() {
    _webClientController.dispose();
    _desktopClientController.dispose();
    _desktopSecretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = controller.daySettings;
    final notificationSettings = controller.notificationSettings;
    final calendarSettings = controller.calendarSettings;
    final calendars = controller.calendarAccount?.calendars ??
        const <CalendarListItemModel>[];
    final visuals = context.visuals;
    final headerActions = Wrap(
      spacing: 12,
      runSpacing: 12,
      children: const [
        _SettingsHeaderPill(label: 'General'),
        _SettingsHeaderPill(label: 'Integraciones', selected: true),
        _SettingsHeaderPill(label: 'Rutinas'),
        _SettingsPrimaryPill(
          label: 'Guardar ajustes',
          icon: Icons.add_rounded,
        ),
        _SettingsHeaderPill(
          label: 'Hoy',
          icon: Icons.calendar_today_outlined,
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: const Color(0xFFE7D9C8)),
          boxShadow: const [
            BoxShadow(
              blurRadius: 26,
              color: Color(0x12000000),
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1200;
              final leftColumn = ScrollConfiguration(
                behavior:
                    const MaterialScrollBehavior().copyWith(scrollbars: false),
                child: ListView(
                  children: [
                    _PageHeader(
                      title: 'Ajustes',
                      subtitle:
                          'Personaliza cómo funciona tu sistema y tus integraciones.',
                      trailing: headerActions,
                    ),
                    const SizedBox(height: 22),
                    _SettingsSectionCard(
                      icon: Icons.person_outline_rounded,
                      title: 'Cuenta y nube',
                      child: Column(
                        children: [
                          _settingsDataRow(
                            leftLabel: 'Cuenta',
                            leftValue: controller.cloudConnected
                                ? controller.cloudEmail
                                : 'Sin conectar',
                            rightLabel: 'Estado',
                            rightValue: controller.cloudConnected
                                ? 'Conectada'
                                : (controller.cloudConfigured
                                    ? 'Lista'
                                    : 'Sin configurar'),
                          ),
                          const Divider(height: 26),
                          _settingsStatusLine(
                            icon: Icons.cloud_done_outlined,
                            text: controller.cloudConnected
                                ? 'Todas tus notas y ajustes están sincronizados'
                                : 'La nube está lista para conectarse',
                            active: controller.cloudConnected,
                          ),
                          if (controller.cloudError.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                controller.cloudError,
                                style:
                                    const TextStyle(color: Color(0xFF9D4436)),
                              ),
                            ),
                          ],
                          if (controller.lastCloudSyncAt != null) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Ultima sincronizacion: ${_settingsDateTime(controller.lastCloudSyncAt!)}',
                                style: TextStyle(color: visuals.textMuted),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _SettingsHintRow(
                            icon: Icons.lock_outline_rounded,
                            text:
                                'Esta app personal no deberia pedir URL ni claves aqui. La configuracion de Supabase va integrada en el proyecto y en Ajustes solo controlas el estado de la sesion.',
                          ),
                          const SizedBox(height: 12),
                          _settingsOutlineShell(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Proyecto Supabase',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: visuals.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  controller.cloudSupabaseUrl,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (controller.cloudAllowedEmail.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Cuenta permitida: ${controller.cloudAllowedEmail}',
                                    style: TextStyle(color: visuals.textMuted),
                                  ),
                                ],
                                if (controller.cloudRedirectUrl.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Redirect local: ${controller.cloudRedirectUrl}',
                                    style: TextStyle(color: visuals.textMuted),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton(
                                onPressed: !controller.cloudConfigured ||
                                        controller.cloudBusy
                                    ? null
                                    : () async {
                                        final messenger =
                                            ScaffoldMessenger.of(context);
                                        final launched =
                                            await controller.connectCloud();
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              launched
                                                  ? 'Se abrió el acceso a Google para Supabase.'
                                                  : 'No se pudo iniciar la conexión con Supabase.',
                                            ),
                                          ),
                                        );
                                      },
                                child: Text(controller.cloudConnected
                                    ? 'Reconectar nube'
                                    : 'Conectar nube'),
                              ),
                              FilledButton.tonal(
                                onPressed: controller.cloudConnected &&
                                        !controller.cloudBusy
                                    ? () async {
                                        await controller.syncWithCloud();
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Sincronización con Supabase completada.')),
                                        );
                                      }
                                    : null,
                                child: const Text('Sincronizar ahora'),
                              ),
                              OutlinedButton(
                                onPressed: controller.cloudConnected &&
                                        !controller.cloudBusy
                                    ? () async {
                                        await controller.disconnectCloud();
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Sesión de Supabase cerrada.')),
                                        );
                                      }
                                    : null,
                                child: const Text('Cerrar sesión'),
                              ),
                            ],
                          ),
                          if (controller.cloudBusy) ...[
                            const SizedBox(height: 12),
                            const LinearProgressIndicator(),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SettingsSectionCard(
                      icon: Icons.calendar_month_outlined,
                      title: 'Calendario e integraciones',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _settingsDataRow(
                            leftLabel: 'Google Calendar',
                            leftValue: controller.isCalendarConnected
                                ? 'Conectado como ${calendarSettings.connectedEmail}'
                                : 'Todavía no hay sesión activa.',
                            rightValue: controller.isCalendarConnected
                                ? 'Sincronizado'
                                : 'Sin conectar',
                            trailing: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.tonal(
                                  onPressed: controller.calendarBusy
                                      ? null
                                      : _saveAndConnectCalendar,
                                  child: Text(controller.isCalendarConnected
                                      ? 'Reconectar'
                                      : 'Conectar'),
                                ),
                                OutlinedButton(
                                  onPressed: controller.isCalendarConnected
                                      ? controller.disconnectCalendar
                                      : null,
                                  child: const Text('Desconectar'),
                                ),
                              ],
                            ),
                          ),
                          if (controller.calendarBusy) ...[
                            const SizedBox(height: 12),
                            const LinearProgressIndicator(),
                          ],
                          if (calendarSettings.lastError.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(calendarSettings.lastError,
                                style:
                                    const TextStyle(color: Color(0xFF9D4436))),
                          ],
                          const Divider(height: 26),
                          TextField(
                            controller: _webClientController,
                            decoration: const InputDecoration(
                                labelText: 'Web Client ID'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _desktopClientController,
                            decoration: const InputDecoration(
                                labelText: 'Desktop Client ID'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _desktopSecretController,
                            decoration: const InputDecoration(
                                labelText: 'Desktop Client Secret'),
                          ),
                          if (calendars.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: calendars.any((item) =>
                                      item.id ==
                                      calendarSettings.selectedCalendarId)
                                  ? calendarSettings.selectedCalendarId
                                  : calendars.first.id,
                              items: calendars
                                  .map((calendar) => DropdownMenuItem<String>(
                                      value: calendar.id,
                                      child: Text(calendar.name)))
                                  .toList(),
                              onChanged: (value) async {
                                if (value == null) return;
                                final selected = calendars
                                    .firstWhere((item) => item.id == value);
                                await controller.updateCalendarSettings(
                                  controller.calendarSettings.copyWith(
                                    selectedCalendarId: selected.id,
                                    selectedCalendarName: selected.name,
                                  ),
                                );
                                await controller.refreshCalendarEvents();
                              },
                              decoration: const InputDecoration(
                                  labelText: 'Calendario principal'),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Sincronizar tareas con calendario\nLas tareas con hora o fecha se envían a Google Calendar.',
                                  style: TextStyle(
                                      color: visuals.textMuted, height: 1.35),
                                ),
                              ),
                              Switch(
                                value: controller.isCalendarConnected,
                                onChanged: controller.isCalendarConnected
                                    ? (_) {}
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SettingsSectionCard(
                      icon: Icons.schedule_rounded,
                      title: 'Reglas del día real',
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _settingsSelectTile(
                                  label: 'El día real cierra a las',
                                  helper:
                                      'A partir de esta hora, el sistema considera que tu día real terminó.',
                                  value: '${settings.dayEndsAtHour}:00',
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: _settingsSelectTile(
                                  label: 'El siguiente comienza a las',
                                  helper:
                                      'Desde esta hora, comienza el nuevo día real.',
                                  value: '${settings.nextDayVisibleAtHour}:00',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Slider(
                            value: settings.dayEndsAtHour.toDouble(),
                            min: 0,
                            max: 12,
                            divisions: 12,
                            onChanged: (value) => controller.updateSettings(
                              settings.copyWith(dayEndsAtHour: value.round()),
                            ),
                          ),
                          Slider(
                            value: settings.nextDayVisibleAtHour.toDouble(),
                            min: 5,
                            max: 14,
                            divisions: 9,
                            onChanged: (value) => controller.updateSettings(
                              settings.copyWith(
                                  nextDayVisibleAtHour: value.round()),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SettingsSectionCard(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notificaciones',
                      child: Column(
                        children: [
                          _settingsToggleRow(
                            title: 'Recordatorios de tareas',
                            subtitle:
                                'Recibe avisos para tareas programadas y pendientes importantes.',
                            value: notificationSettings.notificationsEnabled,
                            onChanged: (value) =>
                                controller.updateNotificationSettings(
                              notificationSettings.copyWith(
                                  notificationsEnabled: value),
                            ),
                          ),
                          const Divider(height: 26),
                          _settingsToggleRow(
                            title: 'Aviso de comienzo del día',
                            subtitle:
                                'Muestra un recordatorio con tus tareas activas del día.',
                            value: notificationSettings.dayStartReminderEnabled,
                            onChanged: (value) =>
                                controller.updateNotificationSettings(
                              notificationSettings.copyWith(
                                  dayStartReminderEnabled: value),
                            ),
                          ),
                          const Divider(height: 26),
                          _settingsToggleRow(
                            title: 'Aviso de cierre del día',
                            subtitle:
                                'Te recuerda revisar inbox y pendientes antes del corte.',
                            value: notificationSettings.dayEndReminderEnabled,
                            onChanged: (value) =>
                                controller.updateNotificationSettings(
                              notificationSettings.copyWith(
                                  dayEndReminderEnabled: value),
                            ),
                          ),
                          const Divider(height: 26),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Horas de enfoque (no molestar)\nSilencia notificaciones fuera de este rango.',
                                  style: TextStyle(
                                      color: visuals.textMuted, height: 1.35),
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 120,
                                child: DropdownButtonFormField<int>(
                                  initialValue: 22,
                                  items: List.generate(24, (index) => index)
                                      .map((hour) => DropdownMenuItem(
                                          value: hour,
                                          child: Text(
                                              '${hour.toString().padLeft(2, '0')}:00')))
                                      .toList(),
                                  onChanged: (_) {},
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text('–'),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 120,
                                child: DropdownButtonFormField<int>(
                                  initialValue: 7,
                                  items: List.generate(24, (index) => index)
                                      .map((hour) => DropdownMenuItem(
                                          value: hour,
                                          child: Text(
                                              '${hour.toString().padLeft(2, '0')}:00')))
                                      .toList(),
                                  onChanged: (_) {},
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.tonal(
                                onPressed: controller.notificationBusy
                                    ? null
                                    : () async {
                                        final granted = await controller
                                            .requestNotificationPermissions();
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(granted
                                                ? 'Permisos concedidos.'
                                                : 'No se concedieron los permisos.'),
                                          ),
                                        );
                                      },
                                child: const Text('Pedir permisos'),
                              ),
                              FilledButton(
                                onPressed: controller.rescheduleTaskReminders,
                                child: const Text('Reprogramar avisos'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SettingsSectionCard(
                      icon: Icons.palette_outlined,
                      title: 'Apariencia',
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _settingsSelectTile(
                                  label: 'Modo de color',
                                  helper: controller.visualMode ==
                                          AppVisualMode.classic
                                      ? 'Cálido (recomendado)'
                                      : 'Phantom',
                                  value: controller.visualMode ==
                                          AppVisualMode.classic
                                      ? 'Clásico'
                                      : 'Phantom',
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: _settingsSelectTile(
                                  label: 'Densidad',
                                  helper: 'Cómoda',
                                  value: 'Cómoda',
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: _settingsSelectTile(
                                  label: 'Idioma',
                                  helper: 'Español',
                                  value: 'Español',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SegmentedButton<AppVisualMode>(
                            segments: const [
                              ButtonSegment<AppVisualMode>(
                                value: AppVisualMode.classic,
                                label: Text('Clásico'),
                                icon: Icon(Icons.layers_rounded),
                              ),
                              ButtonSegment<AppVisualMode>(
                                value: AppVisualMode.phantom,
                                label: Text('Phantom'),
                                icon: Icon(Icons.bolt_rounded),
                              ),
                            ],
                            selected: <AppVisualMode>{controller.visualMode},
                            onSelectionChanged: (selection) =>
                                controller.setVisualMode(selection.first),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SettingsSectionCard(
                      icon: Icons.spa_outlined,
                      title: 'Rutinas y comportamiento',
                      child: Column(
                        children: [
                          _settingsToggleRow(
                            title: 'Movimiento ya resuelto',
                            subtitle:
                                'Oculta automáticamente tareas completadas del día.',
                            value: true,
                            onChanged: (_) {},
                          ),
                          const Divider(height: 26),
                          _settingsToggleRow(
                            title: 'Sugerencias inteligentes',
                            subtitle:
                                'Muestra ideas y atajos según tu patrón de uso.',
                            value: true,
                            onChanged: (_) {},
                          ),
                          const Divider(height: 26),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton(
                                onPressed: () => _showExport(context),
                                child: const Text('Exportar JSON'),
                              ),
                              FilledButton.tonal(
                                onPressed: () => _showImport(context),
                                child: const Text('Importar JSON'),
                              ),
                              OutlinedButton(
                                onPressed: () => _confirmReset(context),
                                child: const Text('Reiniciar datos'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              final rightColumn = ScrollConfiguration(
                behavior:
                    const MaterialScrollBehavior().copyWith(scrollbars: false),
                child: ListView(
                  children: [
                    _SettingsAsideCard(
                      title: 'Estado del sistema',
                      icon: Icons.shield_outlined,
                      children: [
                        _SettingsStatusItem(
                          icon: Icons.person_outline_rounded,
                          title: 'Cuenta',
                          subtitle: controller.cloudConnected
                              ? 'Conectada'
                              : 'Sin sesión',
                          active: controller.cloudConnected,
                        ),
                        _SettingsStatusItem(
                          icon: Icons.cloud_outlined,
                          title: 'Sincronización en la nube',
                          subtitle: controller.lastCloudSyncAt == null
                              ? 'Pendiente'
                              : 'Actualizada hace ${DateTime.now().difference(controller.lastCloudSyncAt!).inMinutes.clamp(0, 59)} min',
                          active: controller.lastCloudSyncAt != null,
                        ),
                        _SettingsStatusItem(
                          icon: Icons.calendar_month_rounded,
                          title: 'Google Calendar',
                          subtitle: controller.isCalendarConnected
                              ? 'Sincronizado'
                              : 'Desconectado',
                          active: controller.isCalendarConnected,
                        ),
                        _SettingsStatusItem(
                          icon: Icons.folder_copy_outlined,
                          title: 'Copias de seguridad',
                          subtitle: controller.lastSavedAt == null
                              ? 'Sin guardar'
                              : 'Última: hoy, ${_timeLabel(controller.lastSavedAt!)}',
                          active: controller.lastSavedAt != null,
                        ),
                        _SettingsStatusItem(
                          icon: Icons.notifications_none_rounded,
                          title: 'Alertas',
                          subtitle: notificationSettings.notificationsEnabled
                              ? 'Todo en orden'
                              : 'Desactivadas',
                          active: notificationSettings.notificationsEnabled,
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {},
                            child: const Text('Ver detalles del sistema'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const _SettingsAsideCard(
                      title: 'Consejos y atajos',
                      icon: Icons.tips_and_updates_outlined,
                      children: [
                        _SettingsHintRow(
                          icon: Icons.open_with_rounded,
                          text:
                              'Arrastra y suelta tareas para reordenar tu día.',
                        ),
                        _SettingsHintRow(
                          icon: Icons.keyboard_command_key_rounded,
                          text:
                              'Escribe / para abrir la captura rápida desde cualquier vista.',
                        ),
                        _SettingsHintRow(
                          icon: Icons.link_rounded,
                          text:
                              'Usa @proyectos para crear tareas directamente en un proyecto.',
                        ),
                        _SettingsHintRow(
                          icon: Icons.calendar_today_outlined,
                          text:
                              'Consulta el calendario desde la vista Hoy con el atajo C.',
                        ),
                      ],
                    ),
                  ],
                ),
              );

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: leftColumn),
                  if (wide) ...[
                    const SizedBox(width: 22),
                    SizedBox(width: 320, child: rightColumn),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _saveAndConnectCalendar() async {
    await controller.updateCalendarSettings(
      controller.calendarSettings.copyWith(
        webClientId: _webClientController.text.trim(),
        desktopClientId: _desktopClientController.text.trim(),
        desktopClientSecret: _desktopSecretController.text.trim(),
      ),
    );
    await controller.connectCalendar();
  }

  void _showExport(BuildContext context) {
    final snapshot = controller.exportSnapshot().toPrettyJson();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export JSON'),
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

  void _showImport(BuildContext context) {
    final importController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import JSON'),
        content: SizedBox(
          width: 720,
          child: TextField(
            controller: importController,
            minLines: 12,
            maxLines: 20,
            decoration: const InputDecoration(
              hintText: 'Pega aqui un snapshot completo en JSON',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final ok = controller.importStateFromJson(importController.text);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? 'Estado importado correctamente.'
                      : 'No se pudo importar ese JSON.'),
                ),
              );
            },
            child: const Text('Importar'),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reiniciar datos'),
        content: const Text(
            'Esto sustituira tu estado actual por la base inicial de la app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              await controller.resetToSeed();
              navigator.pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('Datos reiniciados.')),
              );
            },
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _SettingsPanelCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0DE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF70835D), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF8D8377)),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _SettingsAsideCard extends StatelessWidget {
  const _SettingsAsideCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _SettingsPanelCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0DE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF70835D), size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE7D9C8)),
          const SizedBox(height: 14),
          ...children,
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

class _SettingsHeaderPill extends StatelessWidget {
  const _SettingsHeaderPill({
    required this.label,
    this.icon,
    this.selected = false,
  });

  final String label;
  final IconData? icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF7C9164) : const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? const Color(0xFF7C9164) : const Color(0xFFE3D5C4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : const Color(0xFF2D2A25),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF2D2A25),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsPrimaryPill extends StatelessWidget {
  const _SettingsPrimaryPill({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF2F382A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFFF9F5EC)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFF9F5EC),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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

Widget _settingsOutlineShell({required Widget child}) {
  return DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFFFFFCF8),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE5D8C7)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: child,
    ),
  );
}

Widget _settingsDataRow({
  required String leftLabel,
  required String leftValue,
  String? rightLabel,
  String? rightValue,
  Widget? trailing,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(leftLabel,
                style: const TextStyle(fontSize: 13, color: Color(0xFF7E7568))),
            const SizedBox(height: 4),
            Text(leftValue, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
      if (rightLabel != null || rightValue != null) ...[
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rightLabel ?? '',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF7E7568))),
              const SizedBox(height: 4),
              if (rightValue != null)
                _miniBadge(rightValue, const Color(0xFFE8F0DE),
                    const Color(0xFF677E53)),
            ],
          ),
        ),
      ],
      if (trailing != null) ...[
        const SizedBox(width: 18),
        trailing,
      ],
    ],
  );
}

Widget _settingsStatusLine({
  required IconData icon,
  required String text,
  required bool active,
}) {
  return Row(
    children: [
      Icon(icon,
          color: active ? const Color(0xFF70835D) : const Color(0xFFB4AC9F),
          size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(text)),
    ],
  );
}

Widget _settingsSelectTile({
  required String label,
  required String helper,
  required String value,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(helper,
          style: const TextStyle(
              fontSize: 13, color: Color(0xFF7E7568), height: 1.35)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5D8C7)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(value)),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    ],
  );
}

Widget _settingsToggleRow({
  required String title,
  required String subtitle,
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
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(color: Color(0xFF7E7568), height: 1.35)),
          ],
        ),
      ),
      const SizedBox(width: 18),
      Switch(value: value, onChanged: onChanged),
    ],
  );
}

Widget _settingsMetricRow(IconData icon, String value, String label) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF70835D)),
        const SizedBox(width: 12),
        SizedBox(
          width: 34,
          child: Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        Expanded(
            child:
                Text(label, style: const TextStyle(color: Color(0xFF6E675C)))),
      ],
    ),
  );
}

List<TaskModel> _completedPlaceholderTasks(
    TodoWorkspace controller, String key) {
  final categoryIds = controller.categories.isNotEmpty
      ? <String>[controller.categories.first.id]
      : const <String>[];
  final date = controller.logicalDate();
  switch (key) {
    case 'today':
      return [
        TaskModel(
            id: 'done-a',
            title: 'Desayunar',
            categoryIds: categoryIds,
            scheduledAt: date.add(const Duration(hours: 7, minutes: 20)),
            status: TaskStatus.completed),
        TaskModel(
            id: 'done-b',
            title: 'Regar plantas del salón',
            categoryIds: categoryIds,
            scheduledAt: date.add(const Duration(hours: 8, minutes: 15)),
            status: TaskStatus.completed),
      ];
    case 'yesterday':
      return [
        TaskModel(
            id: 'done-c',
            title: 'Lavar toallas',
            categoryIds: categoryIds,
            scheduledAt: date
                .subtract(const Duration(days: 1))
                .add(const Duration(hours: 18, minutes: 45)),
            status: TaskStatus.completed),
        TaskModel(
            id: 'done-d',
            title: 'Enviar mensaje a Ana',
            categoryIds: categoryIds,
            scheduledAt: date
                .subtract(const Duration(days: 1))
                .add(const Duration(hours: 17, minutes: 30)),
            status: TaskStatus.completed),
        TaskModel(
            id: 'done-e',
            title: 'Confirmar cita del viernes',
            categoryIds: categoryIds,
            scheduledAt: date
                .subtract(const Duration(days: 1))
                .add(const Duration(hours: 16, minutes: 5)),
            status: TaskStatus.completed),
      ];
    case 'week':
      return [
        TaskModel(
            id: 'done-f',
            title: 'Sacar basura',
            categoryIds: categoryIds,
            scheduledAt: date
                .subtract(const Duration(days: 2))
                .add(const Duration(hours: 20, minutes: 10)),
            status: TaskStatus.completed),
        TaskModel(
            id: 'done-g',
            title: 'Revisar estantería del baño',
            categoryIds: categoryIds,
            scheduledAt: date
                .subtract(const Duration(days: 2))
                .add(const Duration(hours: 10, minutes: 25)),
            status: TaskStatus.completed),
      ];
    default:
      return [
        TaskModel(
            id: 'done-h',
            title: 'Ordenar recibidor',
            categoryIds: categoryIds,
            scheduledAt: date
                .subtract(const Duration(days: 8))
                .add(const Duration(hours: 11, minutes: 15)),
            status: TaskStatus.completed),
        TaskModel(
            id: 'done-i',
            title: 'Preparar lavadora',
            categoryIds: categoryIds,
            scheduledAt: date
                .subtract(const Duration(days: 9))
                .add(const Duration(hours: 9, minutes: 10)),
            status: TaskStatus.completed),
      ];
  }
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

String _activityBadgeLabel(DateTime value, DateTime today) {
  if (_sameDay(value, today)) {
    return 'Hoy';
  }
  if (_sameDay(value, today.subtract(const Duration(days: 1)))) {
    return 'Ayer';
  }
  return 'Semana';
}

String _settingsDateTime(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${_timeLabel(value)}';
}

String _weekdayLabel(DateTime date) {
  const names = <String>['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];
  final index = date.weekday - 1;
  return '${names[index]} ${date.day}';
}

String _weekdayShort(DateTime date) {
  const names = <String>['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];
  return names[date.weekday - 1];
}

String _weekdayLong(DateTime date) {
  const names = <String>[
    'Lunes',
    'Martes',
    'Miercoles',
    'Jueves',
    'Viernes',
    'Sabado',
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
