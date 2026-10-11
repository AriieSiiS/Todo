part of 'todo_workspace.dart';

extension TodoWorkspaceAgent on TodoWorkspace {
  Future<Map<String, dynamic>> executeAgentCommand(
      String name, Map<String, dynamic> arguments) {
    final result =
        _agentCommandQueue.then((_) => _executeAgentCommand(name, arguments));
    _agentCommandQueue =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Map<String, dynamic> _agentTask(TaskModel task) => {
        ...task.toJson(),
        'task_version': _agentTaskVersion(task),
      };

  Map<String, dynamic> _agentNote(QuickNote note) => {
        ...note.toJson(),
        'note_version': _agentDigest(note.toJson()),
      };

  Iterable<Map<String, dynamic>> _agentContent(String section) {
    return switch (section) {
      'notas' => _notes.map(_agentNote),
      'ropa' => _wardrobeItems.map((item) => item.toJson()),
      'conjuntos' => _wardrobeOutfits.map((item) => item.toJson()),
      'usos_ropa' => _wardrobeWearLogs.map((item) => item.toJson()),
      'planes_ropa' => _wardrobePlanEntries.map((item) => item.toJson()),
      'maletas' => _wardrobePackingLists.map((item) => item.toJson()),
      'recetas' => _recipes.map((item) => item.toJson()),
      'menus' => _weeklyMenus.map((item) => item.toJson()),
      'hogar' => _householdItems.map((item) => item.toJson()),
      'compras' => _shoppingItems.map((item) => item.toJson()),
      'biblioteca' => _libraryItems.map((item) => item.toJson()),
      'objetivos_biblioteca' => _libraryGoals.map((item) => item.toJson()),
      _ => throw const FormatException('La colección no está disponible.'),
    };
  }

  String _agentTaskVersion(TaskModel task) {
    final related = <TaskModel>[task];
    final visited = <String>{task.id};
    var ancestor = task;
    while (ancestor.parentTaskId != null) {
      final parent = taskById(ancestor.parentTaskId!);
      if (parent == null || !visited.add(parent.id)) break;
      related.add(parent);
      ancestor = parent;
    }
    for (var index = 0; index < related.length; index++) {
      for (final child
          in _tasks.where((item) => item.parentTaskId == related[index].id)) {
        if (visited.add(child.id)) related.add(child);
      }
    }
    related.sort((a, b) => a.id.compareTo(b.id));
    return _agentDigest({
      'tasks': related.map((item) => item.toJson()).toList(),
      'logicalDate': _occurrenceKey(logicalDate()),
    });
  }

  String _agentDigest(Object? value) {
    Object? ordered(Object? item) {
      if (item is Map) {
        final keys = item.keys.cast<String>().toList()..sort();
        return {for (final key in keys) key: ordered(item[key])};
      }
      if (item is List) return item.map(ordered).toList();
      return item;
    }

    return sha256.convert(utf8.encode(jsonEncode(ordered(value)))).toString();
  }

  Future<Map<String, dynamic>> _executeAgentCommand(
      String name, Map<String, dynamic> arguments) async {
    const schemas = <String, Set<String>>{
      'get_today': {},
      'list_tasks': {'status', 'project_id', 'category_id', 'date'},
      'get_task': {'task_id'},
      'list_projects': {},
      'list_categories': {},
      'read_content': {'section'},
      'list_content_sections': {},
      'delete_task': {'request_id', 'task_id', 'expected_version', 'confirm'},
      'create_note': {
        'request_id',
        'content',
        'scheduled_for',
        'emoji',
        'is_pinned',
        'category_ids'
      },
      'update_note': {
        'request_id',
        'note_id',
        'expected_version',
        'content',
        'scheduled_for',
        'clear_scheduled_for',
        'emoji',
        'is_pinned',
        'category_ids',
        'status'
      },
      'archive_note': {'request_id', 'note_id', 'expected_version'},
      'delete_note': {'request_id', 'note_id', 'expected_version', 'confirm'},
      'create_task': {
        'request_id',
        'title',
        'description',
        'scheduled_at',
        'priority',
        'category_ids',
        'project_ids',
        'recurrence_type',
        'recurrence_interval',
        'recurrence_weekdays'
      },
      'update_task': {
        'request_id',
        'task_id',
        'expected_version',
        'title',
        'description',
        'scheduled_at',
        'clear_scheduled_at',
        'priority',
        'category_ids',
        'project_ids'
      },
      'complete_task': {'request_id', 'task_id', 'expected_version'},
      'move_task_to_day': {'request_id', 'task_id', 'expected_version', 'date'},
    };
    final fields = schemas[name];
    if (fields == null || arguments.keys.any((key) => !fields.contains(key))) {
      throw const FormatException(
          'La herramienta o alguno de sus campos no está permitido.');
    }
    String text(String field, {bool required = false}) {
      final value = arguments[field];
      if (value == null && !required) return '';
      if (value is! String || (required && value.trim().isEmpty)) {
        throw FormatException('El campo $field debe contener texto válido.');
      }
      return value;
    }

    DateTime date(String value, {bool withTime = false}) {
      final pattern = withTime
          ? RegExp(
              r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,6})?)?(Z|[+-]\d{2}:\d{2})?$')
          : RegExp(r'^\d{4}-\d{2}-\d{2}$');
      final parsed = DateTime.tryParse(value);
      final plain =
          DateTime.tryParse(value.length >= 10 ? value.substring(0, 10) : '');
      if (!pattern.hasMatch(value) ||
          parsed == null ||
          plain == null ||
          _occurrenceKey(plain) != value.substring(0, 10) ||
          (withTime &&
              (int.parse(value.substring(11, 13)) > 23 ||
                  int.parse(value.substring(14, 16)) > 59 ||
                  (value.length >= 19 &&
                      int.tryParse(value.substring(17, 19)) != null &&
                      int.parse(value.substring(17, 19)) > 59)))) {
        throw const FormatException(
            'La fecha no tiene un formato ISO 8601 válido.');
      }
      return parsed.toLocal();
    }

    TaskModel findTask() {
      final task = taskById(text('task_id', required: true));
      if (task == null) throw const FormatException('La tarea ya no existe.');
      return task;
    }

    if (name == 'read_content') {
      return {
        'items': _agentContent(text('section', required: true)).toList(),
        'source': 'app'
      };
    }
    if (name == 'list_content_sections') {
      const titles = {
        'notas': 'Notas',
        'ropa': 'Ropa',
        'conjuntos': 'Conjuntos',
        'usos_ropa': 'Usos de ropa',
        'planes_ropa': 'Planes de ropa',
        'maletas': 'Maletas',
        'recetas': 'Recetas',
        'menus': 'Menús',
        'hogar': 'Hogar',
        'compras': 'Compras',
        'biblioteca': 'Biblioteca',
        'objetivos_biblioteca': 'Objetivos de Biblioteca'
      };
      return {
        'sections': [
          for (final entry in titles.entries)
            {
              'section': entry.key,
              'title': entry.value,
              'count': _agentContent(entry.key).length
            }
        ],
        'source': 'app'
      };
    }

    if (name == 'get_today') {
      return {
        'date': _occurrenceKey(logicalDate()),
        'tasks': tasksForToday().map(_agentTask).toList(),
        'source': 'app'
      };
    }
    if (name == 'get_task') {
      return {'task': _agentTask(findTask()), 'source': 'app'};
    }
    if (name == 'list_projects') {
      return {
        'projects': _projects.map((item) => item.toJson()).toList(),
        'source': 'app'
      };
    }
    if (name == 'list_categories') {
      return {
        'categories': _categories.map((item) => item.toJson()).toList(),
        'source': 'app'
      };
    }
    if (name == 'list_tasks') {
      final status = text('status');
      if (status.isNotEmpty &&
          !{'all', 'active', 'completed', 'archived'}.contains(status)) {
        throw const FormatException('El estado de la tarea no es válido.');
      }
      final project = text('project_id');
      final category = text('category_id');
      final day = text('date');
      final target = day.isEmpty
          ? null
          : day == 'today'
              ? logicalDate()
              : date(day);
      Iterable<TaskModel> selected = _tasks;
      selected = selected.where((task) =>
          (status.isEmpty || status == 'all' || task.status.name == status) &&
          (project.isEmpty || task.projectIds.contains(project)) &&
          (category.isEmpty || task.categoryIds.contains(category)) &&
          (target == null ||
              _agentMatchesDate(task, target, overdue: day == 'today')));
      return {'tasks': selected.map(_agentTask).toList(), 'source': 'app'};
    }

    final requestId = text('request_id', required: true);
    if (!RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(requestId)) {
      throw const FormatException(
          'request_id debe tener entre 8 y 128 letras, cifras, guiones o guiones bajos.');
    }
    final fingerprint = _agentDigest({'name': name, 'arguments': arguments});
    final receipt = _agentOperationReceipts[requestId] as Map?;
    if (receipt != null) {
      if (receipt['fingerprint'] != fingerprint) {
        throw const FormatException(
            'request_id ya se utilizó para una operación diferente.');
      }
      await _saveAgentChanges();
      return jsonDecode(jsonEncode(receipt['result'])) as Map<String, dynamic>;
    }
    if (_agentOperationReceipts.length >= 10000) {
      throw const FormatException(
          'El registro de operaciones está lleno. Revisa la conexión desde Todo.');
    }
    List<String>? relation(String field, Iterable<String> available) {
      if (!arguments.containsKey(field)) return null;
      final value = arguments[field];
      if (value is! List ||
          value.any((item) => item is! String || !available.contains(item))) {
        throw FormatException(
            'El campo $field contiene identificadores inexistentes.');
      }
      return value.cast<String>().toSet().toList();
    }

    final categories =
        relation('category_ids', _categories.map((item) => item.id));
    final projects = relation('project_ids', _projects.map((item) => item.id));
    if ({'create_note', 'update_note', 'archive_note', 'delete_note'}
        .contains(name)) {
      QuickNote? previous;
      if (name != 'create_note') {
        final id = text('note_id', required: true);
        for (final item in _notes) {
          if (item.id == id) previous = item;
        }
        if (previous == null) {
          throw const FormatException('La nota ya no existe.');
        }
        if (text('expected_version', required: true) !=
            _agentDigest(previous.toJson())) {
          throw const FormatException(
              'La nota cambió desde la consulta. Vuelve a consultarla.');
        }
      }
      if (name == 'delete_note') {
        if (arguments['confirm'] != true) {
          throw const FormatException(
              'Confirma el borrado permanente de la nota.');
        }
        _notes.removeWhere((item) => item.id == previous!.id);
        return _finishAgentOperation(requestId, fingerprint, {
          'deleted_ids': [previous!.id]
        });
      }
      final content = arguments.containsKey('content')
          ? text('content', required: true).trim()
          : previous?.content;
      if (content == null || content.isEmpty) {
        throw const FormatException('La nota necesita contenido.');
      }
      final clear = arguments['clear_scheduled_for'] ?? false;
      if (clear is! bool || (clear && arguments.containsKey('scheduled_for'))) {
        throw const FormatException(
            'La fecha no puede fijarse y eliminarse a la vez.');
      }
      final scheduled = arguments.containsKey('scheduled_for')
          ? date(text('scheduled_for', required: true), withTime: true)
          : previous?.scheduledFor;
      final pinned = arguments['is_pinned'] ?? previous?.isPinned ?? false;
      if (pinned is! bool) {
        throw const FormatException('is_pinned debe ser booleano.');
      }
      final status = text('status');
      if (status.isNotEmpty && !{'inbox', 'archived'}.contains(status)) {
        throw const FormatException('El estado de la nota no es válido.');
      }
      final note = (previous ??
              QuickNote(id: _id('note'), content: content, createdAt: now))
          .copyWith(
        content: content,
        scheduledFor: scheduled,
        clearScheduledFor: clear,
        emoji: arguments.containsKey('emoji') ? text('emoji') : null,
        isPinned: pinned,
        categoryIds: categories,
        updatedAt: now,
        status: name == 'archive_note' || status == 'archived'
            ? NoteStatus.archived
            : status == 'inbox'
                ? NoteStatus.inbox
                : null,
      );
      if (previous == null) {
        _notes.insert(0, note);
      } else {
        _notes[_notes.indexWhere((item) => item.id == note.id)] = note;
      }
      return _finishAgentOperation(requestId, fingerprint,
          {name == 'create_note' ? 'created' : 'note': _agentNote(note)});
    }
    TaskPriority? priority;
    if (arguments.containsKey('priority')) {
      final value = text('priority', required: true);
      if (!TaskPriority.values.any((item) => item.name == value)) {
        throw const FormatException('La prioridad no es válida.');
      }
      priority = TaskPriority.values.firstWhere((item) => item.name == value);
    }
    final title = arguments.containsKey('title')
        ? text('title', required: true).trim()
        : null;
    final description = arguments.containsKey('description')
        ? text('description').trim()
        : null;
    final scheduled = arguments.containsKey('scheduled_at')
        ? date(text('scheduled_at', required: true), withTime: true)
        : null;
    TaskModel task;
    if (name == 'create_task') {
      if (title == null) {
        throw const FormatException('La tarea necesita un título.');
      }
      final type = text('recurrence_type');
      if (type.isNotEmpty &&
          !RecurrenceType.values.any((item) => item.name == type)) {
        throw const FormatException('La recurrencia no es válida.');
      }
      final interval = arguments['recurrence_interval'] ?? 1;
      final weekdays = arguments['recurrence_weekdays'] ?? <int>[];
      if (interval is! int ||
          interval < 1 ||
          interval > 3650 ||
          weekdays is! List ||
          weekdays.any((day) => day is! int || day < 1 || day > 7)) {
        throw const FormatException(
            'El intervalo o los días de recurrencia no son válidos.');
      }
      task = TaskModel(
          id: _id('task'),
          title: title,
          description: description?.isEmpty == true ? null : description,
          scheduledAt: scheduled,
          priority: priority ?? TaskPriority.medium,
          categoryIds: categories ?? [],
          projectIds: projects ?? [],
          recurrence: RecurrenceRule(
              type: type.isEmpty
                  ? RecurrenceType.none
                  : RecurrenceType.values
                      .firstWhere((item) => item.name == type),
              interval: interval,
              weekdays: weekdays.cast<int>()),
          manualOrder: _nextManualOrder());
      _tasks.add(task);
    } else {
      task = findTask();
      if (text('expected_version', required: true) != _agentTaskVersion(task)) {
        throw const FormatException(
            'La tarea cambió desde la consulta. Vuelve a consultarla antes de modificarla.');
      }
      if (task.calendarLink != null) {
        throw const FormatException(
            'Las tareas enlazadas al calendario se editan desde Todo.');
      }
      if (task.status == TaskStatus.archived) {
        throw const FormatException(
            'La tarea está archivada. Revísala desde Todo.');
      }
      if (name == 'delete_task') {
        if (arguments['confirm'] != true) {
          throw const FormatException(
              'Confirma el borrado permanente de la tarea y sus subtareas.');
        }
        final ids = <String>{task.id};
        while (true) {
          final children = _tasks
              .where((item) => ids.contains(item.parentTaskId))
              .map((item) => item.id)
              .toSet();
          if (children.difference(ids).isEmpty) break;
          ids.addAll(children);
        }
        final affected = _tasks.where((item) => ids.contains(item.id)).toList();
        if (affected.any((item) =>
            item.calendarLink != null || item.status == TaskStatus.archived)) {
          throw const FormatException(
              'Revisa desde Todo las subtareas archivadas o enlazadas al calendario antes de borrar.');
        }
        _tasks.removeWhere((item) => ids.contains(item.id));
        for (var i = 0; i < _tasks.length; i++) {
          final item = _tasks[i];
          if (item.subtaskIds.any(ids.contains)) {
            _tasks[i] = item.copyWith(
                subtaskIds:
                    item.subtaskIds.where((id) => !ids.contains(id)).toList());
          }
        }
        return _finishAgentOperation(requestId, fingerprint, {
          'deleted_ids': ids.toList()..sort(),
          'deleted_titles': affected.map((item) => item.title).toList()
        });
      }
      if (name == 'update_task') {
        final clear = arguments['clear_scheduled_at'] ?? false;
        if (clear is! bool || (clear && scheduled != null)) {
          throw const FormatException(
              'La fecha no puede fijarse y eliminarse a la vez.');
        }
        task = task.copyWith(
            title: title,
            description: description,
            clearDescription: description == '',
            scheduledAt: scheduled,
            clearScheduledAt: clear,
            priority: priority,
            categoryIds: categories,
            projectIds: projects);
        _tasks[_tasks.indexWhere((item) => item.id == task.id)] = task;
      } else if (name == 'move_task_to_day') {
        final day = date(text('date', required: true));
        final previous = task.scheduledAt ?? logicalDate();
        task = task.copyWith(
            scheduledAt: DateTime(
                day.year,
                day.month,
                day.day,
                previous.hour,
                previous.minute,
                previous.second,
                previous.millisecond,
                previous.microsecond));
        _tasks[_tasks.indexWhere((item) => item.id == task.id)] = task;
      } else {
        if (task.recurrence.isRecurring || _recurringParentOf(task) != null) {
          final key = _occurrenceKey(logicalDate());
          if (!task.recurrenceCompletions.containsKey(key)) {
            _setRecurringOccurrenceCompleted(task.id, key, completed: true);
          }
        } else if (task.status != TaskStatus.completed) {
          final completedAt = DateTime.now();
          _tasks[_tasks.indexWhere((item) => item.id == task.id)] = task
              .copyWith(status: TaskStatus.completed, completedAt: completedAt);
          _setSubtasksCompletion(task.id, true, completedAt);
        }
        task = taskById(task.id)!;
      }
    }
    return _finishAgentOperation(requestId, fingerprint, {
      name == 'create_task' ? 'created' : 'task': _agentTask(task),
    });
  }

  Future<Map<String, dynamic>> _finishAgentOperation(String requestId,
      String fingerprint, Map<String, dynamic> payload) async {
    final result = <String, dynamic>{
      ...payload,
      'request_id': requestId,
      'savedLocally': true,
      'source': 'app',
    };
    _agentOperationReceipts[requestId] = {
      'fingerprint': fingerprint,
      'result': result
    };
    _commit();
    await _saveAgentChanges();
    return jsonDecode(jsonEncode(result)) as Map<String, dynamic>;
  }

  Future<void> _saveAgentChanges() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    // La confirmación requiere el snapshot completo, incluida la operación.
    // Si falla, el reintento vuelve a guardarlo sin aplicar de nuevo el cambio.
    await _saveSnapshotTracked(_buildSnapshot());
    _syncMetadata = _syncMetadata.copyWith(pendingLocalChanges: true);
    await _store.saveSyncMetadata(_syncMetadata);
    _lastSavedAt = DateTime.now();
    _notifyAgentChange();
    if (!_isFlutterTest) {
      unawaited(rescheduleTaskReminders());
    }
  }

  bool _agentMatchesDate(TaskModel task, DateTime day,
      {required bool overdue}) {
    if (task.recurrence.isRecurring) {
      final key = _occurrenceKey(day);
      if (task.status == TaskStatus.active &&
          (task.recurrenceCompletions.containsKey(key) ||
              task.skippedRecurrenceOccurrences.contains(key))) {
        return false;
      }
      if (!_sameDay(day, logicalDate()) &&
          task.recurrence.type == RecurrenceType.daily) {
        return false;
      }
      return _recursOnDay(task, day);
    }
    final scheduled = task.scheduledAt;
    return scheduled == null ||
        _sameDay(scheduled, day) ||
        (overdue &&
            task.status == TaskStatus.active &&
            scheduled.isBefore(day));
  }
}
