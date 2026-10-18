part of 'app_shell.dart';

Future<void> showWeeklySummary(BuildContext context, TodoWorkspace controller) {
  return showDialog<void>(
    context: context,
    builder: (context) => _WeeklySummaryDialog(controller: controller),
  );
}

/// Muestra el resumen de una semana. Solo se calcula al abrirlo o al cambiar
/// de semana: no se genera nada de forma automática.
class _WeeklySummaryDialog extends StatefulWidget {
  const _WeeklySummaryDialog({required this.controller});

  final TodoWorkspace controller;

  @override
  State<_WeeklySummaryDialog> createState() => _WeeklySummaryDialogState();
}

class _WeeklySummaryDialogState extends State<_WeeklySummaryDialog> {
  int _weeksBack = 0;
  bool _copied = false;

  DateTime get _weekStart {
    final current = widget.controller.weekStartFor();
    return DateTime(current.year, current.month, current.day - 7 * _weeksBack);
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.buildWeeklySummary(weekStart: _weekStart);
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Resumen semanal')),
          IconButton(
            key: const ValueKey('summary-previous'),
            tooltip: 'Semana anterior',
            onPressed: () => setState(() {
              _weeksBack += 1;
              _copied = false;
            }),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            key: const ValueKey('summary-next'),
            tooltip: 'Semana siguiente',
            onPressed: _weeksBack == 0
                ? null
                : () => setState(() {
                      _weeksBack -= 1;
                      _copied = false;
                    }),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: SelectableText(
            text,
            key: const ValueKey('summary-text'),
            style: const TextStyle(height: 1.4),
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          key: const ValueKey('summary-copy'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (mounted) setState(() => _copied = true);
          },
          icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded),
          label: Text(_copied ? 'Copiado' : 'Copiar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
