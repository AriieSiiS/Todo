import 'package:flutter/material.dart';

import '../../domain/models.dart';
import 'book_reading_panel.dart';
import 'texto_busqueda.dart';

class LibraryQuotesDialog extends StatefulWidget {
  const LibraryQuotesDialog(
      {required this.books, this.onEdit, this.onDelete, super.key});

  final List<LibraryItem> books;
  final void Function(LibraryItem book, Map<String, dynamic> quote)? onEdit;
  final void Function(LibraryItem book, Map<String, dynamic> quote)? onDelete;

  @override
  State<LibraryQuotesDialog> createState() => _LibraryQuotesDialogState();
}

class _LibraryQuotesDialogState extends State<LibraryQuotesDialog> {
  final _search = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final books = widget.books
        .where((book) => book.type == LibraryItemType.book)
        .toList()
      ..sort((a, b) => a.title.paraBuscar.compareTo(b.title.paraBuscar));
    final all = [
      for (final book in books)
        for (final quote in orderedBookQuotes(book.reading))
          if ((quote['text'] as String? ?? '').trim().isNotEmpty)
            (book: book, quote: quote),
    ];
    final query = _search.text.trim().paraBuscar;
    final matches = all
        .where((entry) => [
              entry.book.title,
              entry.book.author ?? '',
              entry.quote['text'] ?? '',
              entry.quote['note'] ?? '',
              entry.quote['page'] ?? '',
              entry.quote['chapter'] ?? '',
            ].join(' ').paraBuscar.contains(query))
        .toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(Icons.format_quote_rounded, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Citas de tus libros',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  tooltip: 'Cerrar citas',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Buscar citas, libros o autores',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (_) {
                  if (_scroll.hasClients) _scroll.jumpTo(0);
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: matches.isEmpty
                    ? Center(
                        child: Text(
                          all.isEmpty
                              ? 'Todavía no hay citas en tus libros'
                              : 'No hay citas que coincidan',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      )
                    : Scrollbar(
                        controller: _scroll,
                        child: ListView.separated(
                          controller: _scroll,
                          padding: const EdgeInsets.only(right: 12),
                          itemCount: matches.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) => _LibraryQuoteCard(
                            book: matches[index].book,
                            quote: matches[index].quote,
                            onEdit: widget.onEdit,
                            onDelete: widget.onDelete,
                          ),
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

class _LibraryQuoteCard extends StatelessWidget {
  const _LibraryQuoteCard(
      {required this.book, required this.quote, this.onEdit, this.onDelete});

  final LibraryItem book;
  final Map<String, dynamic> quote;
  final void Function(LibraryItem book, Map<String, dynamic> quote)? onEdit;
  final void Function(LibraryItem book, Map<String, dynamic> quote)? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = quote['text'] as String;
    final note = quote['note'] as String? ?? '';
    final page = quote['page'] as String? ?? '';
    final chapter = quote['chapter'] as String? ?? '';
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.primary, fontWeight: FontWeight.w700)),
                  if (book.author?.trim().isNotEmpty == true)
                    Text(book.author!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant)),
                ],
              ),
            ),
            BookQuoteActions(
              quote: quote,
              onEdit: onEdit == null ? null : () => onEdit!(book, quote),
              onDelete: onDelete == null ? null : () => onDelete!(book, quote),
            ),
          ]),
          const SizedBox(height: 12),
          SelectableText(text,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 12),
            SelectableText('Nota: $note',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontStyle: FontStyle.italic)),
          ],
          if (page.isNotEmpty || chapter.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
                [
                  if (page.isNotEmpty) '${bookQuotePageLabel(quote)} $page',
                  if (chapter.isNotEmpty) chapter,
                ].join(' · '),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}
