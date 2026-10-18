part of 'todo_workspace.dart';

extension TodoWorkspaceResumen on TodoWorkspace {
  /// Lunes de la semana que contiene [reference] (por defecto, el día lógico).
  DateTime weekStartFor([DateTime? reference]) {
    final day = logicalDate(reference);
    return DateTime(day.year, day.month, day.day - (day.weekday - 1));
  }

  /// Resumen de la semana que empieza en [weekStart], en texto plano con
  /// formato Markdown sencillo. Solo se genera cuando se pide.
  String buildWeeklySummary({DateTime? weekStart}) {
    final start = weekStart == null
        ? weekStartFor()
        : DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = DateTime(start.year, start.month, start.day + 7);
    final lastDay = DateTime(end.year, end.month, end.day - 1);
    bool inWeek(DateTime? value) =>
        value != null && !value.isBefore(start) && value.isBefore(end);

    final buffer = StringBuffer()
      ..writeln('# Resumen de la semana')
      ..writeln('${_resumenDia(start)} – ${_resumenDia(lastDay)} de ${lastDay.year}')
      ..writeln();

    // Tareas.
    final completed = <String>[];
    for (final task in _tasks) {
      if (task.isSubtask) continue;
      if (task.recurrence.isRecurring) {
        for (final done in task.recurrenceCompletions.values) {
          if (inWeek(done)) completed.add(task.title);
        }
      } else if (task.status == TaskStatus.completed &&
          inWeek(task.completedAt)) {
        completed.add(task.title);
      }
    }
    buffer.writeln('## Tareas');
    if (completed.isEmpty) {
      buffer.writeln('No hay tareas completadas esta semana.');
    } else {
      buffer.writeln('Has completado ${completed.length}.');
      for (final title in completed.take(10)) {
        buffer.writeln('- $title');
      }
      if (completed.length > 10) {
        buffer.writeln('- … y ${completed.length - 10} más');
      }
    }
    final plantTasks = _tasks.where((task) =>
        task.sourcePlantId != null &&
        task.status == TaskStatus.completed &&
        inWeek(task.completedAt));
    final plantCount = plantTasks.length;
    if (plantCount > 0) {
      buffer.writeln('Cuidados de plantas hechos: $plantCount.');
    }
    final pending = _tasks
        .where((task) =>
            !task.isSubtask &&
            task.status == TaskStatus.active &&
            task.scheduledAt != null &&
            task.scheduledAt!.isBefore(start))
        .length;
    if (pending > 0) {
      buffer.writeln('Tareas activas con fecha anterior a la semana: $pending.');
    }
    buffer.writeln();

    // Biblioteca.
    final library = _libraryItems
        .where((item) =>
            item.status == LibraryItemStatus.completed &&
            inWeek(item.completedDate))
        .toList();
    buffer.writeln('## Biblioteca');
    if (library.isEmpty) {
      buffer.writeln('No has terminado nada esta semana.');
    } else {
      for (final item in library) {
        final rating = item.rating == null
            ? ''
            : ' (${item.rating!.toStringAsFixed(1).replaceAll('.', ',')})';
        buffer.writeln('- ${item.title}$rating');
      }
    }
    buffer.writeln();

    // Gastos.
    final weekExpenses =
        _expenses.where((expense) => inWeek(expense.date)).toList();
    final spent =
        weekExpenses.fold<double>(0, (sum, expense) => sum + expense.amount);
    buffer.writeln('## Gastos');
    if (weekExpenses.isEmpty) {
      buffer.writeln('No hay gastos registrados.');
    } else {
      buffer.writeln('Total: ${_resumenDinero(spent)} en ${weekExpenses.length} gastos.');
      final byCategory = <String, double>{};
      for (final expense in weekExpenses) {
        final name = expenseCategoryById(expense.categoryId)?.name ?? 'Sin categoría';
        byCategory[name] = (byCategory[name] ?? 0) + expense.amount;
      }
      final top = byCategory.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in top.take(3)) {
        buffer.writeln('- ${entry.key}: ${_resumenDinero(entry.value)}');
      }
    }
    final nextWeekEnd = DateTime(end.year, end.month, end.day + 7);
    final upcomingPayments = upcomingFixedPayments()
        .where((payment) =>
            !payment.nextPaymentDate.isBefore(end) &&
            payment.nextPaymentDate.isBefore(nextWeekEnd))
        .toList();
    if (upcomingPayments.isNotEmpty) {
      buffer.writeln('Cobros de la semana próxima:');
      for (final payment in upcomingPayments) {
        buffer.writeln(
            '- ${payment.name}: ${_resumenDinero(payment.amount)} (${_resumenDia(payment.nextPaymentDate)})');
      }
    }
    buffer.writeln();

    // Enfoque.
    final focusSeconds = focusSecondsBetween(start, end);
    buffer.writeln('## Enfoque');
    if (focusSeconds == 0) {
      buffer.writeln('No has registrado sesiones.');
    } else {
      final sessions = _focusSessions
          .where((session) => inWeek(session.startedAt))
          .length;
      buffer.writeln(
          '${_resumenDuracion(focusSeconds)} repartidos en $sessions sesiones.');
    }
    buffer.writeln();

    // Diario.
    final entries =
        _journalEntries.where((entry) => inWeek(entry.date)).toList();
    final moods = entries.where((entry) => entry.mood > 0).toList();
    buffer.writeln('## Diario');
    if (entries.isEmpty) {
      buffer.writeln('No has escrito entradas.');
    } else {
      buffer.write('Entradas: ${entries.length} de 7 días.');
      if (moods.isNotEmpty) {
        final average = moods.fold<int>(0, (sum, entry) => sum + entry.mood) /
            moods.length;
        buffer.write(
            ' Ánimo medio: ${average.toStringAsFixed(1).replaceAll('.', ',')} de 5.');
      }
      buffer.writeln();
    }
    buffer.writeln();

    // Viajes.
    final trips = _trips
        .where((trip) =>
            !trip.archived &&
            !trip.startDate.isAfter(nextWeekEnd) &&
            !trip.endDate.isBefore(start))
        .toList();
    if (trips.isNotEmpty) {
      buffer.writeln('## Viajes');
      for (final trip in trips) {
        buffer.writeln(
            '- ${trip.name}${trip.destination.isEmpty ? '' : ' (${trip.destination})'}: ${_resumenDia(trip.startDate)} – ${_resumenDia(trip.endDate)}');
      }
    }
    return buffer.toString().trimRight();
  }

  static String _resumenDia(DateTime day) {
    const meses = <String>[
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
    ];
    return '${day.day} de ${meses[day.month - 1]}';
  }

  static String _resumenDinero(double value) =>
      '${value.toStringAsFixed(2).replaceAll('.', ',')} €';

  static String _resumenDuracion(int segundos) {
    final minutos = segundos ~/ 60;
    if (minutos < 60) return '$minutos min';
    return '${minutos ~/ 60} h ${(minutos % 60).toString().padLeft(2, '0')} min';
  }
}
