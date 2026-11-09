part of 'app_shell.dart';

const List<String> _tiposPinturaMiniatura = <String>[
  'Imprimación',
  'Base',
  'Lavado',
  'Capa',
  'Contraste',
  'Técnica',
  'Barniz',
];

Color _colorEstadoMiniatura(BuildContext context, MiniatureStatus status) {
  final visuals = context.visuals;
  return switch (status) {
    MiniatureStatus.unbuilt => visuals.textMuted,
    MiniatureStatus.built => const Color(0xFF8A7650),
    MiniatureStatus.primed => const Color(0xFF66768A),
    MiniatureStatus.painting => const Color(0xFFC9963B),
    MiniatureStatus.painted => visuals.success,
  };
}

IconData _iconoEstadoMiniatura(MiniatureStatus status) => switch (status) {
      MiniatureStatus.unbuilt => Icons.inventory_2_outlined,
      MiniatureStatus.built => Icons.handyman_rounded,
      MiniatureStatus.primed => Icons.format_color_fill_rounded,
      MiniatureStatus.painting => Icons.brush_rounded,
      MiniatureStatus.painted => Icons.verified_rounded,
    };

class MiniaturesPage extends StatefulWidget {
  const MiniaturesPage({required this.controller, super.key});

  final TodoWorkspace controller;

  @override
  State<MiniaturesPage> createState() => _MiniaturesPageState();
}

class _MiniaturesPageState extends State<MiniaturesPage> {
  String? _openKitId;
  MiniatureStatus? _filter;

  TodoWorkspace get controller => widget.controller;

  Future<void> _crearCaja() async {
    final id = await showMiniatureKitEditor(context, controller);
    if (id != null && mounted) setState(() => _openKitId = id);
  }

  @override
  Widget build(BuildContext context) {
    final openKit =
        _openKitId == null ? null : controller.miniatureKitById(_openKitId!);
    if (openKit != null) {
      return _MiniKitDetail(
        key: ValueKey('miniature-detail-${openKit.id}'),
        controller: controller,
        kit: openKit,
        onBack: () => setState(() => _openKitId = null),
      );
    }
    final visuals = context.visuals;
    final kits = controller.miniatureKits.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final visibles = _filter == null
        ? kits
        : kits.where((kit) => kit.status == _filter).toList();
    final totalModels = kits.fold<int>(0, (sum, kit) => sum + kit.models.length);
    final paintedModels =
        kits.fold<int>(0, (sum, kit) => sum + kit.paintedCount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: _PageHeader(
              title: 'Miniaturas',
              subtitle: '',
              compact: true,
              pinTrailingToEdge: true,
              trailing: _HeaderActionButton(
                key: const ValueKey('miniatures-add-kit'),
                label: 'Añadir caja',
                icon: Icons.add_rounded,
                onPressed: _crearCaja,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (kits.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterPill(
                        key: const ValueKey('miniatures-filter-all'),
                        label: 'Todas',
                        selected: _filter == null,
                        onTap: () => setState(() => _filter = null),
                      ),
                      for (final status in MiniatureStatus.values)
                        if (kits.any((kit) => kit.status == status))
                          _FilterPill(
                            key: ValueKey('miniatures-filter-${status.name}'),
                            label: status.pluralLabel,
                            icon: _iconoEstadoMiniatura(status),
                            selected: _filter == status,
                            onTap: () => setState(() =>
                                _filter = _filter == status ? null : status),
                          ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$paintedModels de $totalModels miniaturas terminadas',
                  style: TextStyle(color: visuals.textMuted),
                ),
              ],
            ),
          if (kits.isNotEmpty) const SizedBox(height: 16),
          Expanded(
            child: kits.isEmpty
                ? _MiniEmpty(onAdd: _crearCaja)
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 300,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.74,
                    ),
                    itemCount: visibles.length,
                    itemBuilder: (context, index) => _MiniKitCard(
                      controller: controller,
                      kit: visibles[index],
                      onOpen: () =>
                          setState(() => _openKitId = visibles[index].id),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MiniEmpty extends StatelessWidget {
  const _MiniEmpty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 46, color: visuals.textMuted),
          const SizedBox(height: 12),
          Text('Todavía no hay miniaturas',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Añade una caja para seguir su montaje, su pintura y tus fotos.',
            style: TextStyle(color: visuals.textMuted),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Añadir caja'),
          ),
        ],
      ),
    );
  }
}

/// Imagen guardada en la carpeta de miniaturas.
class _MiniImage extends StatelessWidget {
  const _MiniImage({
    required this.controller,
    required this.path,
    this.fit = BoxFit.cover,
  });

  final TodoWorkspace controller;
  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return const _MiniImagePlaceholder();
    return FutureBuilder<String>(
      future: controller.miniatureAssetAbsolutePath(path),
      builder: (context, snapshot) {
        final absolute = snapshot.data ?? '';
        if (absolute.isEmpty) return const SizedBox.shrink();
        return ImagenLocal(
          absolute,
          fit: fit,
          errorBuilder: (_, __, ___) => const _MiniImagePlaceholder(),
        );
      },
    );
  }
}

class _MiniImagePlaceholder extends StatelessWidget {
  const _MiniImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return ColoredBox(
      color: visuals.panelAlt,
      child: Center(
        child: Icon(Icons.shield_outlined, size: 40, color: visuals.textMuted),
      ),
    );
  }
}

class _MiniStatusChip extends StatelessWidget {
  const _MiniStatusChip({required this.status});

  final MiniatureStatus status;

  @override
  Widget build(BuildContext context) {
    return _SoftChip(
      label: status.label,
      icon: _iconoEstadoMiniatura(status),
      color: _colorEstadoMiniatura(context, status),
    );
  }
}

class _MiniKitCard extends StatelessWidget {
  const _MiniKitCard({
    required this.controller,
    required this.kit,
    required this.onOpen,
  });

  final TodoWorkspace controller;
  final MiniatureKit kit;
  final VoidCallback onOpen;

  Future<void> _menu(BuildContext context, Offset position) async {
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: const [
        PopupMenuItem(value: 'edit', child: Text('Editar')),
        PopupMenuItem(value: 'delete', child: Text('Eliminar')),
      ],
    );
    if (!context.mounted) return;
    if (choice == 'edit') {
      await showMiniatureKitEditor(context, controller, kit: kit);
    } else if (choice == 'delete') {
      await _confirmarBorrarCaja(context, controller, kit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final subtitle =
        [kit.faction, kit.game].where((part) => part.isNotEmpty).join(' · ');
    final total = kit.models.length;
    return Material(
      key: ValueKey('miniature-card-${kit.id}'),
      color: visuals.panel,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        onSecondaryTapDown: (details) =>
            _menu(context, details.globalPosition),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ColoredBox(
                color: Colors.white,
                child: _MiniImage(
                  controller: controller,
                  path: kit.thumbnailPath.isNotEmpty
                      ? kit.thumbnailPath
                      : kit.imagePath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kit.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: visuals.textMuted, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: kit.progress,
                      minHeight: 6,
                      backgroundColor: visuals.panelAlt,
                      color: _colorEstadoMiniatura(context, kit.status),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${kit.paintedCount}/$total terminadas',
                          style:
                              TextStyle(color: visuals.textMuted, fontSize: 13),
                        ),
                      ),
                      _MiniStatusChip(status: kit.status),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmarBorrarCaja(
  BuildContext context,
  TodoWorkspace controller,
  MiniatureKit kit, {
  VoidCallback? onDeleted,
}) async {
  final confirmed = await _confirmarMiniatura(
    context,
    title: 'Eliminar caja',
    message: 'Se borrará «${kit.name}» con su guía y sus fotos.',
  );
  if (confirmed) {
    controller.deleteMiniatureKit(kit.id);
    onDeleted?.call();
  }
}

Future<bool> _confirmarMiniatura(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'Eliminar',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result == true;
}

Future<String?> _pedirTextoMiniatura(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
}) {
  final text = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: text,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(text.text),
          child: const Text('Guardar'),
        ),
      ],
    ),
  ).whenComplete(text.dispose);
}

class _MiniKitDetail extends StatelessWidget {
  const _MiniKitDetail({
    required this.controller,
    required this.kit,
    required this.onBack,
    super.key,
  });

  final TodoWorkspace controller;
  final MiniatureKit kit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final subtitle =
        [kit.faction, kit.game].where((part) => part.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                key: const ValueKey('miniature-back'),
                tooltip: 'Volver a Miniaturas',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          style: TextStyle(color: visuals.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _HeaderSecondaryButton(
                key: const ValueKey('miniature-edit'),
                label: 'Editar',
                icon: Icons.edit_rounded,
                onPressed: () =>
                    showMiniatureKitEditor(context, controller, kit: kit),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Eliminar caja',
                onPressed: () => _confirmarBorrarCaja(
                  context,
                  controller,
                  kit,
                  onDeleted: onBack,
                ),
                icon: Icon(Icons.delete_outline_rounded, color: visuals.danger),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 300,
                  child: _MiniKitSummary(controller: controller, kit: kit),
                ),
                const SizedBox(width: 22),
                Expanded(
                  child: DefaultTabController(
                    length: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTabBar(labels: [
                          'Miniaturas',
                          'Guía de pintura',
                          kit.photos.isEmpty
                              ? 'Mis fotos'
                              : 'Mis fotos (${kit.photos.length})',
                        ]),
                        const SizedBox(height: 14),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _MiniModelsTab(controller: controller, kit: kit),
                              _MiniGuideTab(controller: controller, kit: kit),
                              _MiniPhotosTab(controller: controller, kit: kit),
                            ],
                          ),
                        ),
                      ],
                    ),
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

class _MiniKitSummary extends StatelessWidget {
  const _MiniKitSummary({required this.controller, required this.kit});

  final TodoWorkspace controller;
  final MiniatureKit kit;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final url = Uri.tryParse(kit.externalUrl);
    return ListView(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: AspectRatio(
            aspectRatio: 1,
            child: ColoredBox(
              color: Colors.white,
              child: _MiniImage(
                controller: controller,
                path: kit.imagePath,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${kit.paintedCount} de ${kit.models.length} terminadas',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _MiniStatusChip(status: kit.status),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: kit.progress,
                  minHeight: 8,
                  backgroundColor: visuals.panelAlt,
                  color: _colorEstadoMiniatura(context, kit.status),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final status in MiniatureStatus.values)
                    if (kit.countWith(status) > 0)
                      _SoftChip(
                        label: '${kit.countWith(status)} '
                            '${kit.countWith(status) == 1 ? status.label.toLowerCase() : status.pluralLabel.toLowerCase()}',
                        color: _colorEstadoMiniatura(context, status),
                      ),
                ],
              ),
            ],
          ),
        ),
        if (kit.note.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Text(kit.note, style: const TextStyle(height: 1.4)),
          ),
        ],
        if (url != null && url.hasScheme) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () =>
                launchUrl(url, mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Ver en la tienda'),
          ),
        ],
      ],
    );
  }
}

class _MiniModelsTab extends StatelessWidget {
  const _MiniModelsTab({required this.controller, required this.kit});

  final TodoWorkspace controller;
  final MiniatureKit kit;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Marca en qué punto está cada miniatura.',
                style: TextStyle(color: visuals.textMuted),
              ),
            ),
            PopupMenuButton<MiniatureStatus>(
              tooltip: 'Marcar todas',
              onSelected: (status) =>
                  controller.setAllMiniatureModelsStatus(kit.id, status),
              itemBuilder: (context) => [
                for (final status in MiniatureStatus.values)
                  PopupMenuItem(
                    value: status,
                    child: Text('Todas: ${status.label.toLowerCase()}'),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.done_all_rounded,
                        size: 18, color: visuals.accent),
                    const SizedBox(width: 6),
                    const Text('Marcar todas'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: () => controller.addMiniatureModel(kit.id),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Añadir miniatura'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: kit.models.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final model = kit.models[index];
              return Container(
                key: ValueKey('miniature-model-${model.id}'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: visuals.panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: visuals.panelBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      _iconoEstadoMiniatura(model.status),
                      color: _colorEstadoMiniatura(context, model.status),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        model.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<MiniatureStatus>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      segments: [
                        for (final status in MiniatureStatus.values)
                          ButtonSegment(
                            value: status,
                            label: Text(status.label),
                          ),
                      ],
                      selected: {model.status},
                      onSelectionChanged: (selection) =>
                          controller.setMiniatureModelStatus(
                              kit.id, model.id, selection.first),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Más opciones',
                      onSelected: (value) async {
                        if (value == 'rename') {
                          final name = await _pedirTextoMiniatura(
                            context,
                            title: 'Cambiar nombre',
                            label: 'Nombre',
                            initial: model.name,
                          );
                          if (name != null) {
                            controller.renameMiniatureModel(
                                kit.id, model.id, name);
                          }
                        } else if (value == 'remove' && context.mounted) {
                          final ok = await _confirmarMiniatura(
                            context,
                            title: 'Quitar miniatura',
                            message: 'Se quitará «${model.name}» de la caja.',
                            action: 'Quitar',
                          );
                          if (ok) {
                            controller.removeMiniatureModel(kit.id, model.id);
                          }
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                            value: 'rename', child: Text('Cambiar nombre')),
                        PopupMenuItem(value: 'remove', child: Text('Quitar')),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MiniGuideTab extends StatelessWidget {
  const _MiniGuideTab({required this.controller, required this.kit});

  final TodoWorkspace controller;
  final MiniatureKit kit;

  Future<void> _anadirPintura(BuildContext context) async {
    final result = await showDialog<MiniaturePaint>(
      context: context,
      builder: (context) => const _MiniPaintDialog(),
    );
    if (result != null) {
      controller.addMiniaturePaint(kit.id, result.name, result.kind);
    }
  }

  Future<void> _editarPaso(BuildContext context, {int? index}) async {
    final step = await showDialog<MiniaturePaintStep>(
      context: context,
      builder: (context) => _MiniStepDialog(
        initial: index == null ? null : kit.guide[index],
        paints: kit.paints.map((paint) => paint.name).toList(),
      ),
    );
    if (step != null) {
      controller.saveMiniatureGuideStep(kit.id, step, index: index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final owned = kit.paints.where((paint) => paint.owned).length;
    return ListView(
      children: [
        _SurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Pinturas',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 10),
                  if (kit.paints.isNotEmpty)
                    Text(
                      'Tienes $owned de ${kit.paints.length}',
                      style: TextStyle(color: visuals.textMuted),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _anadirPintura(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Añadir pintura'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Pulsa una pintura para marcar que ya la tienes.',
                style: TextStyle(color: visuals.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var index = 0; index < kit.paints.length; index++)
                    FilterChip(
                      key: ValueKey('miniature-paint-$index'),
                      selected: kit.paints[index].owned,
                      showCheckmark: true,
                      label: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: kit.paints[index].name),
                          if (kit.paints[index].kind.isNotEmpty)
                            TextSpan(
                              text: '  ${kit.paints[index].kind}',
                              style: TextStyle(
                                color: visuals.textMuted,
                                fontSize: 12,
                              ),
                            ),
                        ]),
                      ),
                      onSelected: (_) =>
                          controller.toggleMiniaturePaintOwned(kit.id, index),
                      deleteIcon: const Icon(Icons.close_rounded, size: 16),
                      deleteButtonTooltipMessage: 'Quitar pintura',
                      onDeleted: () async {
                        final ok = await _confirmarMiniatura(
                          context,
                          title: 'Quitar pintura',
                          message:
                              'Se quitará «${kit.paints[index].name}» de la lista.',
                          action: 'Quitar',
                        );
                        if (ok) controller.removeMiniaturePaint(kit.id, index);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text('Pasos', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _editarPaso(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Añadir paso'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (kit.guide.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'Todavía no hay pasos. Añade el primero con su pintura.',
              style: TextStyle(color: visuals.textMuted),
            ),
          ),
        for (var index = 0; index < kit.guide.length; index++) ...[
          _MiniStepCard(
            number: index + 1,
            step: kit.guide[index],
            isFirst: index == 0,
            isLast: index == kit.guide.length - 1,
            onEdit: () => _editarPaso(context, index: index),
            onMove: (offset) =>
                controller.moveMiniatureGuideStep(kit.id, index, offset),
            onDelete: () async {
              final ok = await _confirmarMiniatura(
                context,
                title: 'Eliminar paso',
                message: 'Se borrará «${kit.guide[index].title}».',
              );
              if (ok) controller.removeMiniatureGuideStep(kit.id, index);
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _MiniStepCard extends StatelessWidget {
  const _MiniStepCard({
    required this.number,
    required this.step,
    required this.isFirst,
    required this.isLast,
    required this.onEdit,
    required this.onMove,
    required this.onDelete,
  });

  final int number;
  final MiniaturePaintStep step;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onEdit;
  final ValueChanged<int> onMove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Container(
      key: ValueKey('miniature-step-$number'),
      padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
      decoration: BoxDecoration(
        color: visuals.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: visuals.panelBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: visuals.accent.withValues(alpha: 0.16),
            child: Text(
              '$number',
              style: TextStyle(
                color: visuals.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    step.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                if (step.paints.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final paint in step.paints)
                        _SoftChip(
                          label: paint,
                          icon: Icons.water_drop_rounded,
                          color: visuals.accent,
                        ),
                    ],
                  ),
                ],
                if (step.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(step.description, style: const TextStyle(height: 1.4)),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                case 'up':
                  onMove(-1);
                case 'down':
                  onMove(1);
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Editar')),
              if (!isFirst)
                const PopupMenuItem(value: 'up', child: Text('Subir')),
              if (!isLast)
                const PopupMenuItem(value: 'down', child: Text('Bajar')),
              const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniPaintDialog extends StatefulWidget {
  const _MiniPaintDialog();

  @override
  State<_MiniPaintDialog> createState() => _MiniPaintDialogState();
}

class _MiniPaintDialogState extends State<_MiniPaintDialog> {
  final TextEditingController _name = TextEditingController();
  String _kind = 'Capa';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Añadir pintura'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Pintura'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                for (final kind in _tiposPinturaMiniatura)
                  DropdownMenuItem(value: kind, child: Text(kind)),
              ],
              onChanged: (value) => setState(() => _kind = value ?? _kind),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            Navigator.of(context)
                .pop(MiniaturePaint(name: _name.text.trim(), kind: _kind));
          },
          child: const Text('Añadir'),
        ),
      ],
    );
  }
}

class _MiniStepDialog extends StatefulWidget {
  const _MiniStepDialog({required this.initial, required this.paints});

  final MiniaturePaintStep? initial;
  final List<String> paints;

  @override
  State<_MiniStepDialog> createState() => _MiniStepDialogState();
}

class _MiniStepDialogState extends State<_MiniStepDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.initial?.title ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.initial?.description ?? '');
  late final Set<String> _selected = {...?widget.initial?.paints};

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final available = <String>{...widget.paints, ..._selected}.toList();
    return AlertDialog(
      title: Text(widget.initial == null ? 'Añadir paso' : 'Editar paso'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Paso',
                  hintText: 'Por ejemplo, «Armadura: capa base»',
                ),
              ),
              if (available.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Pinturas de este paso'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final paint in available)
                      FilterChip(
                        label: Text(paint),
                        selected: _selected.contains(paint),
                        onSelected: (value) => setState(() {
                          if (value) {
                            _selected.add(paint);
                          } else {
                            _selected.remove(paint);
                          }
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _description,
                minLines: 3,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Cómo hacerlo',
                  alignLabelWithHint: true,
                ),
              ),
            ],
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
            if (_title.text.trim().isEmpty) return;
            Navigator.of(context).pop(MiniaturePaintStep(
              title: _title.text.trim(),
              description: _description.text.trim(),
              paints: available.where(_selected.contains).toList(),
            ));
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _MiniPhotosTab extends StatefulWidget {
  const _MiniPhotosTab({required this.controller, required this.kit});

  final TodoWorkspace controller;
  final MiniatureKit kit;

  @override
  State<_MiniPhotosTab> createState() => _MiniPhotosTabState();
}

class _MiniPhotosTabState extends State<_MiniPhotosTab> {
  bool _importing = false;

  Future<void> _anadirFotos() async {
    final files = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Imágenes',
          extensions: ['png', 'jpg', 'jpeg', 'webp'],
        ),
      ],
    );
    if (files.isEmpty || !mounted) return;
    setState(() => _importing = true);
    var failed = 0;
    for (final file in files) {
      try {
        await widget.controller.addMiniaturePhoto(widget.kit.id, file.path);
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    setState(() => _importing = false);
    if (failed > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(failed == 1
            ? 'No se pudo añadir una foto.'
            : 'No se pudieron añadir $failed fotos.'),
        persist: false,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final photos = widget.kit.photos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Tus fotos de las miniaturas terminadas.',
                style: TextStyle(color: visuals.textMuted),
              ),
            ),
            if (_importing)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            TextButton.icon(
              key: const ValueKey('miniature-add-photos'),
              onPressed: _importing ? null : _anadirFotos,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: const Text('Añadir fotos'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: photos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_camera_outlined,
                          size: 42, color: visuals.textMuted),
                      const SizedBox(height: 10),
                      Text(
                        'Cuando las termines, añade aquí tus fotos.',
                        style: TextStyle(color: visuals.textMuted),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    return Material(
                      color: visuals.panelAlt,
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (context) => _MiniPhotoDialog(
                            controller: widget.controller,
                            kitId: widget.kit.id,
                            photo: photo,
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _MiniImage(
                              controller: widget.controller,
                              path: photo.thumbnailPath.isNotEmpty
                                  ? photo.thumbnailPath
                                  : photo.imagePath,
                            ),
                            if (photo.caption.isNotEmpty)
                              Align(
                                alignment: Alignment.bottomLeft,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  color: const Color(0x99000000),
                                  child: Text(
                                    photo.caption,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12),
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
      ],
    );
  }
}

class _MiniPhotoDialog extends StatefulWidget {
  const _MiniPhotoDialog({
    required this.controller,
    required this.kitId,
    required this.photo,
  });

  final TodoWorkspace controller;
  final String kitId;
  final MiniaturePhoto photo;

  @override
  State<_MiniPhotoDialog> createState() => _MiniPhotoDialogState();
}

class _MiniPhotoDialogState extends State<_MiniPhotoDialog> {
  late final TextEditingController _caption =
      TextEditingController(text: widget.photo.caption);

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final size = MediaQuery.sizeOf(context);
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      content: SizedBox(
        width: min(900, size.width * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: size.height * 0.62),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _MiniImage(
                  controller: widget.controller,
                  path: widget.photo.imagePath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _caption,
              decoration: const InputDecoration(labelText: 'Pie de foto'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final ok = await _confirmarMiniatura(
              context,
              title: 'Eliminar foto',
              message: 'Se borrará esta foto.',
            );
            if (!ok) return;
            await widget.controller
                .removeMiniaturePhoto(widget.kitId, widget.photo.id);
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text('Eliminar', style: TextStyle(color: visuals.danger)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        FilledButton(
          onPressed: () {
            widget.controller.updateMiniaturePhotoCaption(
                widget.kitId, widget.photo.id, _caption.text);
            Navigator.of(context).pop();
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Abre el editor de una caja. Devuelve el identificador de la caja guardada.
Future<String?> showMiniatureKitEditor(
  BuildContext context,
  TodoWorkspace controller, {
  MiniatureKit? kit,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _MiniKitEditorDialog(controller: controller, kit: kit),
  );
}

class _MiniKitEditorDialog extends StatefulWidget {
  const _MiniKitEditorDialog({required this.controller, this.kit});

  final TodoWorkspace controller;
  final MiniatureKit? kit;

  @override
  State<_MiniKitEditorDialog> createState() => _MiniKitEditorDialogState();
}

class _MiniKitEditorDialogState extends State<_MiniKitEditorDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.kit?.name ?? '');
  late final TextEditingController _game =
      TextEditingController(text: widget.kit?.game ?? 'Warhammer 40.000');
  late final TextEditingController _faction =
      TextEditingController(text: widget.kit?.faction ?? '');
  late final TextEditingController _count = TextEditingController(text: '1');
  late final TextEditingController _url =
      TextEditingController(text: widget.kit?.externalUrl ?? '');
  late final TextEditingController _note =
      TextEditingController(text: widget.kit?.note ?? '');
  XFile? _image;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final text in [_name, _game, _faction, _count, _url, _note]) {
      text.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirImagen() async {
    final selected = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Imágenes',
          extensions: ['png', 'jpg', 'jpeg', 'webp'],
        ),
      ],
    );
    if (selected != null && mounted) setState(() => _image = selected);
  }

  Future<void> _guardar() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Pon un nombre a la caja.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final controller = widget.controller;
    var id = widget.kit?.id;
    if (id == null) {
      id = controller
          .createMiniatureKit(
            name: _name.text,
            game: _game.text,
            faction: _faction.text,
            modelCount: int.tryParse(_count.text.trim()) ?? 1,
            note: _note.text,
            externalUrl: _url.text,
          )
          .id;
    } else {
      controller.updateMiniatureKitDetails(
        id,
        name: _name.text,
        game: _game.text,
        faction: _faction.text,
        note: _note.text,
        externalUrl: _url.text,
      );
    }
    final image = _image;
    if (image != null) {
      try {
        await controller.importMiniatureKitImage(id, image.path);
      } catch (error) {
        if (mounted) {
          setState(() {
            _saving = false;
            _error = 'Se guardó la caja, pero no la imagen: $error';
          });
        }
        return;
      }
    }
    if (mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final isNew = widget.kit == null;
    return AlertDialog(
      title: Text(isNew ? 'Añadir caja' : 'Editar caja'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey('miniature-editor-name'),
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _game,
                      decoration: const InputDecoration(labelText: 'Juego'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _faction,
                      decoration: const InputDecoration(labelText: 'Facción'),
                    ),
                  ),
                  if (isNew) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _count,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration:
                            const InputDecoration(labelText: 'Miniaturas'),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                decoration:
                    const InputDecoration(labelText: 'Enlace a la tienda'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _elegirImagen,
                    icon: const Icon(Icons.add_photo_alternate_rounded),
                    label: Text(widget.kit?.hasImage == true || _image != null
                        ? 'Cambiar imagen de la caja'
                        : 'Añadir imagen de la caja'),
                  ),
                  if (_image != null)
                    Expanded(
                      child: Text(
                        _image!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: visuals.textMuted),
                      ),
                    ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_error!, style: TextStyle(color: visuals.danger)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('miniature-editor-save'),
          onPressed: _saving ? null : _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
