part of 'knowledge_workspace_page.dart';

class _KnowledgeMediaBlockBuilder extends BlockComponentBuilder {
  _KnowledgeMediaBlockBuilder(
    this.service, {
    required this.editable,
    required this.onUpdate,
  });

  final KnowledgeService service;
  final bool editable;
  final Future<void> Function(Node, Map<String, dynamic>) onUpdate;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    return _KnowledgeMediaBlock(
      key: blockComponentContext.node.key,
      node: blockComponentContext.node,
      service: service,
      editable: editable,
      onUpdate: onUpdate,
      configuration: configuration,
    );
  }

  @override
  BlockComponentValidate get validate => (node) => node.children.isEmpty;
}

class _KnowledgeMediaBlock extends BlockComponentStatefulWidget {
  const _KnowledgeMediaBlock({
    required super.key,
    required super.node,
    required super.configuration,
    required this.service,
    required this.editable,
    required this.onUpdate,
  });

  final KnowledgeService service;
  final bool editable;
  final Future<void> Function(Node, Map<String, dynamic>) onUpdate;

  @override
  State<_KnowledgeMediaBlock> createState() => _KnowledgeMediaBlockState();
}

class _KnowledgeMediaBlockState extends State<_KnowledgeMediaBlock> {
  Player? _player;
  VideoController? _videoController;
  bool _imageSelected = false;
  double? _draftImageWidth;

  KnowledgeAsset? get asset => widget.service
      .assetById(widget.node.attributes['knowledgeAssetId']?.toString() ?? '');

  @override
  void initState() {
    super.initState();
    final current = asset;
    if (current?.kind == KnowledgeAssetKind.audio ||
        current?.kind == KnowledgeAssetKind.video) {
      _player = Player();
      if (current?.kind == KnowledgeAssetKind.video) {
        _videoController = VideoController(_player!);
      }
      final path =
          current == null ? '' : widget.service.absoluteAssetPath(current);
      if (path.isNotEmpty) unawaited(_player!.open(Media(path), play: false));
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = asset;
    if (current == null) {
      final source = widget.node.attributes['url']?.toString() ?? '';
      if (widget.node.type == 'image' && source.isNotEmpty) {
        return _buildImageBlock(source);
      }
      return const Padding(
          padding: EdgeInsets.all(16), child: Text('Recurso no disponible.'));
    }
    final path = widget.service.absoluteAssetPath(current);
    if (current.kind == KnowledgeAssetKind.image) {
      return _buildImageBlock(path);
    }
    Widget child;
    switch (current.kind) {
      case KnowledgeAssetKind.video:
        child =
            SizedBox(height: 360, child: Video(controller: _videoController!));
      case KnowledgeAssetKind.audio:
        child = StreamBuilder<bool>(
          stream: _player!.stream.playing,
          builder: (context, snapshot) => ListTile(
            leading: IconButton(
              onPressed: () =>
                  snapshot.data == true ? _player!.pause() : _player!.play(),
              icon: Icon(
                  snapshot.data == true
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  size: 36),
            ),
            title:
                Text(widget.node.attributes['caption']?.toString() ?? 'Audio'),
            subtitle: const Text('Recurso local gestionado'),
          ),
        );
      case KnowledgeAssetKind.pdf:
        child = SizedBox(height: 520, child: PdfViewer.file(path));
      case KnowledgeAssetKind.file:
        child = ListTile(
          leading: const Icon(Icons.insert_drive_file_outlined, size: 34),
          title:
              Text(widget.node.attributes['caption']?.toString() ?? 'Archivo'),
          subtitle: Text('${(current.size / 1024).toStringAsFixed(1)} KB'),
          trailing: const Icon(Icons.open_in_new_rounded),
          onTap: () => launchUrl(Uri.file(path)),
        );
      case KnowledgeAssetKind.image:
        throw StateError('Las imágenes se construyen como bloques editables.');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F4EE),
          border: Border.all(color: const Color(0xFFE3D8CB)),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }

  Widget _buildImageBlock(String path) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 900.0;
        final minWidth = maxWidth < 160 ? maxWidth : 160.0;
        final storedWidth = _nullableAttributeDouble('knowledgeImageWidth') ??
            _nullableAttributeDouble('width') ??
            maxWidth;
        final imageWidth = (_draftImageWidth ?? storedWidth)
            .clamp(minWidth, maxWidth)
            .toDouble();
        final decodeWidth =
            (imageWidth * MediaQuery.devicePixelRatioOf(context) * 1.25)
                .ceil()
                .clamp(1, 2400);
        final blockAlignment = switch (
            widget.node.attributes['knowledgeImageAlignment']?.toString() ??
                widget.node.attributes['align']?.toString()) {
          'start' || 'left' => Alignment.centerLeft,
          'end' || 'right' => Alignment.centerRight,
          _ => Alignment.center,
        };
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Align(
            alignment: blockAlignment,
            child: SizedBox(
              width: imageWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.editable
                    ? () => setState(() => _imageSelected = true)
                    : null,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F4EE),
                        border: Border.all(
                          color: _imageSelected
                              ? const Color(0xFF708A5B)
                              : const Color(0xFFE3D8CB),
                          width: _imageSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _buildImageViewport(path, decodeWidth),
                    ),
                    if (_imageSelected && widget.editable) ...[
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _buildImageToolbar(
                          path: path,
                          width: imageWidth,
                          maxWidth: maxWidth,
                        ),
                      ),
                      Positioned(
                        right: -7,
                        bottom: -7,
                        child: Tooltip(
                          message: 'Arrastra para cambiar el tamaño',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragUpdate: (details) {
                              setState(() {
                                _draftImageWidth =
                                    (imageWidth + details.delta.dx)
                                        .clamp(minWidth, maxWidth)
                                        .toDouble();
                              });
                            },
                            onHorizontalDragEnd: (_) {
                              final width = _draftImageWidth ?? imageWidth;
                              _updateImageAttributes(<String, dynamic>{
                                'knowledgeImageWidth': width
                              });
                            },
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0xFF607A4D),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: const Color(0xFFFFFCF8), width: 2),
                                boxShadow: const <BoxShadow>[
                                  BoxShadow(
                                      color: Color(0x33000000), blurRadius: 4),
                                ],
                              ),
                              child: const Icon(Icons.open_in_full_rounded,
                                  size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageViewport(String path, int decodeWidth) {
    final aspectRatio =
        _nullableAttributeDouble('knowledgeImageCropAspectRatio');
    if (aspectRatio == null) {
      return _knowledgeImageWidget(
        path,
        cacheWidth: decodeWidth,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => const SizedBox(
          height: 160,
          child: Center(child: Text('No se pudo mostrar la imagen.')),
        ),
      );
    }
    final zoom = _attributeDouble('knowledgeImageCropZoom', 1).clamp(1, 4);
    final focusX =
        _attributeDouble('knowledgeImageCropX', 0).clamp(-1, 1).toDouble();
    final focusY =
        _attributeDouble('knowledgeImageCropY', 0).clamp(-1, 1).toDouble();
    return AspectRatio(
      aspectRatio: aspectRatio.clamp(0.35, 3).toDouble(),
      child: ClipRect(
        child: Transform.scale(
          scale: zoom.toDouble(),
          child: _knowledgeImageWidget(
            path,
            cacheWidth: decodeWidth,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            alignment: Alignment(focusX, focusY),
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Text('No se pudo mostrar la imagen.'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageToolbar({
    required String path,
    required double width,
    required double maxWidth,
  }) {
    return Material(
      color: const Color(0xF7FFFCF8),
      elevation: 3,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 38,
        padding: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD9CCBD)),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${width.round()} px',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            IconButton(
              onPressed: () => _showCropDialog(path),
              tooltip: 'Recortar imagen',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.crop_rounded, size: 18),
            ),
            PopupMenuButton<_KnowledgeImageAction>(
              tooltip: 'Opciones de imagen',
              iconSize: 18,
              onSelected: (action) => _applyImageAction(action, maxWidth),
              itemBuilder: (context) =>
                  const <PopupMenuEntry<_KnowledgeImageAction>>[
                PopupMenuItem(
                  value: _KnowledgeImageAction.width25,
                  child: Text('Tamaño: 25 %'),
                ),
                PopupMenuItem(
                  value: _KnowledgeImageAction.width50,
                  child: Text('Tamaño: 50 %'),
                ),
                PopupMenuItem(
                  value: _KnowledgeImageAction.width75,
                  child: Text('Tamaño: 75 %'),
                ),
                PopupMenuItem(
                  value: _KnowledgeImageAction.width100,
                  child: Text('Ajustar al ancho'),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: _KnowledgeImageAction.alignStart,
                  child: Text('Alinear a la izquierda'),
                ),
                PopupMenuItem(
                  value: _KnowledgeImageAction.alignCenter,
                  child: Text('Centrar'),
                ),
                PopupMenuItem(
                  value: _KnowledgeImageAction.alignEnd,
                  child: Text('Alinear a la derecha'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _applyImageAction(_KnowledgeImageAction action, double maxWidth) {
    switch (action) {
      case _KnowledgeImageAction.width25:
        _setImageWidth(maxWidth * 0.25, maxWidth);
      case _KnowledgeImageAction.width50:
        _setImageWidth(maxWidth * 0.5, maxWidth);
      case _KnowledgeImageAction.width75:
        _setImageWidth(maxWidth * 0.75, maxWidth);
      case _KnowledgeImageAction.width100:
        _setImageWidth(maxWidth, maxWidth);
      case _KnowledgeImageAction.alignStart:
        _updateImageAttributes(
            <String, dynamic>{'knowledgeImageAlignment': 'start'});
      case _KnowledgeImageAction.alignCenter:
        _updateImageAttributes(
            <String, dynamic>{'knowledgeImageAlignment': 'center'});
      case _KnowledgeImageAction.alignEnd:
        _updateImageAttributes(
            <String, dynamic>{'knowledgeImageAlignment': 'end'});
    }
  }

  void _setImageWidth(double width, double maxWidth) {
    final minimum = maxWidth < 160 ? maxWidth : 160.0;
    final next = width.clamp(minimum, maxWidth).toDouble();
    setState(() => _draftImageWidth = next);
    _updateImageAttributes(<String, dynamic>{'knowledgeImageWidth': next});
  }

  Future<void> _showCropDialog(String path) async {
    final result = await showDialog<_KnowledgeImageCropSettings>(
      context: context,
      builder: (context) => _KnowledgeImageCropDialog(
        imagePath: path,
        initial: _KnowledgeImageCropSettings(
          aspectRatio:
              _nullableAttributeDouble('knowledgeImageCropAspectRatio'),
          zoom: _attributeDouble('knowledgeImageCropZoom', 1),
          focusX: _attributeDouble('knowledgeImageCropX', 0),
          focusY: _attributeDouble('knowledgeImageCropY', 0),
        ),
      ),
    );
    if (result == null || !mounted) return;
    _updateImageAttributes(<String, dynamic>{
      'knowledgeImageCropAspectRatio': result.aspectRatio,
      'knowledgeImageCropZoom': result.zoom,
      'knowledgeImageCropX': result.focusX,
      'knowledgeImageCropY': result.focusY,
    });
  }

  double _attributeDouble(String key, double fallback) =>
      _nullableAttributeDouble(key) ?? fallback;

  double? _nullableAttributeDouble(String key) {
    final value = widget.node.attributes[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  void _updateImageAttributes(Map<String, dynamic> attributes) {
    unawaited(widget.onUpdate(widget.node, attributes));
  }
}

enum _KnowledgeImageAction {
  width25,
  width50,
  width75,
  width100,
  alignStart,
  alignCenter,
  alignEnd,
}

class _KnowledgeImageCropSettings {
  const _KnowledgeImageCropSettings({
    required this.aspectRatio,
    required this.zoom,
    required this.focusX,
    required this.focusY,
  });

  final double? aspectRatio;
  final double zoom;
  final double focusX;
  final double focusY;
}

class _KnowledgeImageCropDialog extends StatefulWidget {
  const _KnowledgeImageCropDialog({
    required this.imagePath,
    required this.initial,
  });

  final String imagePath;
  final _KnowledgeImageCropSettings initial;

  @override
  State<_KnowledgeImageCropDialog> createState() =>
      _KnowledgeImageCropDialogState();
}

class _KnowledgeImageCropDialogState extends State<_KnowledgeImageCropDialog> {
  late bool _enabled;
  late double _ratio;
  late double _zoom;
  late double _focusX;
  late double _focusY;
  late bool _customRatio;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initial.aspectRatio != null;
    _ratio = widget.initial.aspectRatio ?? 16 / 9;
    _zoom = widget.initial.zoom.clamp(1, 4).toDouble();
    _focusX = widget.initial.focusX.clamp(-1, 1).toDouble();
    _focusY = widget.initial.focusY.clamp(-1, 1).toDouble();
    _customRatio = _enabled && !_isPresetRatio(_ratio);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.crop_rounded, color: Color(0xFF607A4D)),
                  SizedBox(width: 10),
                  Text('Recortar imagen',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'El recorte no modifica el archivo original. Puedes cambiarlo o quitarlo cuando quieras.',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 18),
              Expanded(child: _buildPreview()),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Original'),
                    selected: !_enabled,
                    onSelected: (_) => setState(() {
                      _enabled = false;
                      _customRatio = false;
                    }),
                  ),
                  _ratioChip('Cuadrada', 1),
                  _ratioChip('4:3', 4 / 3),
                  _ratioChip('16:9', 16 / 9),
                  _ratioChip('Vertical 3:4', 3 / 4),
                  ChoiceChip(
                    label: const Text('Libre'),
                    selected: _enabled && _customRatio,
                    onSelected: (_) => setState(() {
                      _enabled = true;
                      _customRatio = true;
                    }),
                  ),
                ],
              ),
              if (_enabled) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 104, child: Text('Zoom')),
                    Expanded(
                      child: Slider(
                        value: _zoom,
                        min: 1,
                        max: 4,
                        divisions: 30,
                        label: '${_zoom.toStringAsFixed(1)}×',
                        onChanged: (value) => setState(() => _zoom = value),
                      ),
                    ),
                  ],
                ),
                if (_customRatio)
                  Row(
                    children: [
                      const SizedBox(
                        width: 104,
                        child: Text(
                          'Proporción',
                          key: ValueKey('knowledge-image-crop-ratio-label'),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _ratio.clamp(0.5, 2.4),
                          min: 0.5,
                          max: 2.4,
                          divisions: 38,
                          label: _ratio.toStringAsFixed(2),
                          onChanged: (value) => setState(() => _ratio = value),
                        ),
                      ),
                    ],
                  ),
                const Text(
                  'Arrastra la imagen en la vista previa para elegir el punto de enfoque.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF777168)),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _enabled = false;
                      _customRatio = false;
                      _ratio = 16 / 9;
                      _zoom = 1;
                      _focusX = 0;
                      _focusY = 0;
                    }),
                    child: const Text('Restablecer'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      _KnowledgeImageCropSettings(
                        aspectRatio: _enabled ? _ratio : null,
                        zoom: _enabled ? _zoom : 1,
                        focusX: _enabled ? _focusX : 0,
                        focusY: _enabled ? _focusY : 0,
                      ),
                    ),
                    child: const Text('Aplicar recorte'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ratio = _enabled ? _ratio.clamp(0.5, 2.4).toDouble() : 16 / 9;
        var width = constraints.maxWidth;
        var height = width / ratio;
        if (height > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = height * ratio;
        }
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: GestureDetector(
              key: const ValueKey('knowledge-image-crop-preview'),
              behavior: HitTestBehavior.opaque,
              onPanUpdate: !_enabled
                  ? null
                  : (details) {
                      setState(() {
                        _focusX = (_focusX - (details.delta.dx / width) * 2)
                            .clamp(-1, 1)
                            .toDouble();
                        _focusY = (_focusY - (details.delta.dy / height) * 2)
                            .clamp(-1, 1)
                            .toDouble();
                      });
                    },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF24231F),
                  border: Border.all(color: const Color(0xFF607A4D), width: 2),
                ),
                child: ClipRect(
                  child: Transform.scale(
                    scale: _enabled ? _zoom : 1,
                    child: _knowledgeImageWidget(
                      widget.imagePath,
                      width: double.infinity,
                      height: double.infinity,
                      fit: _enabled ? BoxFit.cover : BoxFit.contain,
                      alignment: Alignment(_focusX, _focusY),
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _ratioChip(String label, double ratio) {
    return ChoiceChip(
      label: Text(label),
      selected: _enabled && !_customRatio && (_ratio - ratio).abs() < 0.01,
      onSelected: (_) => setState(() {
        _enabled = true;
        _customRatio = false;
        _ratio = ratio;
      }),
    );
  }

  bool _isPresetRatio(double ratio) => <double>[1, 4 / 3, 16 / 9, 3 / 4]
      .any((value) => (value - ratio).abs() < 0.01);
}

Widget _knowledgeImageWidget(
  String source, {
  double? width,
  double? height,
  int? cacheWidth,
  required BoxFit fit,
  Alignment alignment = Alignment.center,
  FilterQuality filterQuality = FilterQuality.medium,
  ImageErrorWidgetBuilder? errorBuilder,
}) {
  final uri = Uri.tryParse(source);
  if (uri?.scheme == 'http' || uri?.scheme == 'https') {
    return Image.network(
      source,
      width: width,
      height: height,
      cacheWidth: cacheWidth,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      errorBuilder: errorBuilder,
    );
  }
  if (uri?.scheme == 'data') {
    try {
      return Image.memory(
        UriData.parse(source).contentAsBytes(),
        width: width,
        height: height,
        cacheWidth: cacheWidth,
        fit: fit,
        alignment: alignment,
        filterQuality: filterQuality,
        errorBuilder: errorBuilder,
      );
    } catch (_) {
      // La vista de error uniforme se construye debajo.
    }
  }
  return Image.file(
    File(source),
    width: width,
    height: height,
    cacheWidth: cacheWidth,
    fit: fit,
    alignment: alignment,
    filterQuality: filterQuality,
    errorBuilder: errorBuilder,
  );
}
