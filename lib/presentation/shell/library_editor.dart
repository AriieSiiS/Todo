part of 'app_shell.dart';

class _LibraryItemDialog extends StatefulWidget {
  const _LibraryItemDialog({
    required this.controller,
    this.item,
    this.initialType = LibraryItemType.game,
    this.initialStatus = LibraryItemStatus.pending,
    this.focusRating = false,
  });

  final TodoWorkspace controller;
  final LibraryItem? item;
  final LibraryItemType initialType;
  final LibraryItemStatus initialStatus;

  /// Abre la ficha con el cursor en la valoración.
  final bool focusRating;

  @override
  State<_LibraryItemDialog> createState() => _LibraryItemDialogState();
}

class _LibraryItemDialogState extends State<_LibraryItemDialog> {
  late LibraryItemType _type;
  LibraryMediaType _mediaType = LibraryMediaType.movie;
  late LibraryItemStatus _status;
  late DateTime _completedDate;
  final _title = TextEditingController();
  final _platform = TextEditingController();
  final _developer = TextEditingController();
  final _author = TextEditingController();
  final _releaseYear = TextEditingController();
  final _creator = TextEditingController();
  final _format = TextEditingController();
  final _genre = TextEditingController();
  final _duration = TextEditingController();
  final _country = TextEditingController();
  final _pages = TextEditingController();
  final _currentPage = TextEditingController();
  final _note = TextEditingController();
  final _ratingFocus = FocusNode();
  final _ratingKey = GlobalKey();
  final _rating = TextEditingController();
  final _cover = TextEditingController();
  final _externalUrl = TextEditingController();
  final _universeName = TextEditingController();
  final _collectionName = TextEditingController();
  final _collectionNumber = TextEditingController();
  final _seasonCount = TextEditingController();
  final _progressCurrent = TextEditingController();
  final _progressTotal = TextEditingController();
  final _progressSeason = TextEditingController();
  bool _showCollectionNumber = false;
  bool _nextSeasonConfirmed = false;
  LibraryPublicationStatus? _publicationStatus;
  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    if (widget.focusRating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ratingFocus.requestFocus();
        final ratingContext = _ratingKey.currentContext;
        if (ratingContext != null) {
          Scrollable.ensureVisible(ratingContext);
        }
      });
    }
    final item = widget.item;
    _type = item?.type ?? widget.initialType;
    _status = item?.status ?? widget.initialStatus;
    if (item == null) {
      _completedDate = DateTime.now();
      return;
    }
    _type = item.type;
    _mediaType = item.mediaType ?? LibraryMediaType.movie;
    _completedDate = item.completedDate ?? DateTime.now();
    _title.text = item.title;
    _platform.text = item.platform ?? '';
    _developer.text = item.developer ?? '';
    _author.text = item.author ?? '';
    _releaseYear.text = item.releaseYear?.toString() ?? '';
    _creator.text = item.creatorOrDirector ?? '';
    _format.text = item.format ?? '';
    _genre.text = item.genre ?? '';
    _duration.text = item.duration ?? '';
    _country.text = item.country ?? '';
    _pages.text = item.pages ?? '';
    _currentPage.text = item.reading?.page ?? '';
    _note.text = item.note ?? '';
    _rating.text = item.rating?.toString() ?? '';
    _cover.text = item.coverUrl ?? '';
    _externalUrl.text = item.externalUrl ?? '';
    _universeName.text = item.universeName ?? '';
    _collectionName.text = item.collectionName ?? '';
    _collectionNumber.text = item.collectionNumber?.toString() ?? '';
    _seasonCount.text = item.seasonCount?.toString() ?? '';
    _progressCurrent.text = item.progressCurrent?.toString() ?? '';
    _progressTotal.text = item.progressTotal?.toString() ?? '';
    _progressSeason.text = item.progressSeason?.toString() ?? '';
    _showCollectionNumber = item.showCollectionNumber;
    _nextSeasonConfirmed = item.nextSeasonConfirmed;
    _publicationStatus = item.publicationStatus;
  }

  @override
  void dispose() {
    _title.dispose();
    _platform.dispose();
    _developer.dispose();
    _author.dispose();
    _releaseYear.dispose();
    _creator.dispose();
    _format.dispose();
    _genre.dispose();
    _duration.dispose();
    _country.dispose();
    _pages.dispose();
    _currentPage.dispose();
    _note.dispose();
    _ratingFocus.dispose();
    _rating.dispose();
    _cover.dispose();
    _externalUrl.dispose();
    _universeName.dispose();
    _collectionName.dispose();
    _collectionNumber.dispose();
    _seasonCount.dispose();
    _progressCurrent.dispose();
    _progressTotal.dispose();
    _progressSeason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 22, 24, 18),
                child: Row(
                  children: [
                    Icon(
                      _libraryIcon(_type),
                      color: _libraryColor(_type),
                      size: 30,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing
                                ? widget.item!.title
                                : 'Añadir a la biblioteca',
                            style: const TextStyle(
                                fontSize: 23, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _isEditing
                                ? '${_libraryTypeSingularLabel(widget.item!)} · Edición'
                                : 'Guarda algo pendiente, en curso o completado.',
                            style: TextStyle(color: visuals.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isEditing) ...[
                        const Text('Tipo de contenido',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _LibraryContentTypeButton(
                                label: 'Juego',
                                icon: Icons.sports_esports_rounded,
                                active: _type == LibraryItemType.game,
                                onTap: () => setState(
                                    () => _type = LibraryItemType.game),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _LibraryContentTypeButton(
                                label: 'Libro / Manga',
                                icon: Icons.menu_book_rounded,
                                active: _type == LibraryItemType.book,
                                onTap: () => setState(
                                    () => _type = LibraryItemType.book),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _LibraryContentTypeButton(
                                label: 'Película / Serie / Anime',
                                icon: Icons.movie_creation_outlined,
                                active: _type == LibraryItemType.movieSeries,
                                onTap: () => setState(
                                    () => _type = LibraryItemType.movieSeries),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                      ],
                      Row(
                        // La ficha de la derecha puede crecer al mostrar la
                        // fecha y la valoración de un elemento completado.
                        // Mantener la carátula alineada arriba evita que salte
                        // de posición al cambiar el estado.
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LibraryImageDropField(
                            label: _imageLabel(),
                            type: _type,
                            icon: _libraryIcon(_type),
                            controller: _cover,
                            width: 244,
                            height: 416,
                          ),
                          const SizedBox(width: 30),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _dialogInfoTitle(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 14),
                                _typedFields(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 18),
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(100, 48),
                        side: const BorderSide(color: Color(0xFFE3D8CB)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancelar'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(_isEditing ? 'Guardar' : 'Añadir'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(132, 48),
                        backgroundColor: const Color(0xFF607A4D),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typedFields() {
    return switch (_type) {
      LibraryItemType.game => Column(
          children: [
            _dialogField(_title, 'Título *', 'Ej. Prey'),
            ..._collectionFields(),
            const SizedBox(height: 8),
            _dialogField(_platform, 'Plataforma *', 'Ej. PC'),
            const SizedBox(height: 8),
            _statusField(),
            if (_status == LibraryItemStatus.completed) ...[
              const SizedBox(height: 8),
              _dateField('Fecha completado *'),
            ],
            const SizedBox(height: 8),
            _dialogField(_releaseYear, 'Año de lanzamiento', 'Ej. 2017',
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            _dialogField(_genre, 'Género', 'Ej. Inmersivo, RPG...'),
            if (_status == LibraryItemStatus.completed) ...[
              const SizedBox(height: 8),
              _dialogField(
                _rating,
                'Valoración opcional',
                'Ej. 8,5',
                focusNode: _ratingFocus,
                fieldKey: _ratingKey,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
            const SizedBox(height: 8),
            _dialogField(
              _note,
              'Notas opcionales',
              'Añade contexto, una reseña o cualquier detalle…',
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 8),
            _dialogField(_developer, 'Desarrollador', 'Ej. Arkane Studios'),
            const SizedBox(height: 8),
            _dialogField(_duration, 'Horas jugadas', 'Ej. 28 h (opcional)'),
          ],
        ),
      LibraryItemType.book => Column(
          children: [
            _dialogField(_title, 'Título *', 'Ej. El Priorato del Naranjo'),
            ..._collectionFields(),
            const SizedBox(height: 8),
            _dialogField(_author, 'Autor *', 'Ej. Samantha Shannon'),
            const SizedBox(height: 8),
            _statusField(),
            if (_status == LibraryItemStatus.completed) ...[
              const SizedBox(height: 8),
              _dateField('Fecha completado *'),
            ],
            const SizedBox(height: 8),
            _dialogField(_releaseYear, 'Año de publicación', 'Ej. 2023',
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            _bookFormatField(),
            const SizedBox(height: 8),
            _dialogField(_genre, 'Género', 'Ej. Fantasía, Manga...'),
            if (_status == LibraryItemStatus.completed) ...[
              const SizedBox(height: 8),
              _dialogField(
                _rating,
                'Valoración opcional',
                'Ej. 8,5',
                focusNode: _ratingFocus,
                fieldKey: _ratingKey,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
            const SizedBox(height: 8),
            _dialogField(
              _note,
              'Notas opcionales',
              'Añade contexto, una reseña o cualquier detalle…',
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 8),
            _externalUrlField(
              'Enlace de Goodreads',
              'https://www.goodreads.com/book/show/…',
            ),
            const SizedBox(height: 8),
            _bookTypeField(),
            if (_creator.text == 'Manga') ...[
              const SizedBox(height: 8),
              _publicationStatusField(),
              const SizedBox(height: 8),
              _dialogField(
                _progressCurrent,
                'Capítulos leídos',
                'Ej. 24',
                fieldKey: const ValueKey('library-progress-current-editor'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              _dialogField(
                _progressTotal,
                'Total de capítulos',
                'Ej. 86',
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 8),
            _dialogField(_pages, 'Páginas / Volúmenes',
                'Ej. 832 páginas / 3 tomos (opcional)'),
            if (_isEditing) ...[
              const SizedBox(height: 8),
              _dialogField(
                _currentPage,
                'Página actual (progreso)',
                'Ej. 27; el porcentaje se calcula con el total',
                fieldKey: const ValueKey('library-current-page-editor'),
                keyboardType: TextInputType.number,
              ),
            ],
          ],
        ),
      LibraryItemType.movieSeries => Column(
          children: [
            _dialogField(_title, 'Título *', 'Ej. El Padrino'),
            ..._collectionFields(),
            const SizedBox(height: 8),
            _mediaTypeField(),
            if (_mediaType == LibraryMediaType.series) ...[
              const SizedBox(height: 8),
              _dialogField(
                _seasonCount,
                'Temporadas disponibles',
                'Ej. 2',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              _nextSeasonConfirmedField(),
              const SizedBox(height: 8),
              _dialogField(
                _progressSeason,
                'Temporada actual (opcional)',
                'Ej. 1',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              _dialogField(
                _progressCurrent,
                'Episodios vistos',
                'Ej. 3',
                fieldKey: const ValueKey('library-progress-current-editor'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              _dialogField(
                _progressTotal,
                'Total de episodios de la temporada',
                'Ej. 9',
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 8),
            _statusField(),
            if (_status == LibraryItemStatus.completed) ...[
              const SizedBox(height: 8),
              _dateField('Fecha completado / visto *'),
            ],
            const SizedBox(height: 8),
            _dialogField(_releaseYear, 'Año de estreno', 'Ej. 1972',
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            _dialogField(_format, 'Formato', 'Ej. Digital'),
            const SizedBox(height: 8),
            _dialogField(_genre, 'Género', 'Ej. Drama, Acción...'),
            if (_status == LibraryItemStatus.completed) ...[
              const SizedBox(height: 8),
              _dialogField(
                _rating,
                'Valoración opcional',
                'Ej. 8,5',
                focusNode: _ratingFocus,
                fieldKey: _ratingKey,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
            const SizedBox(height: 8),
            _dialogField(
              _note,
              'Notas opcionales',
              'Añade contexto, una reseña o cualquier detalle…',
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 8),
            _externalUrlField(
              'Enlace de Letterboxd',
              'https://letterboxd.com/film/…',
            ),
            const SizedBox(height: 8),
            _dialogField(_creator, 'Director / Creador',
                'Ej. Francis Ford Coppola (opcional)'),
            const SizedBox(height: 8),
            _dialogField(_duration, 'Duración', 'Ej. 2 h 55 min'),
            const SizedBox(height: 8),
            _dialogField(
                _country, 'País de origen', 'Ej. Estados Unidos (opcional)'),
          ],
        ),
    };
  }

  List<Widget> _collectionFields() {
    return [
      const SizedBox(height: 8),
      _dialogField(
        _universeName,
        'Universo',
        'Ej. Warhammer 40.000 (opcional)',
      ),
      const SizedBox(height: 8),
      _dialogField(
        _collectionName,
        'Saga / colección',
        'Ej. Carl el mazmorrero',
      ),
      const SizedBox(height: 8),
      _dialogField(
        _collectionNumber,
        'Número de entrega',
        'Ej. 2',
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 8),
      _LibraryEditLine(
        label: 'Mostrar etiquetas',
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Aunque sea la única entrega',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            Switch(
              value: _showCollectionNumber,
              onChanged: (value) =>
                  setState(() => _showCollectionNumber = value),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _externalUrlField(String label, String hint) {
    return _dialogField(
      _externalUrl,
      label,
      hint,
      keyboardType: TextInputType.url,
    );
  }

  Widget _dialogField(
      TextEditingController controller, String label, String hint,
      {TextInputType? keyboardType,
      int maxLines = 1,
      int? minLines,
      FocusNode? focusNode,
      Key? fieldKey}) {
    return _LibraryEditLine(
      label: label,
      alignTop: maxLines > 1,
      child: TextField(
        key: fieldKey,
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        minLines: minLines,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: _libraryEditInputDecoration(context, hint),
      ),
    );
  }

  Widget _statusField() {
    return _LibraryEditLine(
      label: 'Estado',
      child: DropdownButtonFormField<LibraryItemStatus>(
        initialValue: _status,
        decoration: _libraryEditInputDecoration(context, null),
        style: TextStyle(
          color: context.visuals.textStrong,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        items: [
          for (final status in LibraryItemStatus.values)
            DropdownMenuItem(
              value: status,
              child: Row(
                children: [
                  Icon(_libraryStatusIcon(status), size: 18),
                  const SizedBox(width: 10),
                  Text(_libraryStatusSingularLabel(status)),
                ],
              ),
            ),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() => _status = value);
          }
        },
      ),
    );
  }

  Widget _dateField(String label) {
    return _LibraryEditLine(
      label: label,
      child: InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 18),
              const SizedBox(width: 10),
              Text(
                _libraryDate(_completedDate),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mediaTypeField() {
    return _LibraryEditLine(
      label: 'Tipo *',
      child: DropdownButtonFormField<LibraryMediaType>(
        initialValue: _mediaType,
        decoration: _libraryEditInputDecoration(context, null),
        style: TextStyle(
          color: context.visuals.textStrong,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        items: const [
          DropdownMenuItem(
              value: LibraryMediaType.movie, child: Text('Película')),
          DropdownMenuItem(
              value: LibraryMediaType.series, child: Text('Serie')),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() => _mediaType = value);
          }
        },
      ),
    );
  }

  Widget _bookTypeField() {
    return _dropdownTextField(
      label: 'Tipo *',
      controller: _creator,
      fallback: 'Libro',
      options: const ['Libro', 'Manga', 'Cómic'],
    );
  }

  Widget _bookFormatField() {
    return _dropdownTextField(
      label: 'Formato *',
      controller: _format,
      fallback: 'eBook',
      options: const ['Físico', 'eBook'],
    );
  }

  Widget _publicationStatusField() {
    return _LibraryEditLine(
      label: 'Publicación',
      child: DropdownButtonFormField<LibraryPublicationStatus>(
        initialValue: _publicationStatus,
        decoration: _libraryEditInputDecoration(context, 'Selecciona estado'),
        style: TextStyle(
          color: context.visuals.textStrong,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        items: const [
          DropdownMenuItem(
            value: LibraryPublicationStatus.ongoing,
            child: Text('En publicación'),
          ),
          DropdownMenuItem(
            value: LibraryPublicationStatus.finished,
            child: Text('Finalizado'),
          ),
        ],
        onChanged: (value) => setState(() => _publicationStatus = value),
      ),
    );
  }

  Widget _nextSeasonConfirmedField() {
    return _LibraryEditLine(
      label: 'Próxima temporada',
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Temporada confirmada',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Switch(
            value: _nextSeasonConfirmed,
            onChanged: (value) => setState(() => _nextSeasonConfirmed = value),
          ),
        ],
      ),
    );
  }

  Widget _dropdownTextField({
    required String label,
    required TextEditingController controller,
    required String fallback,
    required List<String> options,
  }) {
    final current =
        options.contains(controller.text) ? controller.text : fallback;
    controller.text = current;
    return _LibraryEditLine(
      label: label,
      child: DropdownButtonFormField<String>(
        initialValue: current,
        decoration: _libraryEditInputDecoration(context, null),
        style: TextStyle(
          color: context.visuals.textStrong,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        items: [
          for (final option in options)
            DropdownMenuItem(value: option, child: Text(option)),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() => controller.text = value);
          }
        },
      ),
    );
  }

  String _dialogInfoTitle() => switch (_type) {
        LibraryItemType.game => 'Información del juego',
        LibraryItemType.book => 'Información del libro / manga',
        LibraryItemType.movieSeries =>
          'Información de la película / serie / anime',
      };

  String _imageLabel() => switch (_type) {
        LibraryItemType.game => 'Carátula',
        LibraryItemType.book => 'Portada',
        LibraryItemType.movieSeries => 'Póster',
      };

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      locale: const Locale('es', 'ES'),
      initialDate: _completedDate,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) {
      setState(() => _completedDate = selected);
    }
  }

  void _save() {
    if (_title.text.trim().isEmpty) {
      return;
    }
    final item = widget.item;
    if (item != null) {
      final pageText = _currentPage.text.trim();
      final pageChanged = _type == LibraryItemType.book &&
          (pageText != (item.reading?.page ?? '') ||
              _pages.text.trim() != (item.pages ?? ''));
      if (pageChanged && pageText.isNotEmpty) {
        final total = bookPageTotal(_pages.text.trim(), item.reading);
        final page = int.tryParse(pageText);
        if (total == null || page == null || page < 0 || page > total) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Indica una página válida y el total de páginas.')));
          return;
        }
      }
      widget.controller.updateLibraryItem(
        item.copyWith(
          title: _title.text.trim(),
          status: _status,
          completedDate:
              _status == LibraryItemStatus.completed ? _completedDate : null,
          clearCompletedDate: _status != LibraryItemStatus.completed,
          coverUrl: _cover.text.trim().isEmpty ? null : _cover.text.trim(),
          clearCoverUrl: _cover.text.trim().isEmpty,
          externalUrl: _validExternalUrl,
          clearExternalUrl: _validExternalUrl == null,
          rating: double.tryParse(_rating.text.replaceAll(',', '.')),
          clearRating: _rating.text.trim().isEmpty,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          clearNote: _note.text.trim().isEmpty,
          platform:
              _type == LibraryItemType.game ? _platform.text.trim() : null,
          clearPlatform:
              _type != LibraryItemType.game || _platform.text.trim().isEmpty,
          developer:
              _type == LibraryItemType.game ? _developer.text.trim() : null,
          clearDeveloper:
              _type != LibraryItemType.game || _developer.text.trim().isEmpty,
          author: _type == LibraryItemType.book ? _author.text.trim() : null,
          clearAuthor:
              _type != LibraryItemType.book || _author.text.trim().isEmpty,
          mediaType: _type == LibraryItemType.movieSeries ? _mediaType : null,
          clearMediaType: _type != LibraryItemType.movieSeries,
          releaseYear: int.tryParse(_releaseYear.text),
          clearReleaseYear: _releaseYear.text.trim().isEmpty,
          creatorOrDirector: _type == LibraryItemType.movieSeries ||
                  _type == LibraryItemType.book
              ? _creator.text.trim()
              : null,
          clearCreatorOrDirector: (_type != LibraryItemType.movieSeries &&
                  _type != LibraryItemType.book) ||
              _creator.text.trim().isEmpty,
          genre: _genre.text.trim().isEmpty ? null : _genre.text.trim(),
          clearGenre: _genre.text.trim().isEmpty,
          format: _type == LibraryItemType.game
              ? 'Digital'
              : _format.text.trim().isEmpty
                  ? null
                  : _format.text.trim(),
          clearFormat:
              _type != LibraryItemType.game && _format.text.trim().isEmpty,
          duration:
              _duration.text.trim().isEmpty ? null : _duration.text.trim(),
          clearDuration: _duration.text.trim().isEmpty,
          pages: _type == LibraryItemType.book ? _pages.text.trim() : null,
          clearPages:
              _type != LibraryItemType.book || _pages.text.trim().isEmpty,
          country: _type == LibraryItemType.movieSeries
              ? _country.text.trim()
              : null,
          clearCountry: _type != LibraryItemType.movieSeries ||
              _country.text.trim().isEmpty,
          universeName: _universeName.text.trim().isEmpty
              ? null
              : _universeName.text.trim(),
          clearUniverseName: _universeName.text.trim().isEmpty,
          collectionName: _collectionName.text.trim().isEmpty
              ? null
              : _collectionName.text.trim(),
          clearCollectionName: _collectionName.text.trim().isEmpty,
          collectionNumber: _validCollectionNumber,
          clearCollectionNumber: _validCollectionNumber == null,
          showCollectionNumber: _validCollectionNumber != null &&
              _collectionName.text.trim().isNotEmpty &&
              _showCollectionNumber,
          seasonCount: _type == LibraryItemType.movieSeries &&
                  _mediaType == LibraryMediaType.series
              ? _validSeasonCount
              : null,
          clearSeasonCount: _type != LibraryItemType.movieSeries ||
              _mediaType != LibraryMediaType.series ||
              _validSeasonCount == null,
          nextSeasonConfirmed: _type == LibraryItemType.movieSeries &&
              _mediaType == LibraryMediaType.series &&
              _nextSeasonConfirmed,
          progressCurrent: _admiteProgreso ? _validProgressCurrent : null,
          clearProgressCurrent:
              !_admiteProgreso || _validProgressCurrent == null,
          progressTotal: _admiteProgreso ? _validProgressTotal : null,
          clearProgressTotal: !_admiteProgreso || _validProgressTotal == null,
          progressSeason:
              _admiteProgresoTemporada ? _validProgressSeason : null,
          clearProgressSeason:
              !_admiteProgresoTemporada || _validProgressSeason == null,
          publicationStatus:
              _type == LibraryItemType.book && _creator.text == 'Manga'
                  ? _publicationStatus
                  : null,
          clearPublicationStatus:
              _type != LibraryItemType.book || _creator.text != 'Manga',
        ),
      );
      if (pageChanged && pageText.isNotEmpty) {
        widget.controller.updateBookReadingPage(item.id, int.parse(pageText));
      }
      _closeAfterSave(item.id,
          newlyCompleted: item.status != LibraryItemStatus.completed);
      return;
    }
    final created = widget.controller.createLibraryItem(
      type: _type,
      title: _title.text,
      status: _status,
      completedDate:
          _status == LibraryItemStatus.completed ? _completedDate : null,
      coverUrl: _cover.text,
      externalUrl: _validExternalUrl,
      rating: double.tryParse(_rating.text.replaceAll(',', '.')),
      note: _note.text,
      platform: _type == LibraryItemType.game ? _platform.text : null,
      developer: _type == LibraryItemType.game ? _developer.text : null,
      author: _type == LibraryItemType.book ? _author.text : null,
      mediaType: _type == LibraryItemType.movieSeries ? _mediaType : null,
      releaseYear: int.tryParse(_releaseYear.text),
      creatorOrDirector:
          _type == LibraryItemType.movieSeries || _type == LibraryItemType.book
              ? _creator.text
              : null,
      genre: _genre.text,
      format: _type == LibraryItemType.game ? 'Digital' : _format.text,
      duration: _duration.text,
      pages: _type == LibraryItemType.book ? _pages.text : null,
      country: _type == LibraryItemType.movieSeries ? _country.text : null,
      universeName: _universeName.text,
      collectionName: _collectionName.text,
      collectionNumber: _validCollectionNumber,
      showCollectionNumber: _validCollectionNumber != null &&
          _collectionName.text.trim().isNotEmpty &&
          _showCollectionNumber,
      seasonCount: _type == LibraryItemType.movieSeries &&
              _mediaType == LibraryMediaType.series
          ? _validSeasonCount
          : null,
      nextSeasonConfirmed: _type == LibraryItemType.movieSeries &&
          _mediaType == LibraryMediaType.series &&
          _nextSeasonConfirmed,
      progressCurrent: _admiteProgreso ? _validProgressCurrent : null,
      progressTotal: _admiteProgreso ? _validProgressTotal : null,
      progressSeason: _admiteProgresoTemporada ? _validProgressSeason : null,
      publicationStatus:
          _type == LibraryItemType.book && _creator.text == 'Manga'
              ? _publicationStatus
              : null,
    );
    _closeAfterSave(created.id, newlyCompleted: true);
  }

  void _closeAfterSave(String itemId, {required bool newlyCompleted}) {
    final navigator = Navigator.of(context);
    final parentContext = navigator.context;
    navigator.pop();
    if (newlyCompleted) {
      unawaited(
          _promptCompletedBookRating(parentContext, widget.controller, itemId));
    }
  }

  /// Solo se guarda un enlace web válido; los juegos no tienen ficha externa.
  String? get _validExternalUrl {
    if (_type == LibraryItemType.game) {
      return null;
    }
    return normalizarEnlaceExterno(_externalUrl.text);
  }

  int? get _validCollectionNumber {
    final value = int.tryParse(_collectionNumber.text.trim());
    return value != null && value > 0 ? value : null;
  }

  bool get _admiteProgreso =>
      (_type == LibraryItemType.movieSeries &&
          _mediaType == LibraryMediaType.series) ||
      (_type == LibraryItemType.book && _creator.text == 'Manga');

  bool get _admiteProgresoTemporada =>
      _type == LibraryItemType.movieSeries &&
      _mediaType == LibraryMediaType.series;

  int? get _validProgressCurrent {
    final value = int.tryParse(_progressCurrent.text.trim());
    return value != null && value >= 0 ? value : null;
  }

  int? get _validProgressTotal {
    final value = int.tryParse(_progressTotal.text.trim());
    return value != null && value > 0 ? value : null;
  }

  int? get _validProgressSeason {
    final value = int.tryParse(_progressSeason.text.trim());
    return value != null && value > 0 ? value : null;
  }

  int? get _validSeasonCount {
    final value = int.tryParse(_seasonCount.text.trim());
    return value != null && value > 0 ? value : null;
  }
}

class _BookRatingDialog extends StatefulWidget {
  const _BookRatingDialog({required this.title});

  final String title;

  @override
  State<_BookRatingDialog> createState() => _BookRatingDialogState();
}

class _BookRatingDialogState extends State<_BookRatingDialog> {
  final _rating = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _rating.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_rating.text.trim().replaceAll(',', '.'));
    if (value == null || !value.isFinite || value < 0 || value > 10) {
      setState(() => _error = 'Introduce una nota entre 0 y 10.');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(Icons.star_outline_rounded,
          color: Theme.of(context).colorScheme.primary),
      title: const Text('Valorar libro'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            TextField(
              controller: _rating,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Tu valoración',
                hintText: 'Ej. 8,5',
                suffixText: '/ 10',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Ahora no'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Guardar valoración'),
        ),
      ],
    );
  }
}

class _LibraryEditLine extends StatelessWidget {
  const _LibraryEditLine({
    required this.label,
    required this.child,
    this.alignTop = false,
  });

  final String label;
  final Widget child;
  final bool alignTop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: alignTop ? 10 : 2,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        border: Border.all(color: const Color(0xFFE3D8CB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment:
            alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: alignTop ? 12 : 0),
            child: Icon(
              _detailIcon(label),
              size: 17,
              color: const Color(0xFF607A4D),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: alignTop ? 11 : 0),
              child: Text(
                label,
                style: TextStyle(
                  color: context.visuals.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(flex: 2, child: child),
        ],
      ),
    );
  }
}

InputDecoration _libraryEditInputDecoration(
  BuildContext context,
  String? hint,
) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: context.visuals.textMuted.withValues(alpha: 0.72),
      fontSize: 14,
      fontWeight: FontWeight.w400,
    ),
    isDense: true,
    filled: false,
    contentPadding: const EdgeInsets.symmetric(vertical: 12),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
  );
}

class _LibraryContentTypeButton extends StatelessWidget {
  const _LibraryContentTypeButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? const Color(0xFF607A4D) : const Color(0xFFE3D8CB),
            width: active ? 1.4 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFF607A4D).withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                color: active
                    ? const Color(0xFF607A4D)
                    : context.visuals.textStrong),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active
                      ? const Color(0xFF607A4D)
                      : context.visuals.textStrong,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryImageDropField extends StatefulWidget {
  const _LibraryImageDropField({
    required this.label,
    required this.type,
    required this.icon,
    required this.controller,
    this.width = 176,
    this.height = 300,
  });

  final String label;
  final LibraryItemType type;
  final IconData icon;
  final TextEditingController controller;
  final double width;
  final double height;

  @override
  State<_LibraryImageDropField> createState() => _LibraryImageDropFieldState();
}

class _LibraryImageDropFieldState extends State<_LibraryImageDropField> {
  final FocusNode _pasteFocus = FocusNode(
    debugLabel: 'Pegar portada de biblioteca',
  );

  @override
  void dispose() {
    _pasteFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Column(
        children: [
          CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.keyV, control: true):
                  () => _pasteCover(context),
            },
            child: Focus(
              focusNode: _pasteFocus,
              child: InkWell(
                onTap: () {
                  _pasteFocus.requestFocus();
                  _pickCoverFile(context);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFCF8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE3D8CB)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x260F1B0C),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.controller,
                    builder: (context, value, _) {
                      final source = value.text.trim();
                      if (source.isNotEmpty) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _LibraryCoverImage(
                            source: source,
                            type: widget.type,
                            iconSize: 34,
                          ),
                        );
                      }
                      return _LibraryImagePlaceholder(
                        icon: widget.icon,
                        label: widget.label,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _pasteCover(context),
              icon: const Icon(Icons.content_paste_rounded),
              label: const Text('Pegar imagen'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCoverFile(BuildContext context) async {
    const typeGroup = XTypeGroup(
      label: 'Imágenes',
      extensions: <String>['jpg', 'jpeg', 'png', 'webp'],
      mimeTypes: <String>['image/jpeg', 'image/png', 'image/webp'],
    );
    try {
      final file = await openFile(acceptedTypeGroups: const [typeGroup]);
      if (file == null) {
        return;
      }
      final savedPath = await _copyLibraryCover(file);
      if (!context.mounted) {
        return;
      }
      if (savedPath == null) {
        _showCoverError(context, 'No se pudo guardar la imagen seleccionada.');
        return;
      }
      widget.controller.text = savedPath;
    } catch (error) {
      if (context.mounted) {
        _showCoverError(context, 'No se pudo cambiar la portada: $error');
      }
    }
  }

  Future<void> _pasteCover(BuildContext context) async {
    final result = await readClipboardImage();
    if (!context.mounted) return;
    if (!result.hasImage) {
      _showCoverError(context, result.errorMessage!);
      return;
    }
    try {
      final savedPath = await _copyLibraryCoverBytes(result.bytes!);
      if (!context.mounted) return;
      if (savedPath == null) {
        _showCoverError(context, 'La imagen copiada no es compatible.');
        return;
      }
      widget.controller.text = savedPath;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Imagen pegada.')),
      );
    } catch (error) {
      if (context.mounted) {
        _showCoverError(context, 'No se pudo pegar la portada: $error');
      }
    }
  }

  void _showCoverError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _LibraryImagePlaceholder extends StatelessWidget {
  const _LibraryImagePlaceholder({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 34, color: context.visuals.textStrong),
        const SizedBox(height: 18),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'Haz clic para seleccionar una imagen',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.visuals.textMuted, height: 1.35),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'JPG, PNG · Máx. 5MB',
          style: TextStyle(color: context.visuals.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

IconData _libraryIcon(LibraryItemType type) => switch (type) {
      LibraryItemType.game => Icons.sports_esports_rounded,
      LibraryItemType.book => Icons.menu_book_rounded,
      LibraryItemType.movieSeries => Icons.movie_creation_outlined,
    };

Color _libraryColor(LibraryItemType type) => switch (type) {
      LibraryItemType.game => const Color(0xFF70835D),
      LibraryItemType.book => const Color(0xFF8F74D3),
      LibraryItemType.movieSeries => const Color(0xFFF1A340),
    };

String _libraryTypePluralLabel(LibraryItemType type) => switch (type) {
      LibraryItemType.game => 'Juegos',
      LibraryItemType.book => 'Libros',
      LibraryItemType.movieSeries => 'Pelis y series',
    };

String _libraryTypeSingularLabelForType(LibraryItemType type) => switch (type) {
      LibraryItemType.game => 'Juego',
      LibraryItemType.book => 'Libro',
      LibraryItemType.movieSeries => 'Película o serie',
    };

String _libraryTypeSingularLabel(LibraryItem item) => switch (item.type) {
      LibraryItemType.game => 'Juego',
      LibraryItemType.book => 'Libro',
      LibraryItemType.movieSeries =>
        item.mediaType == LibraryMediaType.series ? 'Serie' : 'Película',
    };

String _librarySeeAllLabel(
  LibraryItemType type,
  int count,
  LibraryItemStatus? status,
) {
  final state = _libraryStatusCountLabel(status, count);
  return switch (type) {
    LibraryItemType.game => 'Ver los $count juegos $state',
    LibraryItemType.book => 'Ver los $count libros $state',
    LibraryItemType.movieSeries => 'Ver las $count películas y series $state',
  };
}

String _libraryStatusPluralLabel(LibraryItemStatus? status) => switch (status) {
      LibraryItemStatus.pending => 'Pendientes',
      LibraryItemStatus.inProgress => 'En curso',
      LibraryItemStatus.completed => 'Completados',
      null => 'Todo',
    };

String _libraryStatusSingularLabel(LibraryItemStatus? status) =>
    switch (status) {
      LibraryItemStatus.pending => 'Pendiente',
      LibraryItemStatus.inProgress => 'En curso',
      LibraryItemStatus.completed => 'Completado',
      null => 'Contenido',
    };

String _libraryStatusCountLabel(LibraryItemStatus? status, int count) =>
    switch (status) {
      LibraryItemStatus.pending => count == 1 ? 'pendiente' : 'pendientes',
      LibraryItemStatus.inProgress => 'en curso',
      LibraryItemStatus.completed => count == 1 ? 'completado' : 'completados',
      null => count == 1 ? 'elemento' : 'elementos',
    };

String _libraryEmptyStatusText(LibraryItemStatus? status) => switch (status) {
      LibraryItemStatus.pending =>
        'No hay contenido pendiente para este filtro.',
      LibraryItemStatus.inProgress =>
        'No hay contenido en curso para este filtro.',
      LibraryItemStatus.completed =>
        'No hay contenido completado para este filtro.',
      null => 'No hay contenido en la biblioteca.',
    };

IconData _libraryStatusIcon(LibraryItemStatus status) => switch (status) {
      LibraryItemStatus.pending => Icons.bookmark_border_rounded,
      LibraryItemStatus.inProgress => Icons.play_circle_outline_rounded,
      LibraryItemStatus.completed => Icons.check_circle_outline_rounded,
    };

String _libraryItemStatusMeta(LibraryItem item) {
  final date = item.completedDate;
  if (item.status == LibraryItemStatus.completed && date != null) {
    return _libraryDate(date);
  }
  return _libraryStatusSingularLabel(item.status);
}

({String saga, String? installment, String? universe})?
    _libraryCollectionLabels(
  TodoWorkspace controller,
  LibraryItem item,
) {
  final collectionName = item.collectionName?.trim();
  final collectionNumber = item.collectionNumber;
  final universe = item.universeName?.trim();
  if (collectionName == null || collectionName.isEmpty) {
    return null;
  }
  final collectionKey = _libraryCollectionKey(collectionName);
  final distinctNumbers = controller.libraryItems
      .where(
        (candidate) =>
            candidate.type == item.type &&
            _libraryCollectionKey(candidate.collectionName) == collectionKey,
      )
      .map((candidate) => candidate.collectionNumber)
      .whereType<int>()
      .toSet();
  final showInstallment = collectionNumber != null &&
      (distinctNumbers.length >= 2 || item.showCollectionNumber);
  return (
    saga: collectionName.toLowerCase().startsWith('saga ')
        ? collectionName.substring(5).trim()
        : collectionName,
    installment: showInstallment ? '#$collectionNumber' : null,
    universe: universe == null || universe.isEmpty ? null : universe,
  );
}

({String seasons, String? upcoming})? _librarySeriesLabels(
  LibraryItem item,
) {
  if (item.type != LibraryItemType.movieSeries ||
      item.mediaType != LibraryMediaType.series ||
      item.seasonCount == null) {
    return null;
  }
  final count = item.seasonCount!;
  return (
    seasons: 'T$count',
    upcoming: item.nextSeasonConfirmed ? 'T${count + 1} ✓' : null,
  );
}

String _libraryCollectionKey(String? value) =>
    (value ?? '').trim().toLowerCase();

String _libraryDeleteMessage(TodoWorkspace controller, LibraryItem item) {
  final linked = controller.libraryGoals.any(
    (goal) =>
        goal.id == item.linkedGoalId || goal.linkedLibraryItemId == item.id,
  );
  if (linked) {
    return '¿Quieres borrar "${item.title}" de la biblioteca? El propósito vinculado se conservará y volverá a crear esta obra como pendiente.';
  }
  return '¿Quieres borrar "${item.title}" de la biblioteca?';
}

String _addGoalLabel(LibraryItemType type) => switch (type) {
      LibraryItemType.game => 'Añadir juego',
      LibraryItemType.book => 'Añadir libro',
      LibraryItemType.movieSeries => 'Añadir película o serie',
    };

String _emptyGoalText(LibraryItemType type) => switch (type) {
      LibraryItemType.game => 'No hay juegos en tus propósitos de este año.',
      LibraryItemType.book => 'No hay libros en tus propósitos de este año.',
      LibraryItemType.movieSeries =>
        'No hay películas ni series en tus propósitos de este año.',
    };

String? _goalMetadata(LibraryGoal goal) {
  final parts = <String>[];
  switch (goal.type) {
    case LibraryItemType.game:
      if (goal.platform?.trim().isNotEmpty ?? false) {
        parts.add(goal.platform!.trim());
      }
      if (goal.developer?.trim().isNotEmpty ?? false) {
        parts.add(goal.developer!.trim());
      }
      break;
    case LibraryItemType.book:
      if (goal.author?.trim().isNotEmpty ?? false) {
        parts.add(goal.author!.trim());
      }
      if (goal.pages?.trim().isNotEmpty ?? false) {
        parts.add(goal.pages!.trim());
      }
      break;
    case LibraryItemType.movieSeries:
      if (goal.mediaType != null) {
        parts.add(
            goal.mediaType == LibraryMediaType.series ? 'Serie' : 'Película');
      }
      if (goal.creatorOrDirector?.trim().isNotEmpty ?? false) {
        parts.add(goal.creatorOrDirector!.trim());
      }
      if (goal.duration?.trim().isNotEmpty ?? false) {
        parts.add(goal.duration!.trim());
      }
      break;
  }
  if (goal.releaseYear != null) {
    parts.add('${goal.releaseYear}');
  }
  if (goal.genre?.trim().isNotEmpty ?? false) {
    parts.add(goal.genre!.trim());
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

String _libraryDate(DateTime date) =>
    '${date.day} ${_monthShortLibrary(date.month)} ${date.year}';

String _formatRating(double rating) {
  final rounded = rating.roundToDouble();
  if ((rating - rounded).abs() < 0.05) {
    return rounded.toInt().toString();
  }
  return rating.toStringAsFixed(1);
}

int _libraryRewatchCount(LibraryItem item) {
  final note = item.note ?? '';
  final match =
      RegExp(r'\[rewatch:x(\d+)\]', caseSensitive: false).firstMatch(note);
  final legacyCount =
      match == null ? 1 : int.tryParse(match.group(1) ?? '') ?? 1;
  return item.rewatchCount > legacyCount ? item.rewatchCount : legacyCount;
}

String _detailTitle(LibraryItemType _) => 'Información';

String _goalDetailTitle(LibraryItemType type) => _detailTitle(type);

String _bookProgressLabel(LibraryItem item) {
  final total = bookPageTotal(item.pages, item.reading);
  if (total == null) return 'Indica el total de páginas en Editar';
  final page = item.reading?.page.isNotEmpty == true ? item.reading!.page : '0';
  return 'Página $page de $total · ${bookReadingPercent(item.reading, total)} %';
}

List<(String, String)> _detailFields(LibraryItem item) {
  final common = <(String, String)>[
    ('Estado', _libraryStatusSingularLabel(item.status)),
    if (item.universeName?.isNotEmpty == true)
      ('Universo', item.universeName!),
    if (item.collectionName?.isNotEmpty == true)
      ('Saga / colección', item.collectionName!),
    if (item.collectionNumber != null)
      ('Número de entrega', '#${item.collectionNumber}'),
    if (item.rewatchCount > 1) ('Rewatch', 'x${item.rewatchCount}'),
    if (textoProgresoManual(item) != null)
      ('Progreso', textoProgresoManual(item)!),
    if (item.completedDate != null)
      ('Fecha completado', _libraryDate(item.completedDate!)),
    if (item.releaseYear != null) ('Año', item.releaseYear.toString()),
    if (item.type != LibraryItemType.game && item.format?.isNotEmpty == true)
      ('Formato', item.format!),
    if (item.genre?.isNotEmpty == true) ('Género', item.genre!),
    if (item.note?.isNotEmpty == true) ('Notas', item.note!),
  ];
  return switch (item.type) {
    LibraryItemType.game => [
        if (item.platform?.isNotEmpty == true) ('Plataforma', item.platform!),
        ...common,
        if (item.developer?.isNotEmpty == true)
          ('Desarrollador', item.developer!),
        if (item.duration?.isNotEmpty == true)
          ('Horas jugadas', item.duration!),
        if (item.rating != null) ('Valoración', item.rating!.toString()),
      ],
    LibraryItemType.book => [
        if (item.author?.isNotEmpty == true) ('Autor', item.author!),
        ...common,
        ('Progreso', _bookProgressLabel(item)),
        if (item.creatorOrDirector?.isNotEmpty == true)
          ('Tipo', item.creatorOrDirector!),
        if (item.creatorOrDirector == 'Manga' && item.publicationStatus != null)
          (
            'Publicación',
            item.publicationStatus == LibraryPublicationStatus.ongoing
                ? 'En publicación'
                : 'Finalizado'
          ),
        if (item.pages?.isNotEmpty == true)
          ('Páginas / volúmenes', item.pages!),
        if (item.rating != null) ('Valoración', item.rating!.toString()),
      ],
    LibraryItemType.movieSeries => [
        (
          'Tipo',
          item.mediaType == LibraryMediaType.series ? 'Serie' : 'Película'
        ),
        ...common,
        if (item.mediaType == LibraryMediaType.series &&
            item.seasonCount != null)
          ('Temporadas disponibles', item.seasonCount.toString()),
        if (item.mediaType == LibraryMediaType.series &&
            item.nextSeasonConfirmed)
          ('Próxima temporada', 'Confirmada'),
        if (item.creatorOrDirector?.isNotEmpty == true)
          ('Director / creador', item.creatorOrDirector!),
        if (item.duration?.isNotEmpty == true) ('Duración', item.duration!),
        if (item.country?.isNotEmpty == true) ('País de origen', item.country!),
        if (item.rating != null) ('Valoración', item.rating!.toString()),
      ],
  };
}

List<(String, String)> _goalDetailFields(LibraryGoal goal) {
  final common = <(String, String)>[
    ('Estado', goal.isCompleted ? 'Completado' : 'Pendiente'),
    ('Año objetivo', goal.targetYear.toString()),
    if (goal.releaseYear != null) ('Año', goal.releaseYear.toString()),
    if (goal.type != LibraryItemType.game && goal.format?.isNotEmpty == true)
      ('Formato', goal.format!),
    if (goal.genre?.isNotEmpty == true) ('Género', goal.genre!),
    if (goal.note?.isNotEmpty == true) ('Notas', goal.note!),
  ];
  return switch (goal.type) {
    LibraryItemType.game => [
        if (goal.platform?.isNotEmpty == true) ('Plataforma', goal.platform!),
        ...common,
        if (goal.developer?.isNotEmpty == true)
          ('Desarrollador', goal.developer!),
        if (goal.duration?.isNotEmpty == true)
          ('Horas previstas', goal.duration!),
      ],
    LibraryItemType.book => [
        if (goal.author?.isNotEmpty == true) ('Autor', goal.author!),
        ...common,
        if (goal.creatorOrDirector?.isNotEmpty == true)
          ('Tipo', goal.creatorOrDirector!),
        if (goal.pages?.isNotEmpty == true)
          ('Páginas / volúmenes', goal.pages!),
      ],
    LibraryItemType.movieSeries => [
        (
          'Tipo',
          goal.mediaType == LibraryMediaType.series ? 'Serie' : 'Película'
        ),
        ...common,
        if (goal.creatorOrDirector?.isNotEmpty == true)
          ('Director / creador', goal.creatorOrDirector!),
        if (goal.duration?.isNotEmpty == true) ('Duración', goal.duration!),
        if (goal.country?.isNotEmpty == true) ('País de origen', goal.country!),
      ],
  };
}

String _monthShortLibrary(int month) => const [
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

String _sortLabel(LibrarySortOrder order) => switch (order) {
      LibrarySortOrder.newestFirst => 'Recientes',
      LibrarySortOrder.oldestFirst => 'Más antiguo',
      LibrarySortOrder.titleAsc => 'A-Z',
      LibrarySortOrder.titleDesc => 'Z-A',
      LibrarySortOrder.highestRating => 'Valoración',
      LibrarySortOrder.releaseYearDesc => 'Año de salida',
      LibrarySortOrder.releaseYearAsc => 'Año de salida antiguo',
      LibrarySortOrder.creatorAsc => 'Creador / autor',
      LibrarySortOrder.genreAsc => 'Género',
      LibrarySortOrder.platformAsc => 'Plataforma',
      LibrarySortOrder.formatAsc => 'Formato',
      LibrarySortOrder.pagesDesc => 'Más páginas',
      LibrarySortOrder.pagesAsc => 'Menos páginas',
      LibrarySortOrder.durationDesc => 'Más duración',
      LibrarySortOrder.durationAsc => 'Menos duración',
      LibrarySortOrder.countryAsc => 'País',
      LibrarySortOrder.achievementsDesc => '% de logros',
    };

String _sortLabelForType(LibrarySortOrder order, LibraryItemType type) {
  if (order == LibrarySortOrder.releaseYearDesc) {
    return switch (type) {
      LibraryItemType.game => 'Año de salida',
      LibraryItemType.book => 'Año de publicación',
      LibraryItemType.movieSeries => 'Año de estreno',
    };
  }
  if (order == LibrarySortOrder.releaseYearAsc) {
    return switch (type) {
      LibraryItemType.game => 'Salida más antigua',
      LibraryItemType.book => 'Publicación más antigua',
      LibraryItemType.movieSeries => 'Estreno más antiguo',
    };
  }
  if (order == LibrarySortOrder.creatorAsc) {
    return switch (type) {
      LibraryItemType.game => 'Desarrollador',
      LibraryItemType.book => 'Autor',
      LibraryItemType.movieSeries => 'Director / creador',
    };
  }
  return _sortLabel(order);
}

List<LibrarySortOrder> _sortOptionsForType(LibraryItemType type) {
  final common = <LibrarySortOrder>[
    LibrarySortOrder.newestFirst,
    LibrarySortOrder.oldestFirst,
    LibrarySortOrder.titleAsc,
    LibrarySortOrder.titleDesc,
    LibrarySortOrder.highestRating,
    LibrarySortOrder.releaseYearDesc,
    LibrarySortOrder.releaseYearAsc,
    LibrarySortOrder.creatorAsc,
    LibrarySortOrder.genreAsc,
  ];
  return switch (type) {
    LibraryItemType.game => [
        ...common,
        LibrarySortOrder.platformAsc,
        LibrarySortOrder.formatAsc,
        LibrarySortOrder.durationDesc,
        LibrarySortOrder.durationAsc,
        LibrarySortOrder.achievementsDesc,
      ],
    LibraryItemType.book => [
        ...common,
        LibrarySortOrder.formatAsc,
        LibrarySortOrder.pagesDesc,
        LibrarySortOrder.pagesAsc,
      ],
    LibraryItemType.movieSeries => [
        ...common,
        LibrarySortOrder.durationDesc,
        LibrarySortOrder.durationAsc,
        LibrarySortOrder.countryAsc,
      ],
  };
}

// El orden elegido se comparte entre vistas; si la vista actual no lo ofrece
// (por ejemplo, Plataforma fuera de Juegos), se usa el orden por defecto.
LibrarySortOrder _effectiveSortOrderForType(
  LibrarySortOrder order,
  LibraryItemType type,
) =>
    _sortOptionsForType(type).contains(order)
        ? order
        : LibrarySortOrder.newestFirst;

LibrarySortOrder _effectiveSortOrderForAll(LibrarySortOrder order) =>
    _sortOptionsForAll().contains(order) ? order : LibrarySortOrder.newestFirst;

List<LibrarySortOrder> _sortOptionsForAll() => const [
      LibrarySortOrder.newestFirst,
      LibrarySortOrder.oldestFirst,
      LibrarySortOrder.titleAsc,
      LibrarySortOrder.titleDesc,
      LibrarySortOrder.highestRating,
      LibrarySortOrder.releaseYearDesc,
      LibrarySortOrder.releaseYearAsc,
      LibrarySortOrder.creatorAsc,
      LibrarySortOrder.genreAsc,
    ];

int _compareLibraryItems(
  LibraryItem left,
  LibraryItem right,
  LibrarySortOrder order,
) {
  final result = switch (order) {
    LibrarySortOrder.newestFirst => (right.completedDate ?? right.updatedAt)
        .compareTo(left.completedDate ?? left.updatedAt),
    LibrarySortOrder.oldestFirst => (left.completedDate ?? left.updatedAt)
        .compareTo(right.completedDate ?? right.updatedAt),
    LibrarySortOrder.titleAsc =>
      _sortText(left.title).compareTo(_sortText(right.title)),
    LibrarySortOrder.titleDesc =>
      _sortText(right.title).compareTo(_sortText(left.title)),
    LibrarySortOrder.highestRating =>
      (right.rating ?? -1).compareTo(left.rating ?? -1),
    LibrarySortOrder.releaseYearDesc =>
      (right.releaseYear ?? 0).compareTo(left.releaseYear ?? 0),
    LibrarySortOrder.releaseYearAsc =>
      (left.releaseYear ?? 9999).compareTo(right.releaseYear ?? 9999),
    LibrarySortOrder.creatorAsc =>
      _libraryCreator(left).compareTo(_libraryCreator(right)),
    LibrarySortOrder.genreAsc =>
      _sortText(left.genre).compareTo(_sortText(right.genre)),
    LibrarySortOrder.platformAsc =>
      _sortText(left.platform).compareTo(_sortText(right.platform)),
    LibrarySortOrder.formatAsc =>
      _sortText(left.format).compareTo(_sortText(right.format)),
    LibrarySortOrder.pagesDesc => _extractFirstNumber(right.pages)
        .compareTo(_extractFirstNumber(left.pages)),
    LibrarySortOrder.pagesAsc => _extractFirstNumber(left.pages)
        .compareTo(_extractFirstNumber(right.pages)),
    LibrarySortOrder.durationDesc => _extractFirstNumber(right.duration)
        .compareTo(_extractFirstNumber(left.duration)),
    LibrarySortOrder.durationAsc => _extractFirstNumber(left.duration)
        .compareTo(_extractFirstNumber(right.duration)),
    LibrarySortOrder.countryAsc =>
      _sortText(left.country).compareTo(_sortText(right.country)),
    LibrarySortOrder.achievementsDesc => _libraryAchievementPercent(right)
        .compareTo(_libraryAchievementPercent(left)),
  };
  if (result != 0) {
    return result;
  }
  return _sortText(left.title).compareTo(_sortText(right.title));
}

/// Logros guardados en local de cada juego (desbloqueados, total). Se rellena
/// al abrir Juegos leyendo del disco; nunca consulta la red.
final Map<String, (int, int)> _libraryAchievementCache = {};

/// Porcentaje de logros de 0 a 100; los juegos sin datos van al final (-1).
double _libraryAchievementPercent(LibraryItem item) {
  final logros = _libraryAchievementCache[item.id];
  if (logros == null || logros.$2 <= 0) return -1;
  return logros.$1 * 100 / logros.$2;
}

bool _libraryHasAllAchievements(LibraryItem item) {
  final logros = _libraryAchievementCache[item.id];
  return logros != null && logros.$2 > 0 && logros.$1 >= logros.$2;
}

String _searchableText(LibraryItem item) {
  return [
    item.title,
    item.platform,
    item.developer,
    item.author,
    item.mediaType?.name,
    item.releaseYear?.toString(),
    item.creatorOrDirector,
    item.genre,
    item.format,
    item.duration,
    item.pages,
    item.country,
    item.note,
    item.universeName,
    item.collectionName,
    item.collectionNumber?.toString(),
  ].whereType<String>().join(' ');
}

String _libraryCreator(LibraryItem item) {
  return _sortText(switch (item.type) {
    LibraryItemType.game => item.developer ?? item.creatorOrDirector,
    LibraryItemType.book => item.author ?? item.creatorOrDirector,
    LibraryItemType.movieSeries => item.creatorOrDirector,
  });
}

String _sortText(String? value) => (value ?? '').trim().toLowerCase();

int _extractFirstNumber(String? value) {
  final match = RegExp(r'\d+').firstMatch(value ?? '');
  return match == null ? 0 : int.tryParse(match.group(0)!) ?? 0;
}

bool _isLocalCoverPath(String value) {
  final lower = value.toLowerCase();
  return RegExp(r'^[a-z]:[\\/]').hasMatch(lower) ||
      lower.startsWith('\\\\') ||
      lower.startsWith('/');
}

Future<String?> _copyLibraryCover(XFile file) async {
  final extension = await _detectCoverExtension(file);
  if (extension == null) {
    return null;
  }
  final directory = await _libraryCoversDirectory();
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final target =
      File('${directory.path}${Platform.pathSeparator}cover_$stamp$extension');
  await file.saveTo(target.path);
  return target.path;
}

Future<String?> _copyLibraryCoverBytes(Uint8List bytes) async {
  final extension = _coverExtensionFromSignature(bytes);
  if (extension == null) return null;
  final directory = await _libraryCoversDirectory();
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final target =
      File('${directory.path}${Platform.pathSeparator}cover_$stamp$extension');
  await target.writeAsBytes(bytes, flush: true);
  return target.path;
}

Future<String?> _detectCoverExtension(XFile file) async {
  final signature = await _readCoverSignature(file.openRead);
  return _coverExtensionFromSignature(signature);
}

Future<List<int>> _readCoverSignature(
  Stream<List<int>> Function([int? start, int? end]) openRead,
) async {
  final bytes = <int>[];
  await for (final chunk in openRead(0, 16)) {
    bytes.addAll(chunk);
    if (bytes.length >= 16) {
      break;
    }
  }
  return bytes.length > 16 ? bytes.sublist(0, 16) : bytes;
}

String? _coverExtensionFromSignature(List<int> bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return '.jpg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return '.png';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return '.webp';
  }
  return null;
}

Future<Directory> _libraryCoversDirectory() async {
  final home = Platform.environment['USERPROFILE'] ??
      Platform.environment['HOME'] ??
      Directory.current.path;
  final documents = Directory('$home${Platform.pathSeparator}Documents');
  final base = documents.existsSync()
      ? Directory('${documents.path}${Platform.pathSeparator}Todo')
      : Directory(home);
  final covers = Directory(
    '${base.path}${Platform.pathSeparator}library_covers',
  );
  if (!await covers.exists()) {
    await covers.create(recursive: true);
  }
  return covers;
}
