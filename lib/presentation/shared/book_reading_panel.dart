import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/models.dart';

class BookReadingBadge extends StatelessWidget {
  const BookReadingBadge({required this.item, super.key});
  final LibraryItem item;
  @override
  Widget build(BuildContext context) {
    final reading = item.reading;
    final total = bookPageTotal(item.pages, reading) ?? 0;
    final percent = item.readingPercent;
    return Tooltip(
        message: [
          '$percent% leído',
          if (item.status != LibraryItemStatus.completed &&
              reading != null &&
              reading.page.isNotEmpty)
            '${reading.pageLabel} ${reading.page}${total > 0 ? ' de $total' : ''}',
          if (item.status != LibraryItemStatus.completed &&
              reading != null &&
              reading.chapter.trim().isNotEmpty)
            reading.chapter,
        ].join('\n'),
        child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: const Color(0xD9202732),
                border: Border.all(color: Colors.white.withValues(alpha: .18)),
                shape: BoxShape.circle),
            child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('$percent%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)))));
  }
}

List<Map<String, dynamic>> orderedBookQuotes(LibraryReading? reading) {
  final quotes = (reading?.quotes ?? <Map<String, dynamic>>[]).indexed.toList()
    ..sort((a, b) {
      final left = int.tryParse(a.$2['page'] as String? ?? '');
      final right = int.tryParse(b.$2['page'] as String? ?? '');
      if (left != null && right != null && left != right) {
        return left.compareTo(right);
      }
      return a.$1.compareTo(b.$1);
    });
  return [for (final entry in quotes) entry.$2];
}

String bookQuotePageLabel(Map<String, dynamic> quote) =>
    switch (quote['page_unit']) {
      'screen' => 'Pantalla',
      'page' => 'Página',
      'estimated_page' => 'Página',
      _ => quote['document_id'] == null ? 'Página' : 'Posición en KOReader'
    };

class BookQuotesPanel extends StatefulWidget {
  const BookQuotesPanel({
    required this.reading,
    this.onEdit,
    this.onDelete,
    super.key,
  });
  final LibraryReading? reading;
  final ValueChanged<Map<String, dynamic>>? onEdit;
  final ValueChanged<Map<String, dynamic>>? onDelete;

  @override
  State<BookQuotesPanel> createState() => _BookQuotesPanelState();
}

class _BookQuotesPanelState extends State<BookQuotesPanel> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final quotes = orderedBookQuotes(widget.reading);
    if (quotes.isEmpty) {
      return SizedBox(
          width: double.infinity,
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 20),
              child: Column(children: [
                Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: .07),
                        shape: BoxShape.circle),
                    child: Icon(Icons.format_quote_rounded,
                        size: 36, color: colors.primary)),
                const SizedBox(height: 20),
                Text('Todavía no hay citas',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Los subrayados que guardes en el Kindle aparecerán aquí.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant)),
              ])));
    }
    return LayoutBuilder(builder: (context, constraints) {
      final layouts = [
        for (final quote in quotes)
          _BookQuoteLayout(context, quote, constraints.maxWidth),
      ];
      final totalHeight =
          layouts.fold<double>(0, (sum, item) => sum + item.height) +
              (quotes.length - 1) * 8;
      final height =
          constraints.hasBoundedHeight ? constraints.maxHeight : totalHeight;
      final needsPages = totalHeight > height;
      final budget =
          (height - (needsPages ? 48 : 0)).clamp(1.0, double.infinity);
      final pages = <List<int>>[[]];
      var used = 0.0;
      for (var index = 0; index < quotes.length; index++) {
        final gap = pages.last.isEmpty ? 0 : 8;
        if (pages.last.isNotEmpty &&
            used + gap + layouts[index].height > budget) {
          pages.add([]);
          used = 0;
        }
        used += (pages.last.isEmpty ? 0 : 8) + layouts[index].height;
        pages.last.add(index);
      }
      final current = _page.clamp(0, pages.length - 1);
      final visible = pages[current];
      return SizedBox(
        height: height,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final index in visible) ...[
                      if (index != visible.first) const SizedBox(height: 8),
                      _BookQuoteCard(
                        quote: quotes[index],
                        layout: layouts[index],
                        onDelete: widget.onDelete == null
                            ? null
                            : () => widget.onDelete!(quotes[index]),
                        onEdit: widget.onEdit == null
                            ? null
                            : () => widget.onEdit!(quotes[index]),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ),
          if (pages.length > 1)
            SizedBox(
              height: 48,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                IconButton(
                  tooltip: 'Citas anteriores',
                  onPressed: current > 0
                      ? () => setState(() => _page = current - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                    '${visible.first + 1}–${visible.last + 1} de ${quotes.length}',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: colors.onSurfaceVariant)),
                IconButton(
                  tooltip: 'Citas siguientes',
                  onPressed: current < pages.length - 1
                      ? () => setState(() => _page = current + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ]),
            ),
        ]),
      );
    });
  }
}

/// Mide el texto con la misma tipografía que la tarjeta para paginar sin scroll.
class _BookQuoteLayout {
  _BookQuoteLayout(
      BuildContext context, Map<String, dynamic> quote, double width) {
    final theme = Theme.of(context);
    textStyle =
        theme.textTheme.bodyMedium!.copyWith(fontSize: 14, height: 1.35);
    noteStyle = theme.textTheme.bodyMedium!.copyWith(
        fontSize: 13,
        height: 1.3,
        fontStyle: FontStyle.italic,
        color: theme.colorScheme.onSurfaceVariant);
    TextPainter measure(String text, TextStyle style, int lines) => TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: lines,
        )..layout(maxWidth: (width - 26).clamp(1.0, double.infinity));
    final text = measure(quote['text'] as String? ?? '', textStyle, 5);
    final note = quote['note'] as String? ?? '';
    final noteText = note.isEmpty ? null : measure('Nota: $note', noteStyle, 2);
    showFullText =
        text.didExceedMaxLines || (noteText?.didExceedMaxLines ?? false);
    height = 26 +
        32 +
        8 +
        text.height +
        (noteText == null ? 0 : 8 + noteText.height) +
        (showFullText ? 32 : 0);
    text.dispose();
    noteText?.dispose();
  }

  late final TextStyle textStyle;
  late final TextStyle noteStyle;
  late final double height;
  late final bool showFullText;
}

class _BookQuoteCard extends StatelessWidget {
  const _BookQuoteCard(
      {required this.quote, required this.layout, this.onEdit, this.onDelete});
  final Map<String, dynamic> quote;
  final _BookQuoteLayout layout;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final page = quote['page'] as String? ?? '';
    final chapter = quote['chapter'] as String? ?? '';
    final note = quote['note'] as String? ?? '';
    return Container(
        height: layout.height,
        width: double.infinity,
        decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: colors.outlineVariant.withValues(alpha: .55))),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              height: 32,
              child: Row(children: [
                if (page.isNotEmpty) ...[
                  Text('${bookQuotePageLabel(quote)} $page',
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.primary, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                ],
                Expanded(
                    child: Text(chapter,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant))),
                BookQuoteActions(
                    quote: quote, onEdit: onEdit, onDelete: onDelete),
              ])),
          const SizedBox(height: 8),
          Text(quote['text'] as String,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: layout.textStyle),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Nota: $note',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: layout.noteStyle),
          ],
          if (layout.showFullText) ...[
            const SizedBox(height: 4),
            SizedBox(
                height: 28,
                child: TextButton(
                  style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Cita completa'),
                      scrollable: true,
                      content: SizedBox(
                        width: 560,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(quote['text'] as String),
                            if (note.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              SelectableText('Nota: $note',
                                  style: layout.noteStyle),
                            ],
                          ],
                        ),
                      ),
                      actions: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cerrar'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('Leer cita completa'),
                )),
          ],
        ]));
  }
}

class BookQuoteActions extends StatelessWidget {
  const BookQuoteActions(
      {required this.quote, this.onEdit, this.onDelete, super.key});

  final Map<String, dynamic> quote;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (onEdit != null)
        IconButton(
          tooltip: 'Editar cita',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          icon: const Icon(Icons.edit_outlined, size: 17),
          onPressed: onEdit,
        ),
      if (onDelete != null)
        IconButton(
          tooltip: 'Borrar cita',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          icon:
              Icon(Icons.delete_outline_rounded, size: 18, color: colors.error),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Borrar cita'),
                content: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(quote['text'] as String,
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 16),
                      const Text(
                          'Se borrará de Todo y no volverá a importarse del Kindle. El subrayado del libro se conserva.'),
                    ],
                  ),
                ),
                actions: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: colors.error,
                        foregroundColor: colors.onError),
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Borrar'),
                  ),
                ],
              ),
            );
            if (confirmed == true && context.mounted) onDelete!();
          },
        ),
      IconButton(
        tooltip: 'Copiar cita',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        icon: Icon(Icons.content_copy_rounded,
            size: 17, color: colors.onSurfaceVariant),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: quote['text'] as String));
          if (context.mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
              content: Text('Cita copiada'),
              persist: false,
              duration: Duration(seconds: 2),
            ));
          }
        },
      ),
    ]);
  }
}
