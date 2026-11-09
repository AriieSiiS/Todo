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

/// Zonas de pintura del modelo 3D, en el orden en que se muestran.
const Map<String, String> _zonasMiniatura = <String, String>{
  'armadura': 'Armadura',
  'capa': 'Capa y faldón',
  'penacho': 'Penacho',
  'traje': 'Mangas y juntas',
  'empunadura': 'Empuñaduras y metal oscuro',
  'hoja': 'Hoja de la espada',
  'energia': 'Energía de la hoja',
  'cordones': 'Cordones',
  'gemas': 'Gemas',
  'ojos': 'Ojos',
  'escudo': 'Escudo',
  'estandarte': 'Estandarte',
  'peana': 'Peana',
  'borde': 'Borde de la peana',
};

const Color _escenarioClaro = Color(0xFF3A2F25);
const Color _escenarioOscuro = Color(0xFF121010);
const Color _oroMiniatura = Color(0xFFE2B85C);

Color _colorHex(String valor, {Color porDefecto = const Color(0xFF8D9198)}) {
  final limpio = valor.replaceAll('*', '').replaceAll('#', '').trim();
  if (limpio.length != 6) return porDefecto;
  final numero = int.tryParse(limpio, radix: 16);
  return numero == null ? porDefecto : Color(0xFF000000 | numero);
}

Color _colorEstadoMiniatura(BuildContext context, MiniatureStatus status) {
  final visuals = context.visuals;
  return switch (status) {
    MiniatureStatus.unbuilt => visuals.textMuted,
    MiniatureStatus.built => const Color(0xFF9C7F4A),
    MiniatureStatus.primed => const Color(0xFF6E8299),
    MiniatureStatus.painting => const Color(0xFFD39A35),
    MiniatureStatus.painted => const Color(0xFF4F9A6A),
  };
}

IconData _iconoEstadoMiniatura(MiniatureStatus status) => switch (status) {
      MiniatureStatus.unbuilt => Icons.inventory_2_outlined,
      MiniatureStatus.built => Icons.handyman_rounded,
      MiniatureStatus.primed => Icons.format_color_fill_rounded,
      MiniatureStatus.painting => Icons.brush_rounded,
      MiniatureStatus.painted => Icons.verified_rounded,
    };

/// Colores que tiene cada zona tras aplicar los pasos hasta [hasta] incluido.
Map<String, String> _coloresHasta(MiniatureKit kit, int hasta) {
  final colores = <String, String>{};
  for (var i = 0; i <= hasta && i < kit.guide.length; i++) {
    for (final entrada in kit.guide[i].zones.entries) {
      if (entrada.key == 'todo') {
        for (final zona in _zonasMiniatura.keys) {
          colores[zona] = entrada.value;
        }
      } else {
        colores[entrada.key] = entrada.value;
      }
    }
  }
  return colores;
}

// ---------------------------------------------------------------------------
// Lista de cajas
// ---------------------------------------------------------------------------

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
    final figuras = kits.fold<int>(0, (sum, kit) => sum + kit.models.length);
    final terminadas = kits.fold<int>(0, (sum, kit) => sum + kit.paintedCount);
    final pinturas = <String>{
      for (final kit in kits)
        for (final paint in kit.paints) paint.name,
    };
    final tengo = <String>{
      for (final kit in kits)
        for (final paint in kit.paints)
          if (paint.owned) paint.name,
    };

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
          const SizedBox(height: 16),
          if (kits.isNotEmpty) ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MiniStat(
                  icon: Icons.inventory_2_rounded,
                  value: '${kits.length}',
                  label: kits.length == 1 ? 'caja' : 'cajas',
                ),
                _MiniStat(
                  icon: Icons.shield_rounded,
                  value: '$figuras',
                  label: 'figuras',
                ),
                _MiniStat(
                  icon: Icons.verified_rounded,
                  value: '$terminadas',
                  label: terminadas == 1 ? 'terminada' : 'terminadas',
                  color: const Color(0xFF4F9A6A),
                ),
                _MiniStat(
                  icon: Icons.palette_rounded,
                  value: '${tengo.length}/${pinturas.length}',
                  label: 'pinturas que tienes',
                  color: _oroMiniatura,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
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
                      onTap: () => setState(
                          () => _filter = _filter == status ? null : status),
                    ),
              ],
            ),
            const SizedBox(height: 18),
          ],
          Expanded(
            child: kits.isEmpty
                ? _MiniEmpty(onAdd: _crearCaja)
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 330,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 18,
                      childAspectRatio: 0.7,
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
          if (kits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Pulsa una caja para ver su montaje, su guía de pintura y el modelo 3D.',
                style: TextStyle(color: visuals.textMuted, fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final tono = color ?? visuals.accent;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 18, 10),
      decoration: BoxDecoration(
        color: visuals.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: visuals.panelBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tono.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: tono),
          ),
          const SizedBox(width: 11),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(color: visuals.textMuted)),
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
    this.alignment = Alignment.center,
    this.escala = 1,
    this.ajustada = false,
  });

  final TodoWorkspace controller;
  final String path;
  final BoxFit fit;
  final Alignment alignment;
  final double escala;

  /// Ocupa solo lo que mide la imagen, para saber si se pulsa fuera de ella.
  final bool ajustada;

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return const _MiniImagePlaceholder();
    return FutureBuilder<String>(
      future: controller.miniatureAssetAbsolutePath(path),
      builder: (context, snapshot) {
        final absolute = snapshot.data ?? '';
        if (absolute.isEmpty) return const SizedBox.shrink();
        final imagen = ImagenLocal(
          absolute,
          fit: fit,
          alignment: alignment,
          escala: escala,
          errorBuilder: (_, __, ___) => const _MiniImagePlaceholder(),
        );
        return ajustada ? imagen : SizedBox.expand(child: imagen);
      },
    );
  }
}

class _MiniImagePlaceholder extends StatelessWidget {
  const _MiniImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_escenarioClaro, _escenarioOscuro],
        ),
      ),
      child: Center(
        child: Icon(Icons.shield_outlined, size: 40, color: Color(0x88FFFFFF)),
      ),
    );
  }
}

/// Muestra de pintura con forma de gota de color.
class _MiniSwatch extends StatelessWidget {
  const _MiniSwatch({required this.color, this.size = 22, this.metal = false});

  final Color color;
  final double size;
  final bool metal;

  @override
  Widget build(BuildContext context) {
    final claro = Color.lerp(color, Colors.white, metal ? 0.55 : 0.28)!;
    final oscuro = Color.lerp(color, Colors.black, 0.35)!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.95,
          colors: [claro, color, oscuro],
          stops: const [0, 0.55, 1],
        ),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
    );
  }
}

bool _pinturaMetalica(String nombre) => const {
      'Retributor Armour',
      'Retributor Armour (spray)',
      'Auric Armour Gold',
      'Liberator Gold',
      'Stormhost Silver',
      'Leadbelcher',
      'Ironbreaker',
    }.contains(nombre);

class _MiniStatusChip extends StatelessWidget {
  const _MiniStatusChip({required this.status, this.onDark = false});

  final MiniatureStatus status;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = _colorEstadoMiniatura(context, status);
    if (!onDark) {
      return _SoftChip(
        label: status.label,
        icon: _iconoEstadoMiniatura(status),
        color: color,
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconoEstadoMiniatura(status), size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MiniKitCard extends StatefulWidget {
  const _MiniKitCard({
    required this.controller,
    required this.kit,
    required this.onOpen,
  });

  final TodoWorkspace controller;
  final MiniatureKit kit;
  final VoidCallback onOpen;

  @override
  State<_MiniKitCard> createState() => _MiniKitCardState();
}

class _MiniKitCardState extends State<_MiniKitCard> {
  bool _hover = false;

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
      await showMiniatureKitEditor(context, widget.controller, kit: widget.kit);
    } else if (choice == 'delete') {
      await _confirmarBorrarCaja(context, widget.controller, widget.kit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kit = widget.kit;
    final subtitle =
        [kit.faction, kit.game].where((part) => part.isNotEmpty).join(' · ');
    final total = kit.models.length;
    final colores = kit.paints
        .where((paint) => paint.color.isNotEmpty && paint.kind != 'Barniz')
        .map((paint) => paint.color)
        .toSet()
        .take(9)
        .toList();
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.02 : 1,
        duration: const Duration(milliseconds: 160),
        child: Material(
          key: ValueKey('miniature-card-${kit.id}'),
          color: _escenarioOscuro,
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          elevation: _hover ? 10 : 3,
          shadowColor: Colors.black54,
          child: InkWell(
            onTap: widget.onOpen,
            onSecondaryTapDown: (details) =>
                _menu(context, details.globalPosition),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _MiniImage(
                  controller: widget.controller,
                  path: kit.coverImage,
                  alignment: Alignment.topCenter,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00000000),
                        Color(0x00000000),
                        Color(0xCC0E0B09),
                        Color(0xF20E0B09),
                      ],
                      stops: [0, 0.42, 0.72, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  child: _MiniStatusChip(status: kit.status, onDark: true),
                ),
                Positioned(
                  top: 10,
                  right: 12,
                  child: _MiniProgressRing(
                    value: total == 0 ? 0 : kit.paintedCount / total,
                    label: '${kit.paintedCount}/$total',
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kit.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if (colores.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            for (final color in colores)
                              Padding(
                                padding: const EdgeInsets.only(right: 5),
                                child: _MiniSwatch(
                                  color: _colorHex(color),
                                  size: 17,
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      _MiniFigureBar(kit: kit, height: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniProgressRing extends StatelessWidget {
  const _MiniProgressRing({required this.value, required this.label});

  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: 3.5,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            color: _oroMiniatura,
          ),
          Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra con un segmento por figura, coloreado según su estado.
class _MiniFigureBar extends StatelessWidget {
  const _MiniFigureBar({required this.kit, this.height = 8});

  final MiniatureKit kit;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < kit.models.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Tooltip(
              message:
                  '${kit.models[i].name}: ${kit.models[i].status.label.toLowerCase()}',
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: kit.models[i].status == MiniatureStatus.unbuilt
                      ? Colors.white.withValues(alpha: 0.18)
                      : _colorEstadoMiniatura(context, kit.models[i].status),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ],
      ],
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

// ---------------------------------------------------------------------------
// Vista de 360° con las fotos oficiales
// ---------------------------------------------------------------------------

/// Gira la figura con las fotos de 360°: arrastrar en horizontal la rota y en
/// vertical cambia la altura de la cámara.
class _MiniGiro extends StatefulWidget {
  const _MiniGiro({
    required this.controller,
    required this.spins,
    this.title = 'Vista 360° oficial',
    super.key,
  });

  final TodoWorkspace controller;
  final List<MiniatureSpin> spins;
  final String title;

  @override
  State<_MiniGiro> createState() => _MiniGiroState();
}

class _MiniGiroState extends State<_MiniGiro> {
  int _figura = 0;
  int _fila = 0;
  int _columna = 0;
  double _arrastreX = 0;
  double _arrastreY = 0;
  bool _arrastrando = false;

  MiniatureSpin get _spin =>
      widget.spins[_figura.clamp(0, widget.spins.length - 1)];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precargarFila();
  }

  /// Ancho al que se decodifican las fotos: basta para el visor y deja que
  /// una fila entera quepa en la caché sin disparar la memoria.
  static const int _anchoDecodificado = 720;

  ImageProvider _foto(int fila, int columna) => ResizeImage(
        FileImage(File(widget.controller
            .miniatureAssetPathSync(_spin.frame(fila, columna)))),
        width: _anchoDecodificado,
      );

  /// Carga de antemano los ángulos de la altura actual para que el giro no
  /// se quede esperando a leer cada foto.
  void _precargarFila() {
    if (widget.spins.isEmpty) return;
    for (var columna = 0; columna < _spin.cols; columna++) {
      precacheImage(_foto(_fila, columna), context, onError: (_, __) {});
    }
  }

  void _arrastrar(Offset delta) {
    final filaAnterior = _fila;
    _arrastreX += delta.dx;
    _arrastreY += delta.dy;
    const pasoX = 14.0;
    const pasoY = 45.0;
    var cambio = false;
    while (_arrastreX.abs() >= pasoX) {
      final sentido = _arrastreX > 0 ? -1 : 1;
      _columna = (_columna + sentido) % _spin.cols;
      if (_columna < 0) _columna += _spin.cols;
      _arrastreX -= pasoX * _arrastreX.sign;
      cambio = true;
    }
    while (_arrastreY.abs() >= pasoY) {
      final sentido = _arrastreY > 0 ? 1 : -1;
      _fila = (_fila + sentido).clamp(0, _spin.rows - 1);
      _arrastreY -= pasoY * _arrastreY.sign;
      cambio = true;
    }
    if (cambio) setState(() {});
    if (_fila != filaAnterior) _precargarFila();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.spins.isEmpty) {
      return const ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        child: _MiniImagePlaceholder(),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(
        color: Colors.white,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Listener recibe todos los movimientos del ratón sin competir con
            // el zoom: con un detector de arrastre, el visor se quedaba a
            // veces con el gesto y la figura no giraba.
            MouseRegion(
              cursor: _arrastrando
                  ? SystemMouseCursors.grabbing
                  : SystemMouseCursors.grab,
              child: Listener(
                key: const ValueKey('miniature-spin'),
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => setState(() => _arrastrando = true),
                onPointerUp: (_) => setState(() => _arrastrando = false),
                onPointerCancel: (_) => setState(() => _arrastrando = false),
                onPointerMove: (evento) {
                  if (evento.buttons != 0) _arrastrar(evento.delta);
                },
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 3,
                  panEnabled: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 54, 20, 46),
                    child: Image(
                      image: _foto(_fila, _columna),
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 14,
              left: 16,
              right: 14,
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Color(0xFF1C1712),
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        _spin.name,
                        style: const TextStyle(
                            color: Color(0x991C1712), fontSize: 12.5),
                      ),
                    ],
                  ),
                  const Spacer(),
                  for (var i = 0; i < widget.spins.length; i++) ...[
                    const SizedBox(width: 6),
                    _MiniGlassButton(
                      icon: Icons.person_rounded,
                      label: 'Figura ${i + 1}',
                      selected: i == _figura,
                      onPressed: () {
                        setState(() {
                          _figura = i;
                          _fila = _fila.clamp(0, _spin.rows - 1);
                          _columna = _columna % _spin.cols;
                        });
                        _precargarFila();
                      },
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.threesixty_rounded,
                            size: 16, color: Color(0x991C1712)),
                        const SizedBox(width: 6),
                        const Flexible(
                          child: Text(
                            'Arrastra para girar · arriba y abajo cambia la altura · rueda para acercar',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Color(0x991C1712), fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        for (var f = 0; f < _spin.rows; f++)
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(left: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: f == _fila
                                  ? const Color(0xFF1C1712)
                                  : const Color(0x331C1712),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón de cristal para colocar sobre el escenario oscuro.
class _MiniGlassButton extends StatelessWidget {
  const _MiniGlassButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? _oroMiniatura.withValues(alpha: 0.9)
          : Colors.black.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 17,
                  color: selected ? const Color(0xFF1C1712) : Colors.white),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFF1C1712) : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ficha de la caja
// ---------------------------------------------------------------------------

class _MiniKitDetail extends StatefulWidget {
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
  State<_MiniKitDetail> createState() => _MiniKitDetailState();
}

class _MiniKitDetailState extends State<_MiniKitDetail>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);
  late int _pasoPintura = _primerPendiente(widget.kit.guide.map((s) => s.done));
  late int _pasoMontaje =
      _primerPendiente(widget.kit.assembly.map((s) => s.done));

  static int _primerPendiente(Iterable<bool> hechos) {
    var indice = 0;
    for (final hecho in hechos) {
      if (!hecho) return indice;
      indice++;
    }
    return indice == 0 ? 0 : indice - 1;
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  MiniatureKit get kit => widget.kit;
  TodoWorkspace get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final pasoPintura =
        kit.guide.isEmpty ? 0 : _pasoPintura.clamp(0, kit.guide.length - 1);
    final pasoMontaje = kit.assembly.isEmpty
        ? 0
        : _pasoMontaje.clamp(0, kit.assembly.length - 1);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MiniHero(
            controller: controller,
            kit: kit,
            onBack: widget.onBack,
            onAssembly: () => _tabs.animateTo(1),
            onPaint: () => _tabs.animateTo(2),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.label,
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(color: Color(0xFF70835D), width: 2),
              ),
              labelColor: context.visuals.accent,
              unselectedLabelColor: context.visuals.textMuted,
              labelStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              unselectedLabelStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              labelPadding: const EdgeInsets.only(right: 28),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              tabs: [
                const Tab(height: 36, text: 'Resumen'),
                Tab(
                  height: 36,
                  text: kit.assembly.isEmpty
                      ? 'Montaje'
                      : 'Montaje ${kit.assemblyDone}/${kit.assembly.length}',
                ),
                Tab(
                  height: 36,
                  text: kit.guide.isEmpty
                      ? 'Pintura'
                      : 'Pintura ${kit.guideDone}/${kit.guide.length}',
                ),
                Tab(height: 36, text: 'Figuras ${kit.models.length}'),
                Tab(
                  height: 36,
                  text: kit.photos.isEmpty
                      ? 'Galería'
                      : 'Galería · ${kit.photos.length} tuyas',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _MiniResumenTab(
                  controller: controller,
                  kit: kit,
                  onOpenPhase: (indice) {
                    setState(() => _pasoPintura = indice);
                    _tabs.animateTo(2);
                  },
                ),
                _MiniMontajeTab(
                  controller: controller,
                  kit: kit,
                  index: pasoMontaje,
                  onIndex: (value) => setState(() => _pasoMontaje = value),
                ),
                _MiniPinturaTab(
                  controller: controller,
                  kit: kit,
                  index: pasoPintura,
                  onIndex: (value) => setState(() => _pasoPintura = value),
                ),
                _MiniFigurasTab(controller: controller, kit: kit),
                _MiniGaleriaTab(controller: controller, kit: kit),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniHero extends StatelessWidget {
  const _MiniHero({
    required this.controller,
    required this.kit,
    required this.onBack,
    required this.onAssembly,
    required this.onPaint,
  });

  final TodoWorkspace controller;
  final MiniatureKit kit;
  final VoidCallback onBack;
  final VoidCallback onAssembly;
  final VoidCallback onPaint;

  @override
  Widget build(BuildContext context) {
    final subtitle =
        [kit.faction, kit.game].where((part) => part.isNotEmpty).join(' · ');
    final fondo = kit.heroPath.isNotEmpty ? kit.heroPath : kit.coverImage;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 226,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: _escenarioOscuro,
              child: _MiniImage(
                controller: controller,
                path: fondo,
                alignment: const Alignment(0.2, -0.5),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xF20E0B09),
                    Color(0xCC0E0B09),
                    Color(0x330E0B09),
                    Color(0x000E0B09),
                  ],
                  stops: [0, 0.38, 0.72, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _MiniGlassButton(
                        key: const ValueKey('miniature-back'),
                        icon: Icons.arrow_back_rounded,
                        label: 'Miniaturas',
                        onPressed: onBack,
                      ),
                      const Spacer(),
                      _MiniGlassButton(
                        key: const ValueKey('miniature-edit'),
                        icon: Icons.edit_rounded,
                        label: 'Editar',
                        onPressed: () => showMiniatureKitEditor(
                            context, controller,
                            kit: kit),
                      ),
                      const SizedBox(width: 8),
                      _MiniGlassButton(
                        icon: Icons.delete_outline_rounded,
                        label: 'Eliminar',
                        onPressed: () => _confirmarBorrarCaja(
                          context,
                          controller,
                          kit,
                          onDeleted: onBack,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    kit.name,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontSize: 38,
                          height: 1,
                        ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 15,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      SizedBox(
                        width: 320,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${kit.paintedCount} de ${kit.models.length} figuras terminadas',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _MiniFigureBar(kit: kit),
                          ],
                        ),
                      ),
                      const SizedBox(width: 22),
                      if (kit.assembly.isNotEmpty)
                        _MiniGlassButton(
                          icon: Icons.handyman_rounded,
                          label:
                              'Montaje ${kit.assemblyDone}/${kit.assembly.length}',
                          onPressed: onAssembly,
                        ),
                      const SizedBox(width: 8),
                      if (kit.guide.isNotEmpty)
                        _MiniGlassButton(
                          icon: Icons.brush_rounded,
                          label: kit.guideDone == 0
                              ? 'Empezar a pintar'
                              : 'Pintura ${kit.guideDone}/${kit.guide.length}',
                          selected: true,
                          onPressed: onPaint,
                        ),
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

// --- Resumen ----------------------------------------------------------------

class _MiniResumenTab extends StatelessWidget {
  const _MiniResumenTab({
    required this.controller,
    required this.kit,
    required this.onOpenPhase,
  });

  final TodoWorkspace controller;
  final MiniatureKit kit;
  final ValueChanged<int> onOpenPhase;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 11,
          child: _MiniGiro(
            key: const ValueKey('miniature-giro-resumen'),
            controller: controller,
            spins: kit.spins,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          flex: 9,
          child: ListView(
            children: [
              _MiniFlujo(kit: kit, onOpen: onOpenPhase),
              const SizedBox(height: 14),
              _MiniPaleta(controller: controller, kit: kit),
              if (kit.note.isNotEmpty) ...[
                const SizedBox(height: 14),
                _SurfaceCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sobre la caja',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(kit.note, style: const TextStyle(height: 1.45)),
                      if (Uri.tryParse(kit.externalUrl)?.hasScheme == true) ...[
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse(kit.externalUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('Ver en la tienda'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Diagrama del proceso: una parada por fase de la guía.
class _MiniFlujo extends StatelessWidget {
  const _MiniFlujo({required this.kit, required this.onOpen});

  final MiniatureKit kit;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final fases = <String, List<int>>{};
    for (var i = 0; i < kit.guide.length; i++) {
      final fase =
          kit.guide[i].phase.isEmpty ? kit.guide[i].title : kit.guide[i].phase;
      fases.putIfAbsent(fase, () => <int>[]).add(i);
    }
    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Diagrama del proceso',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text(
                '${kit.guideDone} de ${kit.guide.length} pasos',
                style: TextStyle(color: visuals.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (fases.isEmpty)
            Text('Añade pasos en Pintura para ver el diagrama.',
                style: TextStyle(color: visuals.textMuted))
          else
            LayoutBuilder(builder: (context, constraints) {
              final porFila = constraints.maxWidth < 520 ? 3 : 4;
              final lista = fases.entries.toList();
              final filas = <List<MapEntry<String, List<int>>>>[];
              for (var i = 0; i < lista.length; i += porFila) {
                filas.add(lista.sublist(i, min(i + porFila, lista.length)));
              }
              var numero = 0;
              return Column(
                children: [
                  for (final fila in filas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var j = 0; j < porFila; j++)
                            Expanded(
                              child: j < fila.length
                                  ? Builder(builder: (context) {
                                      numero++;
                                      final fase = fila[j];
                                      return _MiniFaseNodo(
                                        numero: numero,
                                        nombre: fase.key,
                                        pasos: fase.value
                                            .map((i) => kit.guide[i])
                                            .toList(),
                                        conector: j < fila.length - 1,
                                        onTap: () => onOpen(fase.value.first),
                                      );
                                    })
                                  : const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _MiniFaseNodo extends StatelessWidget {
  const _MiniFaseNodo({
    required this.numero,
    required this.nombre,
    required this.pasos,
    required this.conector,
    required this.onTap,
  });

  final int numero;
  final String nombre;
  final List<MiniaturePaintStep> pasos;
  final bool conector;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final hechos = pasos.where((paso) => paso.done).length;
    final completa = hechos == pasos.length;
    final colores = <String>{
      for (final paso in pasos)
        for (final valor in paso.zones.values) valor.replaceAll('*', ''),
    }.take(4).toList();
    final tono = completa ? const Color(0xFF4F9A6A) : visuals.accent;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            height: 46,
            child: Row(
              children: [
                const Expanded(child: SizedBox.shrink()),
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completa ? tono : visuals.panelAlt,
                    border: Border.all(
                      color: hechos > 0 ? tono : visuals.panelBorder,
                      width: 2.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: completa
                      ? const Icon(Icons.check_rounded, color: Colors.white)
                      : Text(
                          '$numero',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: hechos > 0 ? tono : visuals.textStrong,
                          ),
                        ),
                ),
                Expanded(
                  child: conector
                      ? Container(
                          height: 2.5,
                          margin: const EdgeInsets.only(left: 6),
                          color: completa ? tono : visuals.panelBorder,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            nombre,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '$hechos/${pasos.length}',
            style: TextStyle(color: visuals.textMuted, fontSize: 12),
          ),
          if (colores.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final color in colores)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _MiniSwatch(color: _colorHex(color), size: 14),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Paleta de pinturas con las que ya se tienen marcadas.
class _MiniPaleta extends StatelessWidget {
  const _MiniPaleta({required this.controller, required this.kit});

  final TodoWorkspace controller;
  final MiniatureKit kit;

  Future<void> _anadir(BuildContext context) async {
    final result = await showDialog<MiniaturePaint>(
      context: context,
      builder: (context) => const _MiniPaintDialog(),
    );
    if (result != null) {
      controller.addMiniaturePaint(kit.id, result.name, result.kind);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final tengo = kit.paints.where((paint) => paint.owned).length;
    final grupos = <String, List<int>>{};
    for (var i = 0; i < kit.paints.length; i++) {
      grupos
          .putIfAbsent(
              kit.paints[i].kind.isEmpty ? 'Otras' : kit.paints[i].kind,
              () => <int>[])
          .add(i);
    }
    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Paleta', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 10),
              if (kit.paints.isNotEmpty)
                Text(
                  'Tienes $tengo de ${kit.paints.length}',
                  style: TextStyle(color: visuals.textMuted),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _anadir(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Añadir'),
              ),
            ],
          ),
          Text(
            'Pulsa un bote para marcar que ya lo tienes.',
            style: TextStyle(color: visuals.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          for (final grupo in grupos.entries) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6, top: 4),
              child: Text(
                grupo.key.toUpperCase(),
                style: TextStyle(
                  color: visuals.textMuted,
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final i in grupo.value)
                  _MiniPaintPot(
                    key: ValueKey('miniature-paint-$i'),
                    paint: kit.paints[i],
                    onTap: () =>
                        controller.toggleMiniaturePaintOwned(kit.id, i),
                    onRemove: () async {
                      final ok = await _confirmarMiniatura(
                        context,
                        title: 'Quitar pintura',
                        message:
                            'Se quitará «${kit.paints[i].name}» de la lista.',
                        action: 'Quitar',
                      );
                      if (ok) controller.removeMiniaturePaint(kit.id, i);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _MiniPaintPot extends StatelessWidget {
  const _MiniPaintPot({
    required this.paint,
    required this.onTap,
    this.onRemove,
    super.key,
  });

  final MiniaturePaint paint;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final color = _colorHex(paint.color);
    return Tooltip(
      message: paint.owned ? 'La tienes' : 'Te falta',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        onSecondaryTap: onRemove,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
          decoration: BoxDecoration(
            color: paint.owned
                ? const Color(0xFF4F9A6A).withValues(alpha: 0.14)
                : visuals.panelAlt,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: paint.owned
                  ? const Color(0xFF4F9A6A).withValues(alpha: 0.55)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniSwatch(
                  color: color, size: 24, metal: _pinturaMetalica(paint.name)),
              const SizedBox(width: 8),
              Text(paint.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (paint.owned) ...[
                const SizedBox(width: 6),
                const Icon(Icons.check_circle_rounded,
                    size: 16, color: Color(0xFF4F9A6A)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// --- Montaje ----------------------------------------------------------------

class _MiniMontajeTab extends StatelessWidget {
  const _MiniMontajeTab({
    required this.controller,
    required this.kit,
    required this.index,
    required this.onIndex,
  });

  final TodoWorkspace controller;
  final MiniatureKit kit;
  final int index;
  final ValueChanged<int> onIndex;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    if (kit.assembly.isEmpty) {
      return Center(
        child: Text(
          'Esta caja no tiene instrucciones de montaje.',
          style: TextStyle(color: visuals.textMuted),
        ),
      );
    }
    final paso = kit.assembly[index];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 300,
          child: _MiniStepList(
            count: kit.assembly.length,
            selected: index,
            done: (i) => kit.assembly[i].done,
            title: (i) => kit.assembly[i].title,
            leading: (i) => ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 46,
                height: 46,
                child: ColoredBox(
                  color: Colors.white,
                  child: _MiniImage(
                    controller: controller,
                    path: kit.assembly[i].imagePath,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            onSelect: onIndex,
            onToggle: (i) =>
                controller.toggleMiniatureAssemblyStepDone(kit.id, i),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: _SurfaceCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _MiniNumero(numero: index + 1, hecho: paso.done),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paso ${index + 1} de ${kit.assembly.length}',
                            style: TextStyle(
                                color: visuals.textMuted, fontSize: 12.5),
                          ),
                          Text(
                            paso.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Pulsa para ampliar · arrastra para mover',
                      style: TextStyle(color: visuals.textMuted, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Ver en grande',
                      onPressed: () => _abrirVisor(
                        context,
                        controller,
                        rutas: [
                          for (final paso in kit.assembly) paso.imagePath,
                        ],
                        inicial: index,
                      ),
                      icon: const Icon(Icons.open_in_full_rounded),
                    ),
                  ],
                ),
                if (paso.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(paso.description, style: const TextStyle(height: 1.45)),
                ],
                const SizedBox(height: 14),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: ColoredBox(
                      color: Colors.white,
                      child: _MiniZoomable(
                        key: ValueKey('montaje-$index'),
                        child: SizedBox.expand(
                          child: _MiniImage(
                            controller: controller,
                            path: paso.imagePath,
                            fit: BoxFit.contain,
                            escala: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _MiniStepNav(
                  index: index,
                  count: kit.assembly.length,
                  done: paso.done,
                  onIndex: onIndex,
                  onDone: () {
                    if (!paso.done) {
                      controller.toggleMiniatureAssemblyStepDone(kit.id, index);
                    }
                    if (index < kit.assembly.length - 1) onIndex(index + 1);
                  },
                  onUndo: () =>
                      controller.toggleMiniatureAssemblyStepDone(kit.id, index),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniNumero extends StatelessWidget {
  const _MiniNumero({required this.numero, required this.hecho});

  final int numero;
  final bool hecho;
  static const double size = 44;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hecho ? const Color(0xFF4F9A6A) : _oroMiniatura,
      ),
      alignment: Alignment.center,
      child: hecho
          ? Icon(Icons.check_rounded, color: Colors.white, size: size * 0.5)
          : Text(
              '$numero',
              style: TextStyle(
                color: const Color(0xFF1C1712),
                fontWeight: FontWeight.w900,
                fontSize: size * 0.38,
                shadows: [Shadow(color: visuals.panel, blurRadius: 0)],
              ),
            ),
    );
  }
}

class _MiniStepList extends StatelessWidget {
  const _MiniStepList({
    required this.count,
    required this.selected,
    required this.done,
    required this.title,
    required this.onSelect,
    required this.onToggle,
    this.leading,
    this.subtitle,
  });

  final int count;
  final int selected;
  final bool Function(int) done;
  final String Function(int) title;
  final String Function(int)? subtitle;
  final Widget Function(int)? leading;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final hechos = List.generate(count, done).where((value) => value).length;
    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$hechos de $count hechos',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: count == 0 ? 0 : hechos / count,
                    minHeight: 6,
                    backgroundColor: visuals.panelAlt,
                    color: const Color(0xFF4F9A6A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: count,
              itemBuilder: (context, i) {
                final activo = i == selected;
                final hecho = done(i);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: activo
                        ? visuals.accent.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onSelect(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 7),
                        child: Row(
                          children: [
                            if (leading != null) ...[
                              leading!(i),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${i + 1}. ${title(i)}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: activo
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: hecho ? visuals.textMuted : null,
                                      decoration: hecho
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  if (subtitle != null &&
                                      subtitle!(i).isNotEmpty)
                                    Text(
                                      subtitle!(i),
                                      style: TextStyle(
                                        color: visuals.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: hecho
                                  ? 'Marcar como pendiente'
                                  : 'Marcar como hecho',
                              onPressed: () => onToggle(i),
                              icon: Icon(
                                hecho
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: hecho
                                    ? const Color(0xFF4F9A6A)
                                    : visuals.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStepNav extends StatelessWidget {
  const _MiniStepNav({
    required this.index,
    required this.count,
    required this.done,
    required this.onIndex,
    required this.onDone,
    required this.onUndo,
  });

  final int index;
  final int count;
  final bool done;
  final ValueChanged<int> onIndex;
  final VoidCallback onDone;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final estrecho = constraints.maxWidth < 470;
      return Row(
        children: [
          if (estrecho)
            IconButton.outlined(
              tooltip: 'Anterior',
              onPressed: index > 0 ? () => onIndex(index - 1) : null,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
            )
          else
            OutlinedButton.icon(
              onPressed: index > 0 ? () => onIndex(index - 1) : null,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Anterior'),
            ),
          const Spacer(),
          if (done && estrecho)
            IconButton(
              tooltip: 'Desmarcar',
              onPressed: onUndo,
              icon: const Icon(Icons.undo_rounded, size: 18),
            )
          else if (done)
            TextButton.icon(
              onPressed: onUndo,
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: const Text('Desmarcar'),
            ),
          const SizedBox(width: 8),
          FilledButton.icon(
            key: const ValueKey('miniature-step-done'),
            onPressed: done && index == count - 1 ? null : onDone,
            icon: Icon(
              done ? Icons.arrow_forward_rounded : Icons.check_rounded,
              size: 18,
            ),
            label: Text(done
                ? 'Siguiente'
                : index == count - 1
                    ? 'Hecho'
                    : 'Hecho y siguiente'),
          ),
        ],
      );
    });
  }
}

// --- Pintura guiada -----------------------------------------------------------

class _MiniPinturaTab extends StatelessWidget {
  const _MiniPinturaTab({
    required this.controller,
    required this.kit,
    required this.index,
    required this.onIndex,
  });

  final TodoWorkspace controller;
  final MiniatureKit kit;
  final int index;
  final ValueChanged<int> onIndex;

  Future<void> _editarPaso(BuildContext context, {int? indice}) async {
    final step = await showDialog<MiniaturePaintStep>(
      context: context,
      builder: (context) => _MiniStepDialog(
        initial: indice == null ? null : kit.guide[indice],
        paints: kit.paints.map((paint) => paint.name).toList(),
      ),
    );
    if (step != null) {
      controller.saveMiniatureGuideStep(kit.id, step, index: indice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    if (kit.guide.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Todavía no hay pasos de pintura.',
                style: TextStyle(color: visuals.textMuted)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _editarPaso(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Añadir paso'),
            ),
          ],
        ),
      );
    }
    final paso = kit.guide[index];
    final colores = _coloresHasta(kit, index);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 280,
          child: _MiniStepList(
            count: kit.guide.length,
            selected: index,
            done: (i) => kit.guide[i].done,
            title: (i) => kit.guide[i].title,
            subtitle: (i) => kit.guide[i].phase,
            leading: (i) {
              final valores = kit.guide[i].zones.values.toSet().toList();
              return SizedBox(
                width: 26,
                height: 26,
                child: valores.isEmpty
                    ? Icon(Icons.handyman_rounded,
                        size: 20, color: visuals.textMuted)
                    : _MiniSwatch(
                        color: _colorHex(valores.first),
                        size: 26,
                        metal: valores.first.endsWith('*'),
                      ),
              );
            },
            onSelect: onIndex,
            onToggle: (i) => controller.toggleMiniatureGuideStepDone(kit.id, i),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          flex: 10,
          child: _MiniGiro(
            key: const ValueKey('miniature-giro-pintura'),
            controller: controller,
            spins: kit.spins,
            title: 'Así queda pintada',
          ),
        ),
        const SizedBox(width: 18),
        SizedBox(
          width: 380,
          child: _SurfaceCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (paso.phase.isNotEmpty)
                      _SoftChip(label: paso.phase, color: visuals.accent),
                    const Spacer(),
                    PopupMenuButton<String>(
                      tooltip: 'Más opciones',
                      onSelected: (value) async {
                        switch (value) {
                          case 'edit':
                            await _editarPaso(context, indice: index);
                          case 'add':
                            await _editarPaso(context);
                          case 'up':
                            controller.moveMiniatureGuideStep(
                                kit.id, index, -1);
                            onIndex(index - 1);
                          case 'down':
                            controller.moveMiniatureGuideStep(kit.id, index, 1);
                            onIndex(index + 1);
                          case 'delete':
                            final ok = await _confirmarMiniatura(
                              context,
                              title: 'Eliminar paso',
                              message: 'Se borrará «${paso.title}».',
                            );
                            if (ok) {
                              controller.removeMiniatureGuideStep(
                                  kit.id, index);
                              if (index > 0) onIndex(index - 1);
                            }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                            value: 'edit', child: Text('Editar paso')),
                        const PopupMenuItem(
                            value: 'add', child: Text('Añadir paso al final')),
                        if (index > 0)
                          const PopupMenuItem(
                              value: 'up', child: Text('Subir')),
                        if (index < kit.guide.length - 1)
                          const PopupMenuItem(
                              value: 'down', child: Text('Bajar')),
                        const PopupMenuItem(
                            value: 'delete', child: Text('Eliminar')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  paso.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      if (paso.paints.isNotEmpty) ...[
                        Text(
                          'PINTURAS',
                          style: TextStyle(
                            color: visuals.textMuted,
                            fontSize: 11,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final nombre in paso.paints)
                          _MiniPaintRow(
                            nombre: nombre,
                            paint: kit.paintNamed(nombre),
                            onToggle: () {
                              final i = kit.paints
                                  .indexWhere((paint) => paint.name == nombre);
                              if (i != -1) {
                                controller.toggleMiniaturePaintOwned(kit.id, i);
                              }
                            },
                          ),
                        const SizedBox(height: 10),
                      ],
                      if (paso.zones.isNotEmpty) ...[
                        Text(
                          'ZONAS',
                          style: TextStyle(
                            color: visuals.textMuted,
                            fontSize: 11,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final zona in paso.zones.keys)
                              _SoftChip(
                                label: zona == 'todo'
                                    ? 'Toda la figura'
                                    : _zonasMiniatura[zona] ?? zona,
                                color: _colorHex(
                                    colores[zona] ?? paso.zones[zona] ?? ''),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(paso.description,
                          style: const TextStyle(height: 1.5, fontSize: 14.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _MiniStepNav(
                  index: index,
                  count: kit.guide.length,
                  done: paso.done,
                  onIndex: onIndex,
                  onDone: () {
                    if (!paso.done) {
                      controller.toggleMiniatureGuideStepDone(kit.id, index);
                    }
                    if (index < kit.guide.length - 1) onIndex(index + 1);
                  },
                  onUndo: () =>
                      controller.toggleMiniatureGuideStepDone(kit.id, index),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniPaintRow extends StatelessWidget {
  const _MiniPaintRow({
    required this.nombre,
    required this.paint,
    required this.onToggle,
  });

  final String nombre;
  final MiniaturePaint? paint;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final tengo = paint?.owned ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          _MiniSwatch(
            color: _colorHex(paint?.color ?? ''),
            size: 34,
            metal: _pinturaMetalica(nombre),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if ((paint?.kind ?? '').isNotEmpty)
                  Text(
                    paint!.kind,
                    style: TextStyle(color: visuals.textMuted, fontSize: 12.5),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: paint == null ? null : onToggle,
            icon: Icon(
              tengo
                  ? Icons.check_circle_rounded
                  : Icons.add_shopping_cart_rounded,
              size: 18,
              color: tengo ? const Color(0xFF4F9A6A) : null,
            ),
            label: Text(tengo ? 'La tengo' : 'Me falta'),
          ),
        ],
      ),
    );
  }
}

// --- Figuras ----------------------------------------------------------------

class _MiniFigurasTab extends StatelessWidget {
  const _MiniFigurasTab({required this.controller, required this.kit});

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
                'Pulsa una etapa para mover cada figura por el proceso.',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              label: const Text('Añadir figura'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 520,
              mainAxisExtent: 168,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
            ),
            itemCount: kit.models.length,
            itemBuilder: (context, index) => _MiniFiguraCard(
              controller: controller,
              kit: kit,
              model: kit.models[index],
              numero: index + 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniFiguraCard extends StatelessWidget {
  const _MiniFiguraCard({
    required this.controller,
    required this.kit,
    required this.model,
    required this.numero,
  });

  final TodoWorkspace controller;
  final MiniatureKit kit;
  final MiniatureModel model;
  final int numero;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final actual = model.status.index;
    final color = _colorEstadoMiniatura(context, model.status);
    return Container(
      key: ValueKey('miniature-model-${model.id}'),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: visuals.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: visuals.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 46,
                decoration: ShapeDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: const BeveledRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(18),
                      top: Radius.circular(4),
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$numero',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(model.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(
                      model.status.label,
                      style:
                          TextStyle(color: color, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
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
                      controller.renameMiniatureModel(kit.id, model.id, name);
                    }
                  } else if (value == 'remove' && context.mounted) {
                    final ok = await _confirmarMiniatura(
                      context,
                      title: 'Quitar figura',
                      message: 'Se quitará «${model.name}» de la caja.',
                      action: 'Quitar',
                    );
                    if (ok) controller.removeMiniatureModel(kit.id, model.id);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'rename', child: Text('Cambiar nombre')),
                  PopupMenuItem(value: 'remove', child: Text('Quitar')),
                ],
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              for (final status in MiniatureStatus.values) ...[
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => controller.setMiniatureModelStatus(
                        kit.id, model.id, status),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 3,
                                color: status.index == 0
                                    ? Colors.transparent
                                    : status.index <= actual
                                        ? color
                                        : visuals.panelBorder,
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: status.index == actual ? 34 : 26,
                              height: status.index == actual ? 34 : 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: status.index <= actual
                                    ? color
                                    : visuals.panelAlt,
                                border: Border.all(
                                  color: status.index <= actual
                                      ? color
                                      : visuals.panelBorder,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                _iconoEstadoMiniatura(status),
                                size: status.index == actual ? 17 : 13,
                                color: status.index <= actual
                                    ? Colors.white
                                    : visuals.textMuted,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 3,
                                color: status.index ==
                                        MiniatureStatus.values.length - 1
                                    ? Colors.transparent
                                    : status.index < actual
                                        ? color
                                        : visuals.panelBorder,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          status.label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: status.index == actual
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: status.index == actual
                                ? visuals.textStrong
                                : visuals.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// --- Galería ----------------------------------------------------------------

class _MiniGaleriaTab extends StatefulWidget {
  const _MiniGaleriaTab({required this.controller, required this.kit});

  final TodoWorkspace controller;
  final MiniatureKit kit;

  @override
  State<_MiniGaleriaTab> createState() => _MiniGaleriaTabState();
}

class _MiniGaleriaTabState extends State<_MiniGaleriaTab> {
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
    final kit = widget.kit;
    final oficiales = <String>[
      ...kit.gallery,
      if (kit.imagePath.isNotEmpty) kit.imagePath,
    ];
    return ListView(
      children: [
        Row(
          children: [
            Text('Tus miniaturas',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 10),
            Text(
              kit.photos.isEmpty
                  ? 'Aún no hay fotos'
                  : '${kit.photos.length} ${kit.photos.length == 1 ? 'foto' : 'fotos'}',
              style: TextStyle(color: visuals.textMuted),
            ),
            const Spacer(),
            if (_importing)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            FilledButton.tonalIcon(
              key: const ValueKey('miniature-add-photos'),
              onPressed: _importing ? null : _anadirFotos,
              icon: const Icon(Icons.add_a_photo_rounded, size: 18),
              label: const Text('Añadir fotos'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (kit.photos.isEmpty)
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: _importing ? null : _anadirFotos,
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: visuals.panelBorder, width: 1.5),
                color: visuals.panelAlt.withValues(alpha: 0.5),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_camera_outlined,
                        size: 38, color: visuals.textMuted),
                    const SizedBox(height: 8),
                    Text(
                      'Cuando las termines, añade aquí tus fotos.',
                      style: TextStyle(color: visuals.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          _MiniMosaico(
            controller: widget.controller,
            rutas: [
              for (final photo in kit.photos)
                photo.thumbnailPath.isNotEmpty
                    ? photo.thumbnailPath
                    : photo.imagePath,
            ],
            pies: [for (final photo in kit.photos) photo.caption],
            onOpen: (i) => _abrirVisor(
              context,
              widget.controller,
              rutas: [for (final photo in kit.photos) photo.imagePath],
              inicial: i,
              kitId: kit.id,
              fotos: kit.photos,
            ),
          ),
        if (oficiales.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Text('Referencia oficial',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 10),
              Text('Pintadas por Games Workshop',
                  style: TextStyle(color: visuals.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          _MiniMosaico(
            controller: widget.controller,
            rutas: oficiales,
            fondoBlanco: true,
            onOpen: (i) => _abrirVisor(
              context,
              widget.controller,
              rutas: oficiales,
              inicial: i,
            ),
          ),
        ],
      ],
    );
  }
}

class _MiniMosaico extends StatelessWidget {
  const _MiniMosaico({
    required this.controller,
    required this.rutas,
    required this.onOpen,
    this.pies = const <String>[],
    this.fondoBlanco = false,
  });

  final TodoWorkspace controller;
  final List<String> rutas;
  final List<String> pies;
  final ValueChanged<int> onOpen;
  final bool fondoBlanco;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: rutas.length,
      itemBuilder: (context, i) => Material(
        color: fondoBlanco ? Colors.white : _escenarioOscuro,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onOpen(i),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _MiniImage(controller: controller, path: rutas[i]),
              if (i < pies.length && pies[i].isNotEmpty)
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0xCC000000)],
                      ),
                    ),
                    child: Text(
                      pies[i],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Imagen con zoom: un clic amplía donde se pulsa y otro vuelve al tamaño
/// normal; también acerca con la rueda y se mueve arrastrando. Si se indica
/// [onTapOutside], pulsar fuera de la imagen lo llama.
class _MiniZoomable extends StatefulWidget {
  const _MiniZoomable({
    required this.child,
    this.onTapOutside,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTapOutside;
  final EdgeInsets padding;

  @override
  State<_MiniZoomable> createState() => _MiniZoomableState();
}

class _MiniZoomableState extends State<_MiniZoomable> {
  final TransformationController _transformacion = TransformationController();
  final GlobalKey _marco = GlobalKey();
  Offset _punto = Offset.zero;
  static const double _aumento = 2.6;

  @override
  void dispose() {
    _transformacion.dispose();
    super.dispose();
  }

  void _anotar(TapDownDetails detalles) {
    final caja = _marco.currentContext?.findRenderObject() as RenderBox?;
    _punto = caja?.globalToLocal(detalles.globalPosition) ?? Offset.zero;
  }

  void _alternar() {
    if (_transformacion.value.getMaxScaleOnAxis() > 1.01) {
      _transformacion.value = Matrix4.identity();
      return;
    }
    final escena = _transformacion.toScene(_punto);
    _transformacion.value = Matrix4.diagonal3Values(_aumento, _aumento, 1)
      ..setTranslationRaw(
        _punto.dx - escena.dx * _aumento,
        _punto.dy - escena.dy * _aumento,
        0,
      );
  }

  @override
  Widget build(BuildContext context) {
    final imagen = MouseRegion(
      cursor: SystemMouseCursors.zoomIn,
      child: GestureDetector(
        onTapDown: _anotar,
        onTap: _alternar,
        child: widget.child,
      ),
    );
    return KeyedSubtree(
      key: _marco,
      child: InteractiveViewer(
        transformationController: _transformacion,
        minScale: 1,
        maxScale: 6,
        child: widget.onTapOutside == null
            ? Padding(padding: widget.padding, child: imagen)
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTapOutside,
                child: Padding(
                  padding: widget.padding,
                  child: Center(child: imagen),
                ),
              ),
      ),
    );
  }
}

Future<void> _abrirVisor(
  BuildContext context,
  TodoWorkspace controller, {
  required List<String> rutas,
  required int inicial,
  String? kitId,
  List<MiniaturePhoto> fotos = const <MiniaturePhoto>[],
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => _MiniVisorFotos(
      controller: controller,
      rutas: rutas,
      inicial: inicial,
      kitId: kitId,
      fotos: fotos,
    ),
  );
}

class _MiniVisorFotos extends StatefulWidget {
  const _MiniVisorFotos({
    required this.controller,
    required this.rutas,
    required this.inicial,
    this.kitId,
    this.fotos = const <MiniaturePhoto>[],
  });

  final TodoWorkspace controller;
  final List<String> rutas;
  final int inicial;
  final String? kitId;
  final List<MiniaturePhoto> fotos;

  @override
  State<_MiniVisorFotos> createState() => _MiniVisorFotosState();
}

class _MiniVisorFotosState extends State<_MiniVisorFotos> {
  late int _actual = widget.inicial;

  bool get _esPropia => widget.kitId != null && _actual < widget.fotos.length;

  Future<void> _editarPie() async {
    final foto = widget.fotos[_actual];
    final texto = await _pedirTextoMiniatura(
      context,
      title: 'Pie de foto',
      label: 'Pie de foto',
      initial: foto.caption,
    );
    if (texto != null) {
      widget.controller
          .updateMiniaturePhotoCaption(widget.kitId!, foto.id, texto);
    }
  }

  Future<void> _borrar() async {
    final foto = widget.fotos[_actual];
    final ok = await _confirmarMiniatura(
      context,
      title: 'Eliminar foto',
      message: 'Se borrará esta foto.',
    );
    if (!ok) return;
    await widget.controller.removeMiniaturePhoto(widget.kitId!, foto.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.rutas.length;
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: _MiniZoomable(
              key: ValueKey('visor-$_actual'),
              onTapOutside: () => Navigator.of(context).pop(),
              padding: const EdgeInsets.fromLTRB(90, 70, 90, 70),
              child: _MiniImage(
                controller: widget.controller,
                path: widget.rutas[_actual],
                fit: BoxFit.contain,
                escala: 2,
                ajustada: true,
              ),
            ),
          ),
          Positioned(
            top: 18,
            left: 24,
            right: 24,
            child: Row(
              children: [
                Text(
                  '${_actual + 1} / $total',
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                if (_esPropia && widget.fotos[_actual].caption.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Text(
                    widget.fotos[_actual].caption,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ],
                const Spacer(),
                if (_esPropia) ...[
                  _MiniGlassButton(
                    icon: Icons.short_text_rounded,
                    label: 'Pie de foto',
                    onPressed: _editarPie,
                  ),
                  const SizedBox(width: 8),
                  _MiniGlassButton(
                    icon: Icons.delete_outline_rounded,
                    label: 'Eliminar',
                    onPressed: _borrar,
                  ),
                  const SizedBox(width: 8),
                ],
                _MiniGlassButton(
                  icon: Icons.close_rounded,
                  label: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          if (_actual > 0)
            Positioned(
              left: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filledTonal(
                  iconSize: 30,
                  onPressed: () => setState(() => _actual--),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
              ),
            ),
          if (_actual < total - 1)
            Positioned(
              right: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filledTonal(
                  iconSize: 30,
                  onPressed: () => setState(() => _actual++),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Diálogos de edición
// ---------------------------------------------------------------------------

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
            final paints = available.where(_selected.contains).toList();
            final initial = widget.initial;
            Navigator.of(context).pop(initial == null
                ? MiniaturePaintStep(
                    title: _title.text.trim(),
                    description: _description.text.trim(),
                    paints: paints,
                  )
                : initial.copyWith(
                    title: _title.text.trim(),
                    description: _description.text.trim(),
                    paints: paints,
                  ));
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
    builder: (context) =>
        _MiniKitEditorDialog(controller: controller, kit: kit),
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
                        decoration: const InputDecoration(labelText: 'Figuras'),
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
