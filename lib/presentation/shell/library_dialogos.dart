part of 'app_shell.dart';

class _LibraryCoverImage extends StatelessWidget {
  const _LibraryCoverImage({
    required this.source,
    required this.type,
    this.iconSize = 24,
  });

  final String? source;
  final LibraryItemType type;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final value = source?.trim();
    if (value == null || value.isEmpty) {
      return _LibraryCoverFallback(type: type, iconSize: iconSize);
    }
    if (_isLocalCoverPath(value)) {
      return _LocalLibraryCoverImage(
        path: value,
        type: type,
        iconSize: iconSize,
      );
    }
    return Image.network(
      value,
      fit: BoxFit.cover,
      cacheWidth: 600,
      errorBuilder: (context, error, stackTrace) =>
          _LibraryCoverFallback(type: type, iconSize: iconSize),
    );
  }
}

class _LocalLibraryCoverImage extends StatelessWidget {
  const _LocalLibraryCoverImage({
    required this.path,
    required this.type,
    required this.iconSize,
  });

  final String path;
  final LibraryItemType type;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      cacheWidth: 600,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) =>
          _LibraryCoverFallback(type: type, iconSize: iconSize),
    );
  }
}

class _LibraryCoverFallback extends StatelessWidget {
  const _LibraryCoverFallback({required this.type, required this.iconSize});

  final LibraryItemType type;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Icon(
      _libraryIcon(type),
      color: _libraryColor(type),
      size: iconSize,
    );
  }
}

class _LibraryFilterResult {
  const _LibraryFilterResult({
    required this.type,
    required this.year,
    required this.query,
    required this.minRating,
  });

  final LibraryItemType? type;
  final int year;
  final String query;
  final double? minRating;
}

class _LibraryFilterDialog extends StatefulWidget {
  const _LibraryFilterDialog({
    required this.type,
    required this.year,
    required this.query,
    required this.minRating,
  });

  final LibraryItemType? type;
  final int year;
  final String query;
  final double? minRating;

  @override
  State<_LibraryFilterDialog> createState() => _LibraryFilterDialogState();
}

class _LibraryFilterDialogState extends State<_LibraryFilterDialog> {
  late LibraryItemType? _type = widget.type;
  late int _year = widget.year;
  late final TextEditingController _query =
      TextEditingController(text: widget.query);
  late final TextEditingController _rating = TextEditingController(
    text: widget.minRating == null ? '' : '${widget.minRating}',
  );

  @override
  void dispose() {
    _query.dispose();
    _rating.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filtros'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<LibraryItemType?>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Todas')),
                DropdownMenuItem(
                    value: LibraryItemType.game, child: Text('Juegos')),
                DropdownMenuItem(
                    value: LibraryItemType.book, child: Text('Libros')),
                DropdownMenuItem(
                  value: LibraryItemType.movieSeries,
                  child: Text('Películas y series'),
                ),
              ],
              onChanged: (value) => setState(() => _type = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _year,
              decoration: const InputDecoration(labelText: 'Año'),
              items: const [
                DropdownMenuItem(value: 2026, child: Text('2026')),
                DropdownMenuItem(value: 2025, child: Text('2025')),
                DropdownMenuItem(value: 2024, child: Text('2024')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _year = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _query,
              decoration: const InputDecoration(labelText: 'Buscar por título'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rating,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Valoración mínima'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            const _LibraryFilterResult(
              type: null,
              year: 2026,
              query: '',
              minRating: null,
            ),
          ),
          child: const Text('Limpiar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _LibraryFilterResult(
              type: _type,
              year: _year,
              query: _query.text.trim(),
              minRating: double.tryParse(_rating.text.replaceAll(',', '.')),
            ),
          ),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

class _LibraryGoalDialog extends StatefulWidget {
  const _LibraryGoalDialog({
    required this.controller,
    required this.year,
    this.initialType,
    this.goal,
  });

  final TodoWorkspace controller;
  final int year;
  final LibraryItemType? initialType;
  final LibraryGoal? goal;

  @override
  State<_LibraryGoalDialog> createState() => _LibraryGoalDialogState();
}

class _LibraryGoalDialogState extends State<_LibraryGoalDialog> {
  late LibraryItemType _type = widget.initialType ?? LibraryItemType.game;
  LibraryMediaType _mediaType = LibraryMediaType.movie;
  late int _year = widget.year;
  bool _favorite = false;
  bool _completed = false;
  final _title = TextEditingController();
  final _platform = TextEditingController();
  final _developer = TextEditingController();
  final _author = TextEditingController();
  final _releaseYear = TextEditingController();
  final _creator = TextEditingController();
  final _genre = TextEditingController();
  final _format = TextEditingController();
  final _duration = TextEditingController();
  final _pages = TextEditingController();
  final _country = TextEditingController();
  final _note = TextEditingController();
  final _cover = TextEditingController();
  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    if (goal == null) {
      return;
    }
    _type = goal.type;
    _mediaType = goal.mediaType ?? LibraryMediaType.movie;
    _year = goal.targetYear;
    _favorite = goal.isFavorite;
    _completed = goal.isCompleted;
    _title.text = goal.title;
    _platform.text = goal.platform ?? '';
    _developer.text = goal.developer ?? '';
    _author.text = goal.author ?? '';
    _releaseYear.text = goal.releaseYear?.toString() ?? '';
    _creator.text = goal.creatorOrDirector ?? '';
    _genre.text = goal.genre ?? '';
    _format.text = goal.format ?? '';
    _duration.text = goal.duration ?? '';
    _pages.text = goal.pages ?? '';
    _country.text = goal.country ?? '';
    _note.text = goal.note ?? '';
    _cover.text = goal.coverUrl ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    _platform.dispose();
    _developer.dispose();
    _author.dispose();
    _releaseYear.dispose();
    _creator.dispose();
    _genre.dispose();
    _format.dispose();
    _duration.dispose();
    _pages.dispose();
    _country.dispose();
    _note.dispose();
    _cover.dispose();
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
                                ? 'Editar propósito'
                                : 'Añadir propósito',
                            style: const TextStyle(
                                fontSize: 23, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _isEditing
                                ? 'Actualiza los datos de este propósito.'
                                : 'Registra algo que quieres completar este año.',
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
                      Text(_goalDialogInfoTitle(),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _LibraryImageDropField(
                            label: _goalImageLabel(),
                            type: _type,
                            icon: _libraryIcon(_type),
                            controller: _cover,
                            width: 244,
                            height: 416,
                          ),
                          const SizedBox(width: 30),
                          Expanded(child: _goalTypedFields()),
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

  Widget _goalTypedFields() {
    return Column(
      children: [
        _goalDialogField(_title, 'Título *', _goalTitleHint()),
        const SizedBox(height: 16),
        if (_type == LibraryItemType.game) ...[
          Row(
            children: [
              Expanded(
                  child: _goalDialogField(_platform, 'Plataforma', 'Ej. PC')),
              const SizedBox(width: 14),
              Expanded(
                child: _goalDialogField(
                  _releaseYear,
                  'Año de lanzamiento',
                  'Ej. 2017',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _goalDialogField(
                    _developer, 'Desarrollador', 'Ej. Arkane Studios'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _goalDialogField(_genre, 'Género', 'Ej. Inmersivo, RPG'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _goalDialogField(
            _duration,
            'Horas estimadas',
            'Ej. 20 h',
          ),
        ] else if (_type == LibraryItemType.book) ...[
          Row(
            children: [
              Expanded(
                  child: _goalDialogField(
                      _author, 'Autor', 'Ej. Samantha Shannon')),
              const SizedBox(width: 14),
              Expanded(
                child: _goalDialogField(
                  _releaseYear,
                  'Año de publicación',
                  'Ej. 2023',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _goalBookTypeField()),
              const SizedBox(width: 14),
              Expanded(child: _goalBookFormatField()),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child:
                    _goalDialogField(_genre, 'Género', 'Ej. Fantasía, Clásico'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _goalDialogField(
                    _pages, 'Páginas / Volúmenes', 'Ej. 864 páginas'),
              ),
            ],
          ),
        ] else ...[
          Row(
            children: [
              Expanded(child: _goalMediaTypeField()),
              const SizedBox(width: 14),
              Expanded(
                child: _goalDialogField(
                  _releaseYear,
                  'Año de estreno',
                  'Ej. 1972',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _goalDialogField(
                  _duration,
                  'Duración',
                  'Ej. 2h 55m',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _goalDialogField(
                  _country,
                  'País de origen',
                  'Ej. Estados Unidos',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _goalDialogField(
                  _creator,
                  'Director / Creador',
                  'Ej. Francis Ford Coppola',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _goalDialogField(
                  _genre,
                  'Género',
                  'Ej. Drama, Acción',
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _goalYearField(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SwitchListTile(
                value: _favorite,
                onChanged: (value) => setState(() => _favorite = value),
                title: const Text('Prioritario'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        if (_isEditing) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            value: _completed,
            onChanged: (value) => setState(() => _completed = value),
            title: const Text('Completado'),
            secondary: Icon(
              _completed
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: _completed
                  ? const Color(0xFF70835D)
                  : context.visuals.textMuted,
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
        const SizedBox(height: 16),
        _goalDialogField(_note, 'Nota opcional', 'Añade contexto o motivo...'),
      ],
    );
  }

  Widget _goalDialogField(
    TextEditingController controller,
    String label,
    String hint, {
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: context.visuals.textMuted.withValues(alpha: 0.72),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _goalBookTypeField() {
    return _goalDropdownTextField(
      label: 'Tipo *',
      controller: _creator,
      fallback: 'Libro',
      options: const ['Libro', 'Manga', 'Cómic'],
    );
  }

  Widget _goalBookFormatField() {
    return _goalDropdownTextField(
      label: 'Formato *',
      controller: _format,
      fallback: 'eBook',
      options: const ['Físico', 'eBook'],
    );
  }

  Widget _goalDropdownTextField({
    required String label,
    required TextEditingController controller,
    required String fallback,
    required List<String> options,
  }) {
    final current =
        options.contains(controller.text) ? controller.text : fallback;
    controller.text = current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: current,
          decoration: const InputDecoration(),
          style: TextStyle(
            color: context.visuals.textStrong,
            fontSize: 16,
            fontWeight: FontWeight.w400,
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
      ],
    );
  }

  Widget _goalYearField() {
    final currentYear = DateTime.now().year;
    final years = <int>{_year, currentYear, currentYear + 1}.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Año *', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _year,
          decoration: const InputDecoration(),
          items: [
            for (final year in years)
              DropdownMenuItem(value: year, child: Text('$year')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _year = value);
            }
          },
        ),
      ],
    );
  }

  Widget _goalMediaTypeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tipo *', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        DropdownButtonFormField<LibraryMediaType>(
          initialValue: _mediaType,
          decoration: const InputDecoration(),
          style: TextStyle(
            color: context.visuals.textStrong,
            fontSize: 16,
            fontWeight: FontWeight.w400,
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
      ],
    );
  }

  String _goalDialogInfoTitle() => switch (_type) {
        LibraryItemType.game => 'Información del juego',
        LibraryItemType.book => 'Información del libro / manga',
        LibraryItemType.movieSeries =>
          'Información de la película / serie / anime',
      };

  String _goalTitleHint() => switch (_type) {
        LibraryItemType.game => 'Ej. Prey',
        LibraryItemType.book => 'Ej. El Priorato del Naranjo',
        LibraryItemType.movieSeries => 'Ej. El Padrino',
      };

  String _goalImageLabel() => switch (_type) {
        LibraryItemType.game => 'Carátula',
        LibraryItemType.book => 'Portada',
        LibraryItemType.movieSeries => 'Póster',
      };

  void _save() {
    if (_title.text.trim().isEmpty) {
      return;
    }
    final goal = widget.goal;
    if (goal != null) {
      widget.controller.updateLibraryGoal(
        goal.copyWith(
          title: _title.text.trim(),
          targetYear: _year,
          isFavorite: _favorite,
          coverUrl: _cover.text.trim().isEmpty ? null : _cover.text.trim(),
          clearCoverUrl: _cover.text.trim().isEmpty,
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
        ),
      );
      final navigator = Navigator.of(context);
      final parentContext = navigator.context;
      navigator.pop();
      if (_completed != goal.isCompleted) {
        _toggleLibraryGoalCompleted(parentContext, widget.controller, goal.id);
      }
      return;
    }
    widget.controller.createLibraryGoal(
      type: _type,
      title: _title.text,
      targetYear: _year,
      isFavorite: _favorite,
      coverUrl: _cover.text,
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
    );
    Navigator.of(context).pop();
  }
}
