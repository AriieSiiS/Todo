part of 'editors.dart';

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const colors = <int>[
      0xFF607A5A,
      0xFFC8A46A,
      0xFFAA5C4D,
      0xFF6A7D93,
      0xFF8C6D8A,
      0xFFF2A67A,
      0xFF8FB6EF,
      0xFFAAD5A1,
      0xFFB7AAA3,
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors
          .map(
            (colorValue) => InkWell(
              onTap: () => onSelected(colorValue),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Color(colorValue),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected == colorValue
                        ? Colors.black
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DraftProjectTask {
  const _DraftProjectTask({
    required this.title,
    this.dueDate,
  });

  final String title;
  final DateTime? dueDate;

  _DraftProjectTask copyWith({
    String? title,
    DateTime? dueDate,
  }) {
    return _DraftProjectTask(
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
    );
  }
}

Widget _dialogHeader(
  BuildContext context, {
  required String title,
  required String subtitle,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                  color: Theme.of(context).extension<TodoVisuals>()!.textMuted),
            ),
          ],
        ),
      ),
      IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close_rounded),
      ),
    ],
  );
}

Widget _dialogFooter({
  required String primaryLabel,
  required String secondaryLabel,
  required Future<void> Function() onPrimary,
  required Future<void> Function() onSecondary,
}) {
  return Builder(
    builder: (context) => Row(
      children: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: () async => onSecondary(),
          child: Text(secondaryLabel),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: () async => onPrimary(),
          child: Text(primaryLabel),
        ),
      ],
    ),
  );
}

class _AsideCard extends StatelessWidget {
  const _AsideCard({
    this.title,
    this.subtitle,
    required this.child,
  });

  final String? title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _softBorderBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: TextStyle(
                      color: Theme.of(context)
                          .extension<TodoVisuals>()!
                          .textMuted)),
            ],
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

BoxDecoration _softBorderBox() {
  return BoxDecoration(
    border: Border.all(color: const Color(0xFFE2D5C4)),
    borderRadius: BorderRadius.circular(16),
  );
}

Widget _tagChip(String text, Color background, Color foreground) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(
          color: foreground, fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
}

Widget _summaryLine(IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF70835D)),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

Widget _appearanceRow(String left, String right) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFBF7F0),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(child: Text(left, style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 8),
        _tagChip(right, const Color(0xFFE7EEFF), const Color(0xFF6F90D8)),
      ],
    ),
  );
}

Widget _sectionLabel(String text) {
  return Text(text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600));
}

class _PrioritySegmentedControl extends StatelessWidget {
  const _PrioritySegmentedControl({
    required this.selected,
    required this.onChanged,
  });

  final TaskPriority selected;
  final ValueChanged<TaskPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    final segments = <({TaskPriority value, String label})>[
      (value: TaskPriority.low, label: 'Baja'),
      (value: TaskPriority.medium, label: 'Media'),
      (value: TaskPriority.high, label: 'Alta'),
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF7B8764)),
      ),
      child: Row(
        children: [
          for (var index = 0; index < segments.length; index++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(segments[index].value),
                borderRadius: BorderRadius.horizontal(
                  left: index == 0 ? const Radius.circular(999) : Radius.zero,
                  right: index == segments.length - 1
                      ? const Radius.circular(999)
                      : Radius.zero,
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected == segments[index].value
                        ? const Color(0xFFD8E2C5)
                        : Colors.white,
                    borderRadius: BorderRadius.horizontal(
                      left:
                          index == 0 ? const Radius.circular(999) : Radius.zero,
                      right: index == segments.length - 1
                          ? const Radius.circular(999)
                          : Radius.zero,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        child: AnimatedOpacity(
                          opacity: selected == segments[index].value ? 1 : 0,
                          duration: const Duration(milliseconds: 120),
                          child: const Icon(Icons.check_rounded,
                              size: 16, color: Color(0xFF5E6F4D)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          segments[index].label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF433F39),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _pickerField(
  BuildContext context, {
  required String label,
  required IconData icon,
  required String value,
  required VoidCallback onTap,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionLabel(label),
      const SizedBox(height: 6),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: InputDecoration(prefixIcon: Icon(icon)),
          child:
              Text(value, style: const TextStyle(fontWeight: FontWeight.w400)),
        ),
      ),
    ],
  );
}

String _dateLabel(DateTime value) =>
    '${_weekdayLong(value)}, ${value.day} de ${_monthLong(value.month)}';

String _shortDate(DateTime value) =>
    '${_weekdayShort(value)} ${value.day} ${_monthShort(value.month)}';

String _weekdayLong(DateTime value) => const <String>[
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ][value.weekday - 1];

String _weekdayShort(DateTime value) => const <String>[
      'Lun',
      'Mar',
      'Mié',
      'Jue',
      'Vie',
      'Sáb',
      'Dom'
    ][value.weekday - 1];

String _monthLong(int month) => const <String>[
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
    ][month];

String _monthShort(int month) => const <String>[
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
      'dic'
    ][month];

String _formatTime24(TimeOfDay value) {
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

bool _hasVisibleTimeOfDay(TimeOfDay value) =>
    value.hour != 0 || value.minute != 0;

String _priorityLabel(TaskPriority priority) => switch (priority) {
      TaskPriority.low => 'Baja prioridad',
      TaskPriority.medium => 'Prioridad media',
      TaskPriority.high => 'Alta prioridad',
      TaskPriority.urgent => 'Urgente',
    };

String _recurrenceLabelFor(
        RecurrenceType type, DateTime date, TimeOfDay time, int interval) =>
    switch (type) {
      RecurrenceType.none => 'Sin repeticion',
      RecurrenceType.daily => 'Diaria',
      RecurrenceType.weekly =>
        'Semanal · ${_weekdayLong(date)} a las ${_formatTime24(time)}',
      RecurrenceType.everyXDays => 'Cada $interval dias',
      RecurrenceType.yearly => 'Anual',
    };

ProjectModel? _findProject(List<ProjectModel> projects, String? id) {
  if (id == null) {
    return null;
  }
  for (final project in projects) {
    if (project.id == id) {
      return project;
    }
  }
  return null;
}
