part of 'app_shell.dart';

/// Datos de la franja de progreso que se pinta sobre la portada.
class _LibraryCardProgress {
  const _LibraryCardProgress({
    required this.icon,
    required this.label,
    this.fraction,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final double? fraction;
  final String? tooltip;

  int? get percent => fraction == null ? null : (fraction! * 100).round();
}

/// Progreso a mostrar en la tarjeta: solo para «En curso» y con datos reales.
/// [achievements] son los logros guardados en local (desbloqueados, total).
_LibraryCardProgress? _libraryCardProgress(
  LibraryItem item, {
  (int, int)? achievements,
}) {
  if (item.status != LibraryItemStatus.inProgress) return null;
  switch (item.type) {
    case LibraryItemType.game:
      if (achievements == null || achievements.$2 <= 0) return null;
      return _LibraryCardProgress(
        icon: _libraryIcon(item.type),
        label: '${achievements.$1} / ${achievements.$2} logros',
        fraction: (achievements.$1 / achievements.$2).clamp(0.0, 1.0),
      );
    case LibraryItemType.movieSeries:
      final label = textoProgresoManual(item);
      if (label == null) return null;
      return _LibraryCardProgress(
        icon: _libraryIcon(item.type),
        label: label,
        fraction: fraccionProgresoManual(item),
      );
    case LibraryItemType.book:
      final reading = item.reading;
      if (reading != null) {
        final total = bookPageTotal(item.pages, reading);
        final percent = bookReadingPercent(reading, total);
        final page = reading.page.trim();
        return _LibraryCardProgress(
          icon: _libraryIcon(item.type),
          label: page.isEmpty
              ? 'Leyendo'
              : total != null
                  ? '$page / $total páginas'
                  : 'Página $page',
          fraction: percent / 100,
          tooltip: [
            '$percent% leído',
            if (page.isNotEmpty)
              'Página $page${total != null ? ' de $total' : ''}',
            if (reading.chapter.trim().isNotEmpty) reading.chapter,
          ].join('\n'),
        );
      }
      final label = textoProgresoManual(item);
      if (label == null) return null;
      return _LibraryCardProgress(
        icon: _libraryIcon(item.type),
        label: label,
        fraction: fraccionProgresoManual(item),
      );
  }
}

/// Acción de «Marcar episodio visto» o «Marcar capítulo leído»; `null` si el
/// elemento no admite progreso manual.
VoidCallback? _libraryMarkProgressAction(
  BuildContext context,
  TodoWorkspace controller,
  LibraryItem item,
) {
  if (!admiteProgresoManual(item)) return null;
  return () {
    final resultado = controller.marcarUnidadDeProgreso(item.id);
    if (resultado == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final nuevo = resultado.nuevo;
    final texto = textoProgresoManual(nuevo) ?? '';
    final igual = resultado.anterior.progressCurrent == nuevo.progressCurrent;
    final total = nuevo.progressTotal;
    final enTotal =
        total != null && total > 0 && (nuevo.progressCurrent ?? 0) >= total;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Text(
            igual
                ? 'Ya estás en el total: $texto'
                : enTotal
                    ? 'Marcado: $texto. Has llegado al total; no se completa solo.'
                    : 'Marcado: $texto',
          ),
          action: igual
              ? null
              : SnackBarAction(
                  label: 'Deshacer',
                  onPressed: () =>
                      controller.updateLibraryItem(resultado.anterior),
                ),
        ),
      );
  };
}

String _libraryMarkProgressLabel(LibraryItem item) =>
    item.type == LibraryItemType.book
        ? 'Marcar capítulo leído'
        : 'Marcar episodio visto';

class _LibraryCoverGridCard extends StatefulWidget {
  const _LibraryCoverGridCard({
    required this.item,
    required this.controller,
    required this.showStatus,
    this.showTypeBadge = false,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final LibraryItem item;
  final TodoWorkspace controller;
  final bool showStatus;
  final bool showTypeBadge;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_LibraryCoverGridCard> createState() => _LibraryCoverGridCardState();
}

class _LibraryCoverGridCardState extends State<_LibraryCoverGridCard> {
  bool _hovered = false;
  (int, int)? _achievements;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAchievements());
  }

  @override
  void didUpdateWidget(covariant _LibraryCoverGridCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.status != widget.item.status) {
      unawaited(_loadAchievements());
    }
  }

  /// Lee los logros ya guardados en disco; nunca consulta la red.
  Future<void> _loadAchievements() async {
    final item = widget.item;
    if (item.type != LibraryItemType.game ||
        item.status != LibraryItemStatus.inProgress) {
      if (_achievements != null) setState(() => _achievements = null);
      return;
    }
    final saved = await widget.controller.steam.savedAchievements(item.id);
    if (!mounted) return;
    final list = saved?['achievements'];
    final found = list is List && list.isNotEmpty
        ? (
            list
                .where((entry) => entry is Map && entry['unlocked'] == true)
                .length,
            list.length,
          )
        : null;
    if (found != _achievements) setState(() => _achievements = found);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final progress = _libraryCardProgress(item, achievements: _achievements);
    final readingBadge = item.reading != null &&
        !(progress != null && item.type == LibraryItemType.book);
    final rewatchCount = _libraryRewatchCount(item);
    final collectionLabels = _libraryCollectionLabels(widget.controller, item);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onSecondaryTapDown: (details) => _showLibraryContextMenu(
          context: context,
          position: details.globalPosition,
          onPages: () => _openKnowledgeWorkspace(
            context,
            widget.controller,
            item,
          ),
          onComplete: item.status == LibraryItemStatus.completed
              ? null
              : () => _completeLibraryItem(
                    context,
                    widget.controller,
                    item,
                  ),
          onRating: item.status != LibraryItemStatus.completed
              ? null
              : () => _editLibraryRating(
                    context,
                    widget.controller,
                    item,
                  ),
          onProgress:
              _libraryMarkProgressAction(context, widget.controller, item),
          progressLabel: _libraryMarkProgressLabel(item),
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(7),
          child: AnimatedContainer(
            key: ValueKey('library-cover-card-${item.id}'),
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            transform: Matrix4.identity()
              ..scaleByDouble(
                _hovered ? 1.025 : 1.0,
                _hovered ? 1.025 : 1.0,
                1,
                1,
              ),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF18202A),
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                if (item.status == LibraryItemStatus.completed)
                  BoxShadow(
                    color: const Color(0xFF5F7F49).withValues(alpha: 0.38),
                    blurRadius: _hovered ? 26 : 18,
                    spreadRadius: _hovered ? 2 : 1,
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: _hovered ? 0.26 : 0.18),
                  blurRadius: _hovered ? 22 : 16,
                  offset: Offset(0, _hovered ? 11 : 8),
                ),
              ],
            ),
            foregroundDecoration: item.status == LibraryItemStatus.completed
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: const Color(0xFF5F7F49),
                      width: 4,
                    ),
                  )
                : null,
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _LibraryCoverImage(
                  source: item.coverUrl,
                  type: item.type,
                  iconSize: 44,
                ),
                AnimatedOpacity(
                  opacity: _hovered ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00000000),
                          Color(0x1A000000),
                          Color(0xB8000000),
                        ],
                        stops: [0.42, 0.72, 1],
                      ),
                    ),
                  ),
                ),
                if (widget.showTypeBadge ||
                    item.rating != null ||
                    readingBadge ||
                    rewatchCount > 1)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (widget.showTypeBadge)
                          _LibraryCoverTypeBadge(
                            key: ValueKey('library-cover-type-${item.id}'),
                            type: item.type,
                          ),
                        if (widget.showTypeBadge &&
                            (item.rating != null ||
                                readingBadge ||
                                rewatchCount > 1))
                          const SizedBox(height: 5),
                        if (item.rating != null)
                          _LibraryPosterBadge(
                            icon: Icons.star_rounded,
                            label: _formatRating(item.rating!),
                          ),
                        if (readingBadge) ...[
                          if (item.rating != null) const SizedBox(height: 5),
                          BookReadingBadge(
                              reading: item.reading!,
                              totalPages:
                                  bookPageTotal(item.pages, item.reading)),
                        ],
                        if ((item.rating != null || readingBadge) &&
                            rewatchCount > 1)
                          const SizedBox(height: 5),
                        if (rewatchCount > 1)
                          _LibraryRewatchBadge(count: rewatchCount),
                      ],
                    ),
                  ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  left: 12,
                  right: 12,
                  bottom: progress != null
                      ? (_hovered ? 78 : 66)
                      : (_hovered ? 50 : 38),
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _hovered ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              shadows: [
                                Shadow(
                                  color: Color(0xAA000000),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          if (collectionLabels != null) ...[
                            const SizedBox(height: 6),
                            _LibraryCollectionChips(
                              controller: widget.controller,
                              item: item,
                              compact: true,
                              onDark: true,
                              showUniverse: true,
                              alignment: WrapAlignment.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (progress != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _LibraryProgressStrip(
                      key: ValueKey('library-cover-progress-${item.id}'),
                      progress: progress,
                    ),
                  )
                else
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 8,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE63B4654),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.26),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        _libraryItemStatusMeta(item),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.showStatus)
                  Positioned(
                    left: 8,
                    bottom: progress != null ? 70 : 42,
                    child: _LibraryStatusBadge(status: item.status),
                  ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _LibraryCoverMenuButton(
                    onPages: () => _openKnowledgeWorkspace(
                      context,
                      widget.controller,
                      item,
                    ),
                    onComplete: item.status == LibraryItemStatus.completed
                        ? null
                        : () => _completeLibraryItem(
                              context,
                              widget.controller,
                              item,
                            ),
                    onRating: item.status != LibraryItemStatus.completed
                        ? null
                        : () => _editLibraryRating(
                              context,
                              widget.controller,
                              item,
                            ),
                    onProgress: _libraryMarkProgressAction(
                        context, widget.controller, item),
                    progressLabel: _libraryMarkProgressLabel(item),
                    onEdit: widget.onEdit,
                    onDelete: widget.onDelete,
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

/// Franja degradada sobre la parte baja de la portada con el progreso.
class _LibraryProgressStrip extends StatelessWidget {
  const _LibraryProgressStrip({super.key, required this.progress});

  final _LibraryCardProgress progress;

  @override
  Widget build(BuildContext context) {
    final fraction = progress.fraction;
    final percent = progress.percent;
    final strip = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xC2000000)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 26, 11, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(progress.icon, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    progress.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (percent != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$percent %',
                    style: const TextStyle(
                      color: Color(0xFFF3C77A),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
            if (fraction != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: fraction,
                        child: const ColoredBox(color: Color(0xFFE8A23B)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    final tooltip = progress.tooltip;
    return tooltip == null ? strip : Tooltip(message: tooltip, child: strip);
  }
}

class _LibraryPosterBadge extends StatelessWidget {
  const _LibraryPosterBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xD9202732),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFFF7D36B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryCoverTypeBadge extends StatelessWidget {
  const _LibraryCoverTypeBadge({super.key, required this.type});

  final LibraryItemType type;

  @override
  Widget build(BuildContext context) {
    final color = _libraryColor(type);
    return Tooltip(
      message: _libraryTypeSingularLabelForType(type),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xD9202732),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Icon(_libraryIcon(type), size: 15, color: color),
      ),
    );
  }
}

class _LibraryRewatchBadge extends StatelessWidget {
  const _LibraryRewatchBadge({required this.count, this.compact = false});

  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Vista $count veces',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 8,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: compact ? const Color(0xFFEFF4E7) : const Color(0xDDEFF4E7),
          borderRadius: BorderRadius.circular(999),
          boxShadow: compact
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              const Icon(
                Icons.replay_rounded,
                size: 15,
                color: Color(0xFF607A4D),
              ),
              const SizedBox(width: 3),
            ],
            Text(
              'x$count',
              style: const TextStyle(
                color: Color(0xFF607A4D),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryStatusBadge extends StatelessWidget {
  const _LibraryStatusBadge({required this.status});

  final LibraryItemStatus status;

  @override
  Widget build(BuildContext context) {
    final style = switch (status) {
      LibraryItemStatus.completed => (
          label: 'Completado',
          background: const Color(0xFFE7F2DF),
          foreground: const Color(0xFF597743),
          icon: Icons.check_rounded,
        ),
      LibraryItemStatus.inProgress => (
          label: 'En curso',
          background: const Color(0xFFFFEFD9),
          foreground: const Color(0xFFC77721),
          icon: Icons.play_arrow_rounded,
        ),
      LibraryItemStatus.pending => (
          label: 'Pendiente',
          background: const Color(0xFFECEFF3),
          foreground: const Color(0xFF687384),
          icon: Icons.bookmark_outline_rounded,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 12, color: style.foreground),
          const SizedBox(width: 3),
          Text(
            style.label,
            style: TextStyle(
              color: style.foreground,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryCoverMenuButton extends StatelessWidget {
  const _LibraryCoverMenuButton({
    this.onPages,
    this.onComplete,
    this.onRating,
    this.onProgress,
    this.progressLabel = 'Marcar episodio visto',
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback? onPages;
  final VoidCallback? onComplete;
  final VoidCallback? onRating;
  final VoidCallback? onProgress;
  final String progressLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_LibraryContextAction>(
      tooltip: 'Opciones',
      position: PopupMenuPosition.under,
      onSelected: (action) {
        if (action == _LibraryContextAction.pages) {
          onPages?.call();
        } else if (action == _LibraryContextAction.complete) {
          onComplete?.call();
        } else if (action == _LibraryContextAction.rating) {
          onRating?.call();
        } else if (action == _LibraryContextAction.progress) {
          onProgress?.call();
        } else if (action == _LibraryContextAction.edit) {
          onEdit();
        } else if (action == _LibraryContextAction.delete) {
          onDelete();
        }
      },
      itemBuilder: (context) => [
        if (onPages != null)
          const PopupMenuItem(
            value: _LibraryContextAction.pages,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.description_outlined),
              title: Text('Abrir páginas'),
            ),
          ),
        if (onComplete != null)
          const PopupMenuItem(
            value: _LibraryContextAction.complete,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.check_circle_outline_rounded),
              title: Text('Marcar como completado'),
            ),
          ),
        if (onRating != null)
          const PopupMenuItem(
            value: _LibraryContextAction.rating,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.star_outline_rounded),
              title: Text('Cambiar/añadir valoración'),
            ),
          ),
        if (onProgress != null)
          PopupMenuItem(
            value: _LibraryContextAction.progress,
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.add_task_rounded),
              title: Text(progressLabel),
            ),
          ),
        const PopupMenuItem(
          value: _LibraryContextAction.edit,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.edit_outlined),
            title: Text('Editar'),
          ),
        ),
        const PopupMenuItem(
          value: _LibraryContextAction.delete,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.delete_outline_rounded),
            title: Text('Borrar'),
          ),
        ),
      ],
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xC2202732),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: const Icon(
          Icons.more_horiz_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

class _LibraryItemRow extends StatelessWidget {
  const _LibraryItemRow({
    required this.item,
    required this.controller,
    this.showStatus = false,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final LibraryItem item;
  final TodoWorkspace controller;
  final bool showStatus;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final rewatchCount = _libraryRewatchCount(item);
    final collectionLabels = _libraryCollectionLabels(controller, item);
    final seriesLabels = _librarySeriesLabels(item);
    return GestureDetector(
      onSecondaryTapDown: (details) => _showLibraryContextMenu(
        context: context,
        position: details.globalPosition,
        onPages: () => _openKnowledgeWorkspace(context, controller, item),
        onComplete: item.status == LibraryItemStatus.completed
            ? null
            : () => _completeLibraryItem(context, controller, item),
        onRating: item.status != LibraryItemStatus.completed
            ? null
            : () => _editLibraryRating(context, controller, item),
        onProgress: _libraryMarkProgressAction(context, controller, item),
        progressLabel: _libraryMarkProgressLabel(item),
        onEdit: onEdit,
        onDelete: onDelete,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          child: Row(
            children: [
              _LibraryThumbnail(item: item),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (collectionLabels != null ||
                        rewatchCount > 1 ||
                        seriesLabels != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (showStatus)
                            _LibraryStatusBadge(status: item.status),
                          if (showStatus &&
                              (collectionLabels != null ||
                                  rewatchCount > 1 ||
                                  seriesLabels != null))
                            const SizedBox(width: 5),
                          if (collectionLabels != null)
                            Flexible(
                              child: _LibraryCollectionChips(
                                controller: controller,
                                item: item,
                                compact: true,
                              ),
                            ),
                          if (rewatchCount > 1)
                            Padding(
                              padding: EdgeInsets.only(
                                left: collectionLabels == null ? 0 : 5,
                              ),
                              child: _LibraryRewatchBadge(
                                count: rewatchCount,
                                compact: true,
                              ),
                            ),
                          if (seriesLabels != null)
                            Flexible(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: collectionLabels == null &&
                                          rewatchCount <= 1
                                      ? 0
                                      : 5,
                                ),
                                child: _LibrarySeriesChips(
                                  labels: seriesLabels,
                                  compact: true,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _libraryItemStatusMeta(item),
                style:
                    TextStyle(color: context.visuals.textMuted, fontSize: 13),
              ),
              if (item.reading != null) ...[
                const SizedBox(width: 10),
                BookReadingBadge(
                    reading: item.reading!,
                    totalPages: bookPageTotal(item.pages, item.reading)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryCollectionChips extends StatelessWidget {
  const _LibraryCollectionChips({
    required this.controller,
    required this.item,
    this.compact = false,
    this.singleLine = false,
    this.onDark = false,
    this.alignment = WrapAlignment.start,
    this.showUniverse = false,
  });

  final TodoWorkspace controller;
  final LibraryItem item;
  final bool showUniverse;
  final bool compact;
  final bool singleLine;
  final bool onDark;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final labels = _libraryCollectionLabels(controller, item);
    if (labels == null) {
      return const SizedBox.shrink();
    }
    final universe = showUniverse ? labels.universe : null;
    if (compact || singleLine) {
      final row = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (universe != null && singleLine) ...[
            Flexible(
              child: _LibraryCollectionChip(
                label: universe,
                item: item,
                compact: compact,
                onDark: onDark,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: _LibraryCollectionChip(
              label: labels.saga,
              item: item,
              compact: compact,
              onDark: onDark,
            ),
          ),
          if (labels.installment != null) ...[
            const SizedBox(width: 5),
            _LibraryCollectionChip(
              label: labels.installment!,
              item: item,
              compact: compact,
              onDark: onDark,
            ),
          ],
        ],
      );
      if (universe == null || singleLine) return row;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LibraryCollectionChip(
            label: universe,
            item: item,
            compact: compact,
            onDark: onDark,
          ),
          const SizedBox(height: 4),
          row,
        ],
      );
    }
    return Wrap(
      spacing: 7,
      runSpacing: 5,
      alignment: alignment,
      children: [
        _LibraryCollectionChip(
          label: labels.saga,
          item: item,
          compact: compact,
          onDark: onDark,
        ),
        if (labels.installment != null)
          _LibraryCollectionChip(
            label: labels.installment!,
            item: item,
            compact: compact,
            onDark: onDark,
          ),
      ],
    );
  }
}

class _LibraryCollectionChip extends StatelessWidget {
  const _LibraryCollectionChip({
    required this.label,
    required this.item,
    required this.compact,
    required this.onDark,
  });

  final String label;
  final LibraryItem item;
  final bool compact;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = _libraryColor(item.type);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.92)
            : color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: compact ? 10.5 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LibrarySeriesChips extends StatelessWidget {
  const _LibrarySeriesChips({required this.labels, this.compact = false});

  final ({String seasons, String? upcoming}) labels;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: _LibrarySeriesChip(
              label: labels.seasons,
              tooltip: 'Temporadas disponibles',
            ),
          ),
          if (labels.upcoming != null) ...[
            const SizedBox(width: 5),
            Flexible(
              child: _LibrarySeriesChip(
                label: labels.upcoming!,
                tooltip: 'Siguiente temporada confirmada',
              ),
            ),
          ],
        ],
      );
    }
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        _LibrarySeriesChip(
          label: labels.seasons,
          tooltip: 'Temporadas disponibles',
        ),
        if (labels.upcoming != null)
          _LibrarySeriesChip(
            label: labels.upcoming!,
            tooltip: 'Siguiente temporada confirmada',
          ),
      ],
    );
  }
}

class _LibrarySeriesChip extends StatelessWidget {
  const _LibrarySeriesChip({required this.label, required this.tooltip});

  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0D9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFC77721),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _LibraryThumbnail extends StatelessWidget {
  const _LibraryThumbnail({required this.item, this.small = false});

  final LibraryItem item;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 34.0 : 52.0;
    final coverUrl = item.coverUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(small ? 10 : 12),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _libraryColor(item.type).withValues(alpha: 0.14),
        ),
        child: _LibraryCoverImage(
          source: coverUrl,
          type: item.type,
          iconSize: small ? 18 : 24,
        ),
      ),
    );
  }
}
