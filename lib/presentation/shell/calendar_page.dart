part of 'app_shell.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({required this.controller, super.key});

  final TodoWorkspace controller;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late _CalendarViewMode _mode;
  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  TodoWorkspace get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    final today = controller.logicalDate();
    _mode = _CalendarViewMode.month;
    _visibleMonth = DateTime(today.year, today.month);
    _selectedDay = today;
  }

  @override
  Widget build(BuildContext context) {
    final today = controller.logicalDate();
    final entries = _calendarEntriesFromController(controller);

    if (_selectedDay.year != _visibleMonth.year ||
        _selectedDay.month != _visibleMonth.month) {
      _selectedDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CalendarTopHeader(
            controller: controller,
            mode: _mode,
            today: today,
            onModeSelected: (mode) {
              setState(() {
                _mode = mode;
                if (mode == _CalendarViewMode.month) {
                  _visibleMonth =
                      DateTime(_selectedDay.year, _selectedDay.month);
                }
              });
            },
            onCreate: () => showTaskEditor(
              context,
              controller,
              initialDateOverride: DateTime(
                  _selectedDay.year, _selectedDay.month, _selectedDay.day, 10),
            ),
            onTodayPressed: () {
              setState(() {
                _selectedDay = today;
                _visibleMonth = DateTime(today.year, today.month);
              });
            },
            onSyncPressed: controller.isCalendarConnected
                ? () => controller.refreshCalendarEvents()
                : null,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: switch (_mode) {
              _CalendarViewMode.month => _CalendarMonthView(
                  controller: controller,
                  visibleMonth: _visibleMonth,
                  selectedDay: _selectedDay,
                  today: today,
                  entries: entries,
                  onSelectDay: (day) {
                    setState(() {
                      _selectedDay = day;
                      _visibleMonth = DateTime(day.year, day.month);
                    });
                  },
                  onPreviousMonth: () {
                    setState(() {
                      _visibleMonth = _shiftMonth(_visibleMonth, -1);
                      _selectedDay = DateTime(
                        _visibleMonth.year,
                        _visibleMonth.month,
                        1,
                      );
                    });
                  },
                  onNextMonth: () {
                    setState(() {
                      _visibleMonth = _shiftMonth(_visibleMonth, 1);
                      _selectedDay = DateTime(
                        _visibleMonth.year,
                        _visibleMonth.month,
                        1,
                      );
                    });
                  },
                  onOpenAgenda: () {
                    setState(() {
                      _mode = _CalendarViewMode.agenda;
                      _visibleMonth =
                          DateTime(_selectedDay.year, _selectedDay.month);
                    });
                  },
                ),
              _CalendarViewMode.week => _CalendarWeekView(
                  controller: controller,
                  anchor: _selectedDay,
                  entries: entries,
                  onSelectDay: (day) {
                    setState(() {
                      _selectedDay = day;
                      _visibleMonth = DateTime(day.year, day.month);
                    });
                  },
                ),
              _CalendarViewMode.agenda => _CalendarAgendaView(
                  controller: controller,
                  visibleMonth: _visibleMonth,
                  selectedDay: _selectedDay,
                  today: today,
                  entries: entries,
                  onSelectDay: (day) {
                    setState(() {
                      _selectedDay = day;
                      _visibleMonth = DateTime(day.year, day.month);
                    });
                  },
                  onPreviousMonth: () {
                    setState(() {
                      _visibleMonth = _shiftMonth(_visibleMonth, -1);
                    });
                  },
                  onNextMonth: () {
                    setState(() {
                      _visibleMonth = _shiftMonth(_visibleMonth, 1);
                    });
                  },
                ),
            },
          ),
        ],
      ),
    );
  }
}

class _CalendarTopHeader extends StatelessWidget {
  const _CalendarTopHeader({
    required this.controller,
    required this.mode,
    required this.today,
    required this.onModeSelected,
    required this.onCreate,
    required this.onTodayPressed,
    required this.onSyncPressed,
  });

  final TodoWorkspace controller;
  final _CalendarViewMode mode;
  final DateTime today;
  final ValueChanged<_CalendarViewMode> onModeSelected;
  final VoidCallback onCreate;
  final VoidCallback onTodayPressed;
  final VoidCallback? onSyncPressed;

  @override
  Widget build(BuildContext context) {
    final secondaryText =
        '${today.day}/${today.month}/${today.year} · tu día real cierra a las ${controller.daySettings.dayEndsAtHour}:00';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Calendario',
                      style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        secondaryText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: context.visuals.textMuted),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 280,
                  child: _CalendarModeSwitcher(
                    selected: mode,
                    onSelected: onModeSelected,
                  ),
                ),
                const SizedBox(width: 12),
                _CalendarFixedActionSlot(
                  child: _CalendarGhostButton(
                    label: 'Filtrar',
                    icon: Icons.filter_alt_outlined,
                    onPressed: mode == _CalendarViewMode.agenda ? () {} : null,
                  ),
                ),
                const SizedBox(width: 12),
                _CalendarFixedActionSlot(
                  child: _CalendarGhostButton(
                    label: 'Ordenar',
                    icon: Icons.swap_vert_rounded,
                    onPressed: mode == _CalendarViewMode.agenda ? () {} : null,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 196,
                  child: _HeaderActionButton(
                    label: 'Nueva tarea / evento',
                    icon: Icons.add_rounded,
                    onPressed: onCreate,
                  ),
                ),
                const SizedBox(width: 12),
                _CalendarFixedActionSlot(
                  child: _CalendarGhostButton(
                    label: 'Hoy',
                    icon: Icons.calendar_today_outlined,
                    onPressed: onTodayPressed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _CalendarFixedActionSlot extends StatelessWidget {
  const _CalendarFixedActionSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 108, child: child);
  }
}

class _CalendarModeSwitcher extends StatelessWidget {
  const _CalendarModeSwitcher({
    required this.selected,
    required this.onSelected,
  });

  final _CalendarViewMode selected;
  final ValueChanged<_CalendarViewMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DCCB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _calendarModeChip('Mes', selected == _CalendarViewMode.month,
                onTap: () => onSelected(_CalendarViewMode.month)),
          ),
          Expanded(
            child: _calendarModeChip(
                'Semana', selected == _CalendarViewMode.week,
                onTap: () => onSelected(_CalendarViewMode.week)),
          ),
          Expanded(
            child: _calendarModeChip(
                'Agenda', selected == _CalendarViewMode.agenda,
                onTap: () => onSelected(_CalendarViewMode.agenda)),
          ),
        ],
      ),
    );
  }
}

Widget _calendarModeChip(String label, bool selected,
    {required VoidCallback onTap}) {
  return InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    child: Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF70835D) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : const Color(0xFF2D2A25),
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _CalendarGhostButton extends StatelessWidget {
  const _CalendarGhostButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        backgroundColor: Colors.white.withValues(alpha: 0.6),
        side: const BorderSide(color: Color(0xFFE8DCCB)),
      ),
      label: Text(label),
    );
  }
}

class _CalendarMonthView extends StatelessWidget {
  const _CalendarMonthView({
    required this.controller,
    required this.visibleMonth,
    required this.selectedDay,
    required this.today,
    required this.entries,
    required this.onSelectDay,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onOpenAgenda,
  });

  final TodoWorkspace controller;
  final DateTime visibleMonth;
  final DateTime selectedDay;
  final DateTime today;
  final List<_CalendarEntry> entries;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onOpenAgenda;

  @override
  Widget build(BuildContext context) {
    final gridDays = _monthGridDays(visibleMonth);
    final monthEntries = entries
        .where((entry) => entry.start.year == visibleMonth.year)
        .where((entry) => entry.start.month == visibleMonth.month)
        .toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                  child: Row(
                    children: [
                      _CalendarMonthArrows(
                        onPrevious: onPreviousMonth,
                        onNext: onNextMonth,
                      ),
                      const SizedBox(width: 18),
                      Text(
                        '${_monthLong(visibleMonth.month)} ${visibleMonth.year}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      _CalendarGhostButton(
                        label: 'Hoy',
                        icon: Icons.calendar_today_outlined,
                        onPressed: () => onSelectDay(today),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        Container(
                          height: 52,
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0xFFF0E6D8)),
                            ),
                          ),
                          child: const Row(
                            children: [
                              _MonthWeekdayHeader('Lun'),
                              _MonthWeekdayHeader('Mar'),
                              _MonthWeekdayHeader('Mié'),
                              _MonthWeekdayHeader('Jue'),
                              _MonthWeekdayHeader('Vie'),
                              _MonthWeekdayHeader('Sáb'),
                              _MonthWeekdayHeader('Dom'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: List<Widget>.generate(6, (weekIndex) {
                              final weekDays =
                                  gridDays.skip(weekIndex * 7).take(7).toList();
                              return Expanded(
                                child: Row(
                                  children: weekDays.map((day) {
                                    final dayEntries = monthEntries
                                        .where((entry) =>
                                            _sameDay(entry.start, day))
                                        .toList()
                                      ..sort(
                                          (a, b) => a.start.compareTo(b.start));
                                    return Expanded(
                                      child: _CalendarMonthCell(
                                        day: day,
                                        visibleMonth: visibleMonth,
                                        isSelected: _sameDay(day, selectedDay),
                                        isToday: _sameDay(day, today),
                                        entries: dayEntries,
                                        onTap: () => onSelectDay(day),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 18),
        SizedBox(
          width: 330,
          child: _CalendarMonthSidePanel(
            controller: controller,
            selectedDay: selectedDay,
            entries: entries,
            onOpenAgenda: onOpenAgenda,
          ),
        ),
      ],
    );
  }
}

class _MonthWeekdayHeader extends StatelessWidget {
  const _MonthWeekdayHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _CalendarMonthArrows extends StatelessWidget {
  const _CalendarMonthArrows({
    required this.onPrevious,
    required this.onNext,
  });

  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8DCCB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Container(width: 1, height: 28, color: const Color(0xFFF0E6D8)),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _CalendarMonthCell extends StatelessWidget {
  const _CalendarMonthCell({
    required this.day,
    required this.visibleMonth,
    required this.isSelected,
    required this.isToday,
    required this.entries,
    required this.onTap,
  });

  final DateTime day;
  final DateTime visibleMonth;
  final bool isSelected;
  final bool isToday;
  final List<_CalendarEntry> entries;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inMonth = day.month == visibleMonth.month;
    final visibleEntries = entries.take(2).toList();
    final overflowCount = entries.length - visibleEntries.length;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5F7ED) : Colors.transparent,
          border: const Border(
            right: BorderSide(color: Color(0xFFF0E6D8)),
            bottom: BorderSide(color: Color(0xFFF0E6D8)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: isSelected
                  ? Row(
                      children: [
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: inMonth
                                ? const Color(0xFF2D2A25)
                                : const Color(0xFFB9AD9D),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF70835D),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${entries.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: isToday
                            ? const Color(0xFFEAF0DE)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: inMonth
                                ? const Color(0xFF2D2A25)
                                : const Color(0xFFC3B8A8),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            for (final entry in visibleEntries) ...[
              _CalendarMonthEntryChip(entry: entry),
              const SizedBox(height: 6),
            ],
            if (overflowCount > 0)
              Text(
                '+ $overflowCount más',
                style: const TextStyle(
                  color: Color(0xFF6E665D),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CalendarMonthEntryChip extends StatelessWidget {
  const _CalendarMonthEntryChip({required this.entry});

  final _CalendarEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: entry.background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: entry.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: entry.foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarMonthSidePanel extends StatelessWidget {
  const _CalendarMonthSidePanel({
    required this.controller,
    required this.selectedDay,
    required this.entries,
    required this.onOpenAgenda,
  });

  final TodoWorkspace controller;
  final DateTime selectedDay;
  final List<_CalendarEntry> entries;
  final VoidCallback onOpenAgenda;

  @override
  Widget build(BuildContext context) {
    final dayEntries = entries
        .where((entry) => _sameDay(entry.start, selectedDay))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final activeTasks = dayEntries
        .where((entry) => entry.isTask && !entry.isCompleted)
        .toList();
    final completedTasks =
        dayEntries.where((entry) => entry.isTask && entry.isCompleted).toList();
    final events = dayEntries.where((entry) => !entry.isTask).toList();
    final upcoming = entries
        .where((entry) => entry.start.isAfter(_endOfDay(selectedDay)))
        .where((entry) => !entry.isCompleted)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_weekdayLabelForMonth(selectedDay)} ${selectedDay.day} ${_monthLong(selectedDay.month)}',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontSize: 21),
                  ),
                ),
                Icon(Icons.calendar_today_outlined,
                    size: 18, color: context.visuals.textMuted),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: Row(
              children: [
                Expanded(
                  child: _CalendarStatCard(
                    value: '${activeTasks.length}',
                    label: 'tareas',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CalendarStatCard(
                    value: '${events.length}',
                    label: 'evento',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CalendarStatCard(
                    value: '${completedTasks.length}',
                    label: 'completadas',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CalendarSideSection(
                    title: 'Tareas',
                    child: activeTasks.isEmpty && completedTasks.isEmpty
                        ? _CalendarEmptyLine('No hay tareas este día.')
                        : Column(
                            children: [
                              for (final entry in activeTasks)
                                _CalendarTaskRow(entry: entry),
                              for (final entry in completedTasks)
                                _CalendarTaskRow(entry: entry),
                            ],
                          ),
                  ),
                  const SizedBox(height: 18),
                  _CalendarSideSection(
                    title: 'Eventos',
                    child: events.isEmpty
                        ? _CalendarEmptyLine('No hay eventos este día.')
                        : Column(
                            children: events
                                .map((entry) =>
                                    _CalendarEventSideRow(entry: entry))
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 18),
                  _CalendarSideSection(
                    title: 'Próximos',
                    child: upcoming.isEmpty
                        ? _CalendarEmptyLine('No hay próximos elementos.')
                        : Column(
                            children: upcoming.take(3).map((entry) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(top: 7),
                                      decoration: BoxDecoration(
                                        color: entry.dot,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${_weekdayShort(entry.start)} ${entry.start.day} ${_monthLong(entry.start.month)}',
                                            style: TextStyle(
                                                color:
                                                    context.visuals.textMuted),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(entry.title),
                                        ],
                                      ),
                                    ),
                                    if (entry.categoryLabel != null)
                                      _miniBadge(
                                        entry.categoryLabel!,
                                        entry.background,
                                        entry.foreground,
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onOpenAgenda,
                      child: const Text('Ver agenda completa'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarStatCard extends StatelessWidget {
  const _CalendarStatCard({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DCCB)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: context.visuals.textMuted)),
        ],
      ),
    );
  }
}

class _CalendarSideSection extends StatelessWidget {
  const _CalendarSideSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

class _CalendarTaskRow extends StatelessWidget {
  const _CalendarTaskRow({required this.entry});

  final _CalendarEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(
            entry.isCompleted
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 22,
            color: entry.isCompleted
                ? const Color(0xFFA4AE95)
                : const Color(0xFF7E786E),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.title,
              style: TextStyle(
                fontSize: 16,
                decoration:
                    entry.isCompleted ? TextDecoration.lineThrough : null,
                color: entry.isCompleted
                    ? context.visuals.textMuted
                    : const Color(0xFF2D2A25),
              ),
            ),
          ),
          if (entry.categoryLabel != null)
            _miniBadge(
                entry.categoryLabel!, entry.background, entry.foreground),
        ],
      ),
    );
  }
}

class _CalendarEventSideRow extends StatelessWidget {
  const _CalendarEventSideRow({required this.entry});

  final _CalendarEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 7),
            decoration: BoxDecoration(color: entry.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(entry.title)),
                    if (!entry.allDay)
                      Text(
                        _timeLabel(entry.start),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
                if (entry.categoryLabel != null) ...[
                  const SizedBox(height: 8),
                  _miniBadge(
                      entry.categoryLabel!, entry.background, entry.foreground),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarEmptyLine extends StatelessWidget {
  const _CalendarEmptyLine(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(color: context.visuals.textMuted, height: 1.4),
    );
  }
}

class _CalendarWeekView extends StatelessWidget {
  const _CalendarWeekView({
    required this.controller,
    required this.anchor,
    required this.entries,
    required this.onSelectDay,
  });

  final TodoWorkspace controller;
  final DateTime anchor;
  final List<_CalendarEntry> entries;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final start = _startOfWeek(anchor);
    final days = List<DateTime>.generate(
      7,
      (index) => start.add(Duration(days: index)),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFF0E6D8)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Semana del ${start.day} de ${_monthLong(start.month)} al ${start.add(const Duration(days: 6)).day} de ${_monthLong(start.add(const Duration(days: 6)).month)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Sin placeholders',
                        style: TextStyle(color: context.visuals.textMuted),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    itemCount: days.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final day = days[index];
                      final dayEntries = entries
                          .where((entry) => _sameDay(entry.start, day))
                          .toList()
                        ..sort((a, b) => a.start.compareTo(b.start));
                      return InkWell(
                        onTap: () => onSelectDay(day),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE8DCCB)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 110,
                                child: Text(
                                  '${_weekdayShort(day)} ${day.day}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: dayEntries.isEmpty
                                    ? _CalendarEmptyLine(
                                        'Sin elementos programados.')
                                    : Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: dayEntries
                                            .map((entry) => _miniBadge(
                                                  entry.allDay
                                                      ? entry.title
                                                      : '${_timeLabel(entry.start)} ${entry.title}',
                                                  entry.background,
                                                  entry.foreground,
                                                ))
                                            .toList(),
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
            ),
          ),
        ),
        const SizedBox(width: 18),
        SizedBox(
          width: 330,
          child: _CalendarMonthSidePanel(
            controller: controller,
            selectedDay: anchor,
            entries: entries,
            onOpenAgenda: () {},
          ),
        ),
      ],
    );
  }
}

class _CalendarAgendaView extends StatelessWidget {
  const _CalendarAgendaView({
    required this.controller,
    required this.visibleMonth,
    required this.selectedDay,
    required this.today,
    required this.entries,
    required this.onSelectDay,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final TodoWorkspace controller;
  final DateTime visibleMonth;
  final DateTime selectedDay;
  final DateTime today;
  final List<_CalendarEntry> entries;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    final upcoming = entries
        .where((entry) => !entry.isCompleted)
        .where((entry) => !entry.start.isBefore(today))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final groups = <_CalendarAgendaGroup>[
      _CalendarAgendaGroup(
        title:
            'Hoy · ${_weekdayLong(today)} ${today.day} de ${_monthLong(today.month)}',
        items: upcoming.where((entry) => _sameDay(entry.start, today)).toList(),
      ),
      _CalendarAgendaGroup(
        title:
            'Mañana · ${_weekdayLong(today.add(const Duration(days: 1)))} ${today.add(const Duration(days: 1)).day} de ${_monthLong(today.add(const Duration(days: 1)).month)}',
        items: upcoming
            .where((entry) =>
                _sameDay(entry.start, today.add(const Duration(days: 1))))
            .toList(),
      ),
      _CalendarAgendaGroup(
        title:
            'Esta semana · ${today.add(const Duration(days: 2)).day} ${_monthLong(today.add(const Duration(days: 2)).month)} - ${_endOfWeek(today).day} ${_monthLong(_endOfWeek(today).month)}',
        items: upcoming
            .where((entry) =>
                entry.start
                    .isAfter(_endOfDay(today.add(const Duration(days: 1)))) &&
                !entry.start.isAfter(_endOfWeek(today)))
            .toList(),
      ),
      _CalendarAgendaGroup(
        title:
            'Próxima semana · ${_startOfWeek(today.add(const Duration(days: 7))).day} - ${_endOfWeek(today.add(const Duration(days: 7))).day} ${_monthLong(_endOfWeek(today.add(const Duration(days: 7))).month)}',
        items: upcoming
            .where((entry) =>
                !entry.start.isBefore(
                    _startOfWeek(today.add(const Duration(days: 7)))) &&
                !entry.start
                    .isAfter(_endOfWeek(today.add(const Duration(days: 7)))))
            .toList(),
      ),
    ];

    final dueItems = upcoming.where((entry) => entry.isTask).take(6).toList();
    final eventItems =
        upcoming.where((entry) => !entry.isTask).take(4).toList();

    final groupCards = groups
        .where((group) => group.items.isNotEmpty)
        .map((group) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _CalendarAgendaGroupCard(group: group),
            ))
        .toList()
        .cast<Widget>();
    if (groupCards.isEmpty) {
      groupCards.add(
        _SurfaceCard(
          child: _CalendarEmptyLine(
            'No hay tareas ni eventos programados en la agenda.',
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(children: groupCards),
          ),
        ),
        const SizedBox(width: 18),
        SizedBox(
          width: 330,
          child: Column(
            children: [
              _CalendarMiniMonthPanel(
                visibleMonth: visibleMonth,
                selectedDay: selectedDay,
                entries: entries,
                onPreviousMonth: onPreviousMonth,
                onNextMonth: onNextMonth,
                onSelectDay: onSelectDay,
              ),
              const SizedBox(height: 14),
              _CalendarAgendaSummaryPanel(
                controller: controller,
                anchor: today,
                entries: upcoming,
              ),
              const SizedBox(height: 14),
              _CalendarAgendaSidebarList(
                title: 'Próximos vencimientos',
                items: dueItems,
                emptyLabel: 'No hay vencimientos próximos.',
              ),
              const SizedBox(height: 14),
              _CalendarAgendaSidebarList(
                title: 'Próximos eventos',
                items: eventItems,
                emptyLabel: 'No hay eventos próximos.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CalendarAgendaGroup {
  const _CalendarAgendaGroup({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_CalendarEntry> items;
}

class _CalendarAgendaGroupCard extends StatelessWidget {
  const _CalendarAgendaGroupCard({required this.group});

  final _CalendarAgendaGroup group;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _miniBadge(
                  '${group.items.length}',
                  const Color(0xFFF1ECE4),
                  const Color(0xFF665E54),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final entry in group.items) ...[
            _CalendarAgendaRow(entry: entry),
            if (entry != group.items.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _CalendarAgendaRow extends StatelessWidget {
  const _CalendarAgendaRow({required this.entry});

  final _CalendarEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 58,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: entry.dot,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              entry.allDay ? 'Todo el día' : _timeLabel(entry.start),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (entry.categoryLabel != null) ...[
                    const SizedBox(width: 10),
                    _miniBadge(
                      entry.categoryLabel!,
                      entry.background,
                      entry.foreground,
                    ),
                  ],
                  if (entry.projectLabel != null) ...[
                    const SizedBox(width: 10),
                    _miniBadge(
                      entry.projectLabel!,
                      const Color(0xFFF5F0E8),
                      const Color(0xFF6E665D),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(
            width: 140,
            child: Text(
              entry.trailingLabel ?? '',
              textAlign: TextAlign.right,
              style: TextStyle(color: context.visuals.textMuted),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.more_horiz_rounded),
        ],
      ),
    );
  }
}

class _CalendarMiniMonthPanel extends StatelessWidget {
  const _CalendarMiniMonthPanel({
    required this.visibleMonth,
    required this.selectedDay,
    required this.entries,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDay,
  });

  final DateTime visibleMonth;
  final DateTime selectedDay;
  final List<_CalendarEntry> entries;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final gridDays = _monthGridDays(visibleMonth).take(35).toList();
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_monthLong(visibleMonth.month)} ${visibleMonth.year}',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontSize: 21),
                ),
              ),
              IconButton(
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(child: Center(child: Text('Lun'))),
              Expanded(child: Center(child: Text('Mar'))),
              Expanded(child: Center(child: Text('Mié'))),
              Expanded(child: Center(child: Text('Jue'))),
              Expanded(child: Center(child: Text('Vie'))),
              Expanded(child: Center(child: Text('Sáb'))),
              Expanded(child: Center(child: Text('Dom'))),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: gridDays.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.9,
            ),
            itemBuilder: (context, index) {
              final day = gridDays[index];
              final dayEntries =
                  entries.where((entry) => _sameDay(entry.start, day)).length;
              final isSelected = _sameDay(day, selectedDay);
              final inMonth = day.month == visibleMonth.month;
              return InkWell(
                onTap: () => onSelectDay(day),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF70835D)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : inMonth
                                  ? const Color(0xFF2D2A25)
                                  : const Color(0xFFB9AD9D),
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 2,
                      children: List<Widget>.generate(
                        dayEntries.clamp(0, 3),
                        (_) => Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Color(0xFFB08BEA),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CalendarAgendaSummaryPanel extends StatelessWidget {
  const _CalendarAgendaSummaryPanel({
    required this.controller,
    required this.anchor,
    required this.entries,
  });

  final TodoWorkspace controller;
  final DateTime anchor;
  final List<_CalendarEntry> entries;

  @override
  Widget build(BuildContext context) {
    final weekEnd = _endOfWeek(anchor);
    final weekly = entries
        .where((entry) =>
            !entry.start.isBefore(anchor) && !entry.start.isAfter(weekEnd))
        .toList();
    final tasks = weekly.where((entry) => entry.isTask).length;
    final events = weekly.where((entry) => !entry.isTask).length;
    final routines = weekly.where((entry) => entry.isRecurring).length;
    final maxValue = [tasks, events, routines, 1]
        .reduce((current, next) => current > next ? current : next)
        .toDouble();

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen de la semana',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontSize: 21),
          ),
          const SizedBox(height: 4),
          Text(
            '${anchor.day} ${_monthShort(anchor.month)} - ${weekEnd.day} ${_monthShort(weekEnd.month)}',
            style: TextStyle(color: context.visuals.textMuted),
          ),
          const SizedBox(height: 16),
          _CalendarSummaryBar(
            label: 'Tareas',
            value: tasks,
            maxValue: maxValue,
            color: const Color(0xFF7A915E),
          ),
          const SizedBox(height: 10),
          _CalendarSummaryBar(
            label: 'Eventos',
            value: events,
            maxValue: maxValue,
            color: const Color(0xFF9A84DA),
          ),
          const SizedBox(height: 10),
          _CalendarSummaryBar(
            label: 'Rutinas',
            value: routines,
            maxValue: maxValue,
            color: const Color(0xFFF1A340),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Día real cierra a las ${controller.daySettings.dayEndsAtHour}:00',
                  style: TextStyle(color: context.visuals.textMuted),
                ),
              ),
              Icon(Icons.info_outline_rounded,
                  size: 18, color: context.visuals.textMuted),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarSummaryBar extends StatelessWidget {
  const _CalendarSummaryBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final String label;
  final int value;
  final double maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label)),
        SizedBox(
          width: 24,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value / maxValue,
              minHeight: 6,
              backgroundColor: const Color(0xFFF1ECE4),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

class _CalendarAgendaSidebarList extends StatelessWidget {
  const _CalendarAgendaSidebarList({
    required this.title,
    required this.items,
    required this.emptyLabel,
  });

  final String title;
  final List<_CalendarEntry> items;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontSize: 21),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            _CalendarEmptyLine(emptyLabel)
          else
            Column(
              children: items.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(entry.leadingIcon,
                          color: entry.foreground, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.allDay
                                  ? '${_weekdayShort(entry.start)} ${entry.start.day} ${_monthShort(entry.start.month)} · Todo el día'
                                  : '${_weekdayShort(entry.start)} ${entry.start.day} ${_monthShort(entry.start.month)} · ${_timeLabel(entry.start)}',
                              style:
                                  TextStyle(color: context.visuals.textMuted),
                            ),
                          ],
                        ),
                      ),
                      if (entry.categoryLabel != null)
                        _miniBadge(
                          entry.categoryLabel!,
                          entry.background,
                          entry.foreground,
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          InkWell(
            onTap: () {},
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Ver todos los ${title.toLowerCase()} (${items.length})',
                    style: TextStyle(color: context.visuals.textMuted),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarEntry {
  const _CalendarEntry({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    required this.isTask,
    required this.isCompleted,
    required this.isRecurring,
    required this.background,
    required this.border,
    required this.foreground,
    required this.dot,
    required this.leadingIcon,
    this.categoryLabel,
    this.projectLabel,
    this.trailingLabel,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final bool isTask;
  final bool isCompleted;
  final bool isRecurring;
  final Color background;
  final Color border;
  final Color foreground;
  final Color dot;
  final IconData leadingIcon;
  final String? categoryLabel;
  final String? projectLabel;
  final String? trailingLabel;
}

List<_CalendarEntry> _calendarEntriesFromController(TodoWorkspace controller) {
  final taskEntries =
      controller.tasks.where((task) => task.scheduledAt != null).map((task) {
    final category = task.categoryIds.isNotEmpty
        ? controller.categoryById(task.categoryIds.first)
        : null;
    final project = task.projectIds.isNotEmpty
        ? controller.projectById(task.projectIds.first)
        : null;
    final color = category?.color ?? const Color(0xFF8DAA7F);
    final scheduled = task.scheduledAt!;
    return _CalendarEntry(
      id: task.id,
      title: task.title,
      start: scheduled,
      end: scheduled.add(const Duration(hours: 1)),
      allDay: false,
      isTask: true,
      isCompleted: task.status == TaskStatus.completed,
      isRecurring: task.recurrence.isRecurring,
      background: task.status == TaskStatus.completed
          ? const Color(0xFFF3F0EA)
          : color.withValues(alpha: 0.16),
      border: task.status == TaskStatus.completed
          ? const Color(0xFFE0D8CF)
          : color.withValues(alpha: 0.26),
      foreground: task.status == TaskStatus.completed
          ? const Color(0xFF8D8479)
          : const Color(0xFF2D2A25),
      dot:
          task.status == TaskStatus.completed ? const Color(0xFFB9B1A5) : color,
      leadingIcon: task.recurrence.isRecurring
          ? Icons.refresh_rounded
          : Icons.radio_button_checked_rounded,
      categoryLabel: category?.name,
      projectLabel: project != null ? 'Proyecto: ${project.name}' : null,
      trailingLabel: task.recurrence.isRecurring
          ? 'Rutina · ${_recurrenceSummary(task)}'
          : project?.name,
    );
  });

  final eventEntries = controller.calendarEvents.map((event) {
    final isAllDay = _isAllDayRange(event.startAt, event.endAt);
    return _CalendarEntry(
      id: event.id,
      title: event.title,
      start: event.startAt,
      end: event.endAt,
      allDay: isAllDay,
      isTask: false,
      isCompleted: false,
      isRecurring: false,
      background: const Color(0xFFF0ECFB),
      border: const Color(0xFFD9CFF0),
      foreground: const Color(0xFF2D2A25),
      dot: const Color(0xFF8F74D3),
      leadingIcon:
          isAllDay ? Icons.event_available_rounded : Icons.event_rounded,
      categoryLabel: 'Evento',
      projectLabel: null,
      trailingLabel: isAllDay ? 'Todo el día' : _timeLabel(event.startAt),
    );
  });

  return [...taskEntries, ...eventEntries].toList()
    ..sort((left, right) => left.start.compareTo(right.start));
}

DateTime _shiftMonth(DateTime source, int delta) {
  final monthValue = source.month + delta;
  return DateTime(source.year, monthValue);
}

List<DateTime> _monthGridDays(DateTime visibleMonth) {
  final firstDay = DateTime(visibleMonth.year, visibleMonth.month, 1);
  final start = firstDay.subtract(Duration(days: firstDay.weekday - 1));
  return List<DateTime>.generate(
    42,
    (index) => start.add(Duration(days: index)),
  );
}

DateTime _startOfWeek(DateTime day) => DateTime(day.year, day.month, day.day)
    .subtract(Duration(days: day.weekday - 1));

DateTime _endOfWeek(DateTime day) => DateTime(
      _startOfWeek(day).year,
      _startOfWeek(day).month,
      _startOfWeek(day).day + 6,
      23,
      59,
      59,
    );

DateTime _endOfDay(DateTime day) =>
    DateTime(day.year, day.month, day.day, 23, 59, 59);

String _weekdayLabelForMonth(DateTime day) {
  const labels = <int, String>{
    DateTime.monday: 'Lun',
    DateTime.tuesday: 'Mar',
    DateTime.wednesday: 'Mié',
    DateTime.thursday: 'Jue',
    DateTime.friday: 'Vie',
    DateTime.saturday: 'Sáb',
    DateTime.sunday: 'Dom',
  };
  return labels[day.weekday] ?? _weekdayShort(day);
}

String _monthShort(int month) {
  const labels = <int, String>{
    1: 'ene',
    2: 'feb',
    3: 'mar',
    4: 'abr',
    5: 'may',
    6: 'jun',
    7: 'jul',
    8: 'ago',
    9: 'sep',
    10: 'oct',
    11: 'nov',
    12: 'dic',
  };
  return labels[month] ?? '';
}

String _recurrenceSummary(TaskModel task) {
  switch (task.recurrence.type) {
    case RecurrenceType.none:
      return 'Sin repetición';
    case RecurrenceType.daily:
      return 'Diaria';
    case RecurrenceType.everyXDays:
      return 'Cada ${task.recurrence.interval} días';
    case RecurrenceType.weekly:
      return 'Semanal';
    case RecurrenceType.yearly:
      return 'Anual';
  }
}

Widget _miniBadge(String text, Color background, Color foreground) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(text, style: TextStyle(fontSize: 12, color: foreground)),
  );
}

int _completedStreak(List<TaskModel> completed, DateTime today) {
  final days = completed
      .map((task) => task.scheduledAt ?? today)
      .map((stamp) => DateTime(stamp.year, stamp.month, stamp.day))
      .toSet()
      .toList()
    ..sort((left, right) => right.compareTo(left));

  var streak = 0;
  var cursor = today;
  for (final day in days) {
    if (_sameDay(day, cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
      continue;
    }
    if (day.isBefore(cursor)) {
      break;
    }
  }

  return streak;
}
