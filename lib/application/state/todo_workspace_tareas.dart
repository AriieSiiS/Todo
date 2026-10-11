part of 'todo_workspace.dart';

extension TodoWorkspaceTareas on TodoWorkspace {
  List<TaskModel> tasksForToday() => _sortTasks(_tasksForDay(logicalDate()));

  List<TaskModel> tasksForDate(DateTime day) => _sortTasks(_tasksForDay(day));

  bool canSkipTaskOccurrence(TaskModel task) {
    final recurringTask =
        task.recurrence.isRecurring ? task : _recurringParentOf(task);
    return recurringTask?.canSkipOccurrence ?? false;
  }

  bool isTaskCompletedOnDay(TaskModel task, DateTime day) {
    if (task.recurrence.isRecurring || _recurringParentOf(task) != null) {
      return task.recurrenceCompletions.containsKey(_occurrenceKey(day));
    }
    return task.status == TaskStatus.completed;
  }

  List<TaskModel> tasksForWeek([DateTime? anchor]) {
    final start = logicalDate(anchor);
    final dates =
        List<DateTime>.generate(7, (index) => start.add(Duration(days: index)));
    final seen = <String>{};
    return dates
        .expand(_tasksForDay)
        .where((task) => seen.add(task.id))
        .toList()
      ..sort((left, right) =>
          (left.scheduledAt ?? start).compareTo(right.scheduledAt ?? start));
  }

  List<TaskModel> tasksByCategory(String categoryId) {
    return _tasks
        .where((task) => task.categoryIds.contains(categoryId))
        .where((task) => task.status != TaskStatus.archived)
        .toList()
      ..sort((left, right) => left.manualOrder.compareTo(right.manualOrder));
  }

  List<TaskModel> completedTasks() {
    final completed = <TaskModel>[
      ..._tasks.where(
          (task) => task.status == TaskStatus.completed && !task.isSubtask),
      ..._tasks
          .where((task) => task.recurrence.isRecurring && !task.isSubtask)
          .expand(_completedRecurringOccurrences),
    ];
    return completed
      ..sort(
        (left, right) => (right.completedAt ??
                right.scheduledAt ??
                DateTime(1970))
            .compareTo(left.completedAt ?? left.scheduledAt ?? DateTime(1970)),
      );
  }

  List<QuickNote> inboxNotes() {
    return _notes.where((note) => note.status == NoteStatus.inbox).toList();
  }

  CategoryModel? categoryById(String id) {
    for (final category in _categories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }

  ProjectModel? projectById(String id) {
    for (final project in _projects) {
      if (project.id == id) {
        return project;
      }
    }
    return null;
  }

  TaskModel? taskById(String id) {
    for (final task in _tasks) {
      if (task.id == id) {
        return task;
      }
    }
    return null;
  }

  QuickNote? noteById(String id) {
    for (final note in _notes) {
      if (note.id == id) {
        return note;
      }
    }
    return null;
  }

  List<TaskModel> subtasksOf(TaskModel task) {
    return _tasks.where((item) => item.parentTaskId == task.id).toList()
      ..sort((left, right) => left.manualOrder.compareTo(right.manualOrder));
  }

  CategoryModel _ensureTaskCategory(
    String name,
    Color color,
    IconData icon,
  ) {
    for (final category in _categories) {
      if (category.name.toLowerCase() == name.toLowerCase()) return category;
    }
    return createCategory(
      name: name,
      description: 'Creada automáticamente desde Recetas.',
      colorValue: color.toARGB32(),
      icon: icon,
    );
  }

  TaskModel createTask({
    required String title,
    String? description,
    List<String> categoryIds = const <String>[],
    List<String> projectIds = const <String>[],
    DateTime? scheduledAt,
    TaskPriority priority = TaskPriority.medium,
    RecurrenceRule recurrence = const RecurrenceRule(),
    TaskOrigin origin = TaskOrigin.manual,
    String? parentTaskId,
    List<ReminderRule> reminderRules = const <ReminderRule>[],
    CalendarLink? calendarLink,
    String? sourcePlantId,
    String? sourcePlantCareRoutineId,
  }) {
    final task = TaskModel(
      id: _id('task'),
      title: title.trim(),
      description:
          description?.trim().isEmpty == true ? null : description?.trim(),
      categoryIds: List<String>.from(categoryIds),
      projectIds: List<String>.from(projectIds),
      scheduledAt: scheduledAt,
      priority: priority,
      recurrence: recurrence,
      origin: origin,
      manualOrder: _nextManualOrder(parentTaskId: parentTaskId),
      parentTaskId: parentTaskId,
      reminderRules: List<ReminderRule>.from(reminderRules),
      calendarLink: calendarLink,
      sourcePlantId: sourcePlantId,
      sourcePlantCareRoutineId: sourcePlantCareRoutineId,
    );
    _tasks.add(task);
    if (parentTaskId != null) {
      final parentIndex = _tasks.indexWhere((item) => item.id == parentTaskId);
      if (parentIndex != -1) {
        final parent = _tasks[parentIndex];
        _tasks[parentIndex] = parent.copyWith(
          subtaskIds: <String>[...parent.subtaskIds, task.id],
        );
      }
    }
    _commit();
    return task;
  }

  void updateTask(TaskModel updated) {
    final index = _tasks.indexWhere((task) => task.id == updated.id);
    if (index == -1) {
      return;
    }
    _tasks[index] = updated;
    _commit();
  }

  void deleteTask(String taskId) {
    _tasks.removeWhere(
        (task) => task.id == taskId || task.parentTaskId == taskId);
    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (task.subtaskIds.contains(taskId)) {
        _tasks[i] = task.copyWith(
          subtaskIds: task.subtaskIds.where((id) => id != taskId).toList(),
        );
      }
    }
    _commit();
  }

  void deleteTasks(Iterable<String> taskIds) {
    final ids = taskIds.toSet();
    if (ids.isEmpty) {
      return;
    }
    _tasks.removeWhere(
      (task) => ids.contains(task.id) || ids.contains(task.parentTaskId),
    );
    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      final filtered =
          task.subtaskIds.where((id) => !ids.contains(id)).toList();
      if (filtered.length != task.subtaskIds.length) {
        _tasks[i] = task.copyWith(subtaskIds: filtered);
      }
    }
    _commit();
  }

  Future<void> completeTask(String taskId) async {
    final occurrence = _parseRecurringOccurrenceId(taskId);
    if (occurrence != null) {
      _setRecurringOccurrenceCompleted(
        occurrence.taskId,
        occurrence.key,
        completed: false,
      );
      _commit();
      return;
    }
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    final task = _tasks[index];
    final recurringParent = _recurringParentOf(task);
    if (task.recurrence.isRecurring || recurringParent != null) {
      final key = _occurrenceKey(logicalDate());
      final targetId = task.id;
      final isCompleted = task.recurrenceCompletions.containsKey(key);
      _setRecurringOccurrenceCompleted(
        targetId,
        key,
        completed: !isCompleted,
      );
      if (!isCompleted) {
        unawaited(_feedback.playTaskCompleted());
      }
      _commit();
      return;
    }
    final willComplete = task.status != TaskStatus.completed;
    final completedAt = willComplete ? DateTime.now() : null;
    _tasks[index] = task.copyWith(
      status: willComplete ? TaskStatus.completed : TaskStatus.active,
      completedAt: completedAt,
      clearCompletedAt: !willComplete,
    );
    _setSubtasksCompletion(task.id, willComplete, completedAt);
    if (task.calendarLink != null && _calendarSettings.connected) {
      await syncTaskToCalendar(taskId, silent: true);
    }
    if (willComplete) {
      unawaited(_feedback.playTaskCompleted());
    }
    _commit();
  }

  void skipTaskOccurrence(String taskId, {DateTime? day}) {
    final occurrence = _parseRecurringOccurrenceId(taskId);
    final source = taskById(occurrence?.taskId ?? taskId);
    if (source == null) return;

    final recurringTask =
        source.recurrence.isRecurring ? source : _recurringParentOf(source);
    if (recurringTask == null || !recurringTask.canSkipOccurrence) return;

    final targetDay = occurrence == null
        ? logicalDate(day)
        : DateTime.tryParse(occurrence.key) ?? logicalDate(day);
    if (!_recursOnDay(recurringTask, targetDay)) return;

    final key = _occurrenceKey(targetDay);
    if (recurringTask.recurrenceCompletions.containsKey(key) ||
        recurringTask.skippedRecurrenceOccurrences.contains(key)) {
      return;
    }

    final skipped = Set<String>.from(
      recurringTask.skippedRecurrenceOccurrences,
    )..add(key);
    final index = _tasks.indexWhere((task) => task.id == recurringTask.id);
    if (index == -1) return;
    _tasks[index] = recurringTask.copyWith(
      skippedRecurrenceOccurrences: skipped,
    );
    _commit();
  }

  void reopenTask(String taskId) {
    final occurrence = _parseRecurringOccurrenceId(taskId);
    if (occurrence != null) {
      _setRecurringOccurrenceCompleted(
        occurrence.taskId,
        occurrence.key,
        completed: false,
      );
      _commit();
      return;
    }
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    _tasks[index] = _tasks[index].copyWith(
      status: TaskStatus.active,
      clearCompletedAt: true,
    );
    _setSubtasksCompletion(taskId, false, null);
    _commit();
  }

  void reopenTasks(Iterable<String> taskIds) {
    final ids = taskIds.toSet();
    if (ids.isEmpty) {
      return;
    }
    var changed = false;
    for (final id in ids) {
      final occurrence = _parseRecurringOccurrenceId(id);
      if (occurrence != null) {
        _setRecurringOccurrenceCompleted(
          occurrence.taskId,
          occurrence.key,
          completed: false,
        );
        changed = true;
      }
    }
    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (!ids.contains(task.id) || task.status != TaskStatus.completed) {
        continue;
      }
      _tasks[i] = task.copyWith(
        status: TaskStatus.active,
        clearCompletedAt: true,
      );
      _setSubtasksCompletion(task.id, false, null);
      changed = true;
    }
    if (changed) {
      _commit();
    }
  }

  TaskModel createSubtask(String parentTaskId, String title) {
    return createTask(
      title: title,
      parentTaskId: parentTaskId,
      origin: TaskOrigin.manual,
      scheduledAt: taskById(parentTaskId)?.scheduledAt,
    );
  }

  void replaceTaskSubtasks(String parentTaskId, Iterable<String> titles) {
    final parentIndex = _tasks.indexWhere((task) => task.id == parentTaskId);
    if (parentIndex == -1) return;

    final normalizedTitles = titles
        .map((title) => title.trim())
        .where((title) => title.isNotEmpty)
        .toList();
    final parent = _tasks[parentIndex];
    final existing = subtasksOf(parent);
    final retainedIds = <String>[];

    for (var index = 0; index < normalizedTitles.length; index++) {
      if (index < existing.length) {
        final subtask = existing[index];
        final updated = subtask.copyWith(
          title: normalizedTitles[index],
          scheduledAt: parent.scheduledAt,
          clearScheduledAt: parent.scheduledAt == null,
        );
        final taskIndex = _tasks.indexWhere((task) => task.id == subtask.id);
        if (taskIndex != -1) _tasks[taskIndex] = updated;
        retainedIds.add(subtask.id);
        continue;
      }

      final subtask = TaskModel(
        id: _id('task'),
        title: normalizedTitles[index],
        scheduledAt: parent.scheduledAt,
        origin: TaskOrigin.manual,
        manualOrder: _nextManualOrder(parentTaskId: parentTaskId),
        parentTaskId: parentTaskId,
      );
      _tasks.add(subtask);
      retainedIds.add(subtask.id);
    }

    final removedIds = existing
        .skip(normalizedTitles.length)
        .map((subtask) => subtask.id)
        .toSet();
    _tasks.removeWhere(
      (task) =>
          removedIds.contains(task.id) ||
          (task.parentTaskId != null && removedIds.contains(task.parentTaskId)),
    );

    final refreshedParentIndex =
        _tasks.indexWhere((task) => task.id == parentTaskId);
    if (refreshedParentIndex != -1) {
      _tasks[refreshedParentIndex] = _tasks[refreshedParentIndex].copyWith(
        checklist: const <String>[],
        subtaskIds: retainedIds,
      );
    }
    _commit();
  }

  void _setSubtasksCompletion(
    String parentTaskId,
    bool completed,
    DateTime? completedAt,
  ) {
    for (var i = 0; i < _tasks.length; i++) {
      final subtask = _tasks[i];
      if (subtask.parentTaskId != parentTaskId) {
        continue;
      }
      _tasks[i] = subtask.copyWith(
        status: completed ? TaskStatus.completed : TaskStatus.active,
        completedAt: completedAt,
        clearCompletedAt: !completed,
      );
    }
  }

  Future<void> moveTaskToDay(String taskId, DateTime date) async {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    final source = _tasks[index];
    final current = source.scheduledAt ?? logicalDate();
    _tasks[index] = source.copyWith(
      scheduledAt: DateTime(
          date.year, date.month, date.day, current.hour, current.minute),
      calendarLink:
          source.calendarLink?.copyWith(syncStatus: CalendarSyncStatus.pending),
    );
    _commit();
    if (_tasks[index].calendarLink != null && _calendarSettings.connected) {
      await syncTaskToCalendar(taskId, silent: true);
    }
  }

  Future<void> moveTasksToDay(Iterable<String> taskIds, DateTime date) async {
    final ids = taskIds.toSet();
    if (ids.isEmpty) {
      return;
    }
    final tasksToSync = <String>[];
    for (var i = 0; i < _tasks.length; i++) {
      final source = _tasks[i];
      if (!ids.contains(source.id)) {
        continue;
      }
      final current = source.scheduledAt ?? logicalDate();
      _tasks[i] = source.copyWith(
        scheduledAt: DateTime(
            date.year, date.month, date.day, current.hour, current.minute),
        calendarLink: source.calendarLink
            ?.copyWith(syncStatus: CalendarSyncStatus.pending),
      );
      if (_tasks[i].calendarLink != null && _calendarSettings.connected) {
        tasksToSync.add(source.id);
      }
    }
    _commit();
    for (final id in tasksToSync) {
      await syncTaskToCalendar(id, silent: true);
    }
  }

  Future<void> completeTasks(Iterable<String> taskIds) async {
    final ids = taskIds.toSet();
    if (ids.isEmpty) {
      return;
    }
    final tasksToSync = <String>[];
    final spawnedTasks = <TaskModel>[];
    var changed = false;
    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (!ids.contains(task.id) || task.status == TaskStatus.completed) {
        continue;
      }
      final recurringParent = _recurringParentOf(task);
      if (task.recurrence.isRecurring || recurringParent != null) {
        final key = _occurrenceKey(logicalDate());
        _setRecurringOccurrenceCompleted(
          task.id,
          key,
          completed: true,
        );
        changed = true;
        continue;
      }
      _tasks[i] = task.copyWith(
        status: TaskStatus.completed,
        completedAt: DateTime.now(),
      );
      _setSubtasksCompletion(task.id, true, _tasks[i].completedAt);
      changed = true;
      if (task.calendarLink != null && _calendarSettings.connected) {
        tasksToSync.add(task.id);
      }
    }
    if (spawnedTasks.isNotEmpty) {
      _tasks.addAll(spawnedTasks);
      changed = true;
    }
    if (!changed) {
      return;
    }
    unawaited(_feedback.playTaskCompleted());
    _commit();
    for (final id in tasksToSync) {
      await syncTaskToCalendar(id, silent: true);
    }
  }

  void changePriority(String taskId, TaskPriority priority) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    _tasks[index] = _tasks[index].copyWith(priority: priority);
    _commit();
  }

  void changeManualOrder(List<String> orderedIds) {
    for (var i = 0; i < orderedIds.length; i++) {
      final index = _tasks.indexWhere((task) => task.id == orderedIds[i]);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(manualOrder: i.toDouble());
      }
    }
    _commit();
  }

  void changeCategory(String taskId, List<String> categoryIds) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    _tasks[index] = _tasks[index].copyWith(categoryIds: categoryIds);
    _commit();
  }

  void changeProject(String taskId, List<String> projectIds) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    _tasks[index] = _tasks[index].copyWith(projectIds: projectIds);
    _commit();
  }

  ProjectModel createProject({
    required String name,
    String description = '',
    required int colorValue,
    required IconData icon,
    List<String> categoryIds = const <String>[],
  }) {
    final project = ProjectModel(
      id: _id('project'),
      name: name.trim(),
      description: description.trim(),
      colorValue: colorValue,
      icon: icon,
      categoryIds: List<String>.from(categoryIds),
    );
    _projects.add(project);
    _commit();
    return project;
  }

  void updateProject(ProjectModel updated) {
    final index = _projects.indexWhere((project) => project.id == updated.id);
    if (index == -1) {
      return;
    }
    _projects[index] = updated;
    _commit();
  }

  void setProjectStatus(String projectId, ProjectStatus status) {
    final index = _projects.indexWhere((project) => project.id == projectId);
    if (index == -1) {
      return;
    }
    _projects[index] = _projects[index].copyWith(status: status);
    _commit();
  }

  void completeProject(String projectId) {
    setProjectStatus(projectId, ProjectStatus.completed);
    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (task.projectIds.contains(projectId) &&
          task.status == TaskStatus.active) {
        _tasks[i] = task.copyWith(
          status: TaskStatus.completed,
          completedAt: DateTime.now(),
        );
      }
    }
    _commit();
  }

  void cancelProject(String projectId) {
    setProjectStatus(projectId, ProjectStatus.cancelled);
  }

  CategoryModel createCategory({
    required String name,
    String description = '',
    required int colorValue,
    required IconData icon,
  }) {
    final category = CategoryModel(
      id: _id('category'),
      name: name.trim(),
      description: description.trim(),
      colorValue: colorValue,
      icon: icon,
    );
    _categories.add(category);
    _commit();
    return category;
  }

  void updateCategory(CategoryModel updated) {
    final index =
        _categories.indexWhere((category) => category.id == updated.id);
    if (index == -1) {
      return;
    }
    _categories[index] = updated;
    _commit();
  }

  void reorderNotes(List<String> orderedIds) {
    final byId = {for (final note in _notes) note.id: note};
    final ids = orderedIds.where(byId.containsKey).toSet().toList();
    final included = ids.toSet();
    var index = 0;
    final ordered = _notes
        .map((note) => included.contains(note.id) ? byId[ids[index++]]! : note)
        .toList();
    if (List.generate(ordered.length, (i) => ordered[i].id == _notes[i].id)
        .every((same) => same)) {
      return;
    }
    _notes
      ..clear()
      ..addAll(ordered);
    _commit();
  }

  void reorderCategories(List<String> orderedIds) {
    final byId = {for (final category in _categories) category.id: category};
    final ids = orderedIds.where(byId.containsKey).toSet().toList();
    final included = ids.toSet();
    var index = 0;
    final ordered = _categories
        .map((category) =>
            included.contains(category.id) ? byId[ids[index++]]! : category)
        .toList();
    if (List.generate(ordered.length, (i) => ordered[i].id == _categories[i].id)
        .every((same) => same)) {
      return;
    }
    _categories
      ..clear()
      ..addAll(ordered);
    _commit();
  }

  void toggleCategory(String categoryId) {
    final index =
        _categories.indexWhere((category) => category.id == categoryId);
    if (index == -1) {
      return;
    }
    final category = _categories[index];
    _categories[index] = category.copyWith(active: !category.active);
    _commit();
  }

  void deleteCategory(String categoryId) {
    final index =
        _categories.indexWhere((category) => category.id == categoryId);
    if (index == -1) {
      return;
    }
    _categories.removeAt(index);
    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (task.categoryIds.contains(categoryId)) {
        _tasks[i] = task.copyWith(
          categoryIds:
              task.categoryIds.where((id) => id != categoryId).toList(),
        );
      }
    }
    for (var i = 0; i < _projects.length; i++) {
      final project = _projects[i];
      if (project.categoryIds.contains(categoryId)) {
        _projects[i] = project.copyWith(
          categoryIds:
              project.categoryIds.where((id) => id != categoryId).toList(),
        );
      }
    }
    for (var i = 0; i < _notes.length; i++) {
      final note = _notes[i];
      if (note.categoryIds.contains(categoryId)) {
        _notes[i] = note.copyWith(
          categoryIds:
              note.categoryIds.where((id) => id != categoryId).toList(),
          updatedAt: now,
        );
      }
    }
    _commit();
  }

  QuickNote createNote(
    String content, {
    DateTime? scheduledFor,
    String emoji = '',
    int? colorValue,
    bool isPinned = false,
    List<String> categoryIds = const <String>[],
  }) {
    final note = QuickNote(
      id: _id('note'),
      content: content.trim(),
      createdAt: now,
      scheduledFor: scheduledFor,
      emoji: emoji,
      colorValue: colorValue,
      isPinned: isPinned,
      updatedAt: now,
      categoryIds: List<String>.from(categoryIds),
    );
    _notes.insert(0, note);
    _commit();
    return note;
  }

  void updateNote(
    String noteId, {
    required String content,
    DateTime? scheduledFor,
    String? emoji,
    int? colorValue,
    bool clearColor = false,
    bool? isPinned,
    List<String>? categoryIds,
  }) {
    final index = _notes.indexWhere((note) => note.id == noteId);
    if (index == -1) {
      return;
    }
    _notes[index] = _notes[index].copyWith(
      content: content.trim(),
      scheduledFor: scheduledFor,
      clearScheduledFor: scheduledFor == null,
      emoji: emoji,
      colorValue: colorValue,
      clearColor: clearColor,
      isPinned: isPinned,
      updatedAt: now,
      categoryIds: categoryIds == null ? null : List<String>.from(categoryIds),
    );
    _commit();
  }

  void toggleNotePinned(String noteId) {
    final index = _notes.indexWhere((note) => note.id == noteId);
    if (index == -1) return;
    final note = _notes[index];
    _notes[index] = note.copyWith(
      isPinned: !note.isPinned,
      updatedAt: now,
    );
    _commit();
  }

  TaskModel convertNoteToTask(String noteId, {DateTime? scheduledAt}) {
    final note = _notes.firstWhere((item) => item.id == noteId);
    final task = createTask(
      title: _noteTitle(note),
      description: _noteDescription(note),
      origin: TaskOrigin.note,
      scheduledAt: scheduledAt ?? note.scheduledFor ?? _defaultNoteDate(),
      reminderRules: <ReminderRule>[
        ReminderRule(
          enabled: true,
          minutesBefore: _notificationSettings.defaultMinutesBeforeTask,
        ),
      ],
    );
    return task;
  }

  ProjectModel convertNoteToProject(String noteId) {
    final note = _notes.firstWhere((item) => item.id == noteId);
    final project = createProject(
      name: _noteTitle(note),
      description: _noteDescription(note) ?? '',
      colorValue: const Color(0xFF607A5A).toARGB32(),
      icon: Icons.folder_open_rounded,
    );
    return project;
  }

  void archiveNote(String noteId) {
    final index = _notes.indexWhere((note) => note.id == noteId);
    if (index == -1) {
      return;
    }
    _notes[index] = _notes[index].copyWith(status: NoteStatus.archived);
    _commit();
  }

  void restoreNote(String noteId) {
    final index = _notes.indexWhere((note) => note.id == noteId);
    if (index == -1) return;
    _notes[index] = _notes[index].copyWith(status: NoteStatus.inbox);
    _commit();
  }

  void deleteNote(String noteId) {
    _notes.removeWhere((note) => note.id == noteId);
    _commit();
  }

  void reorganizeDay() {
    final today = tasksForToday();
    final urgent = today
        .where((task) => task.priority == TaskPriority.urgent)
        .map((task) => task.id);
    final high = today
        .where((task) => task.priority == TaskPriority.high)
        .map((task) => task.id);
    final rest = today
        .where((task) =>
            task.priority != TaskPriority.urgent &&
            task.priority != TaskPriority.high)
        .map((task) => task.id);
    changeManualOrder(<String>[...urgent, ...high, ...rest]);
  }

  void reorganizeWeek() {
    final week = tasksForWeek();
    for (final task in week) {
      if (task.priority == TaskPriority.low && task.scheduledAt != null) {
        final index = _tasks.indexWhere((item) => item.id == task.id);
        if (index != -1) {
          _tasks[index] = _tasks[index].copyWith(
            scheduledAt: task.scheduledAt!.add(const Duration(days: 1)),
          );
        }
      }
    }
    _commit();
  }

  void toggleTaskCollapse(String taskId) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    _tasks[index] = _tasks[index].copyWith(collapsed: !_tasks[index].collapsed);
    _commit();
  }

  bool _migrateLegacyChecklistsToSubtasks() {
    final parents = _tasks.where((task) => task.checklist.isNotEmpty).toList();
    if (parents.isEmpty) return false;

    final migratedSubtasks = <TaskModel>[];
    for (final parent in parents) {
      final existing =
          _tasks.where((task) => task.parentTaskId == parent.id).toList()
            ..sort(
              (left, right) => left.manualOrder.compareTo(right.manualOrder),
            );
      final existingTitles =
          existing.map((task) => task.title.trim().toLowerCase()).toSet();
      final subtaskIds = existing.map((task) => task.id).toList();
      var manualOrder = existing.isEmpty
          ? 0.0
          : existing.map((task) => task.manualOrder).reduce(max) + 1;

      for (final rawTitle in parent.checklist) {
        final title = rawTitle.trim();
        if (title.isEmpty || existingTitles.contains(title.toLowerCase())) {
          continue;
        }
        final subtask = TaskModel(
          id: _id('task'),
          title: title,
          scheduledAt: parent.scheduledAt,
          origin: TaskOrigin.manual,
          manualOrder: manualOrder++,
          parentTaskId: parent.id,
        );
        migratedSubtasks.add(subtask);
        subtaskIds.add(subtask.id);
        existingTitles.add(title.toLowerCase());
      }

      final parentIndex = _tasks.indexWhere((task) => task.id == parent.id);
      if (parentIndex != -1) {
        _tasks[parentIndex] = parent.copyWith(
          checklist: const <String>[],
          subtaskIds: subtaskIds,
        );
      }
    }
    _tasks.addAll(migratedSubtasks);
    return true;
  }

  List<TaskModel> _tasksForDay(DateTime day) {
    final logicalToday = logicalDate();
    final occurrenceKey = _occurrenceKey(day);
    final isToday = _sameDay(day, logicalToday);
    return _tasks
        .where((task) => task.status == TaskStatus.active)
        .where((task) => !task.isSubtask)
        .where((task) {
      if (task.recurrence.isRecurring &&
          (task.recurrenceCompletions.containsKey(occurrenceKey) ||
              task.skippedRecurrenceOccurrences.contains(occurrenceKey))) {
        return false;
      }
      if (task.recurrence.isRecurring) {
        if (!isToday && task.recurrence.type == RecurrenceType.daily) {
          return false;
        }
        return _recursOnDay(task, day);
      }
      final scheduled = task.scheduledAt;
      if (scheduled == null) {
        return true;
      }
      if (isToday && scheduled.isBefore(logicalToday)) {
        return true;
      }
      return _sameDay(scheduled, day);
    }).toList();
  }

  List<TaskModel> _sortTasks(List<TaskModel> list) {
    final sorted = List<TaskModel>.from(list);
    switch (_todaySort) {
      case TodaySort.manual:
        sorted.sort(
            (left, right) => left.manualOrder.compareTo(right.manualOrder));
        break;
      case TodaySort.category:
        final names = <String, String>{};
        for (final category in _categories) {
          names.putIfAbsent(category.id, () => category.name);
        }
        String label(TaskModel task) => task.categoryIds.isEmpty
            ? 'zzz'
            : names[task.categoryIds.first] ?? 'zzz';
        sorted.sort((left, right) => label(left).compareTo(label(right)));
        break;
      case TodaySort.time:
        sorted.sort(
          (left, right) => (left.scheduledAt ?? logicalDate())
              .compareTo(right.scheduledAt ?? logicalDate()),
        );
        break;
      case TodaySort.project:
        final names = <String, String>{};
        for (final project in _projects) {
          names.putIfAbsent(project.id, () => project.name);
        }
        String label(TaskModel task) => task.projectIds.isEmpty
            ? 'zzz'
            : names[task.projectIds.first] ?? 'zzz';
        sorted.sort((left, right) => label(left).compareTo(label(right)));
        break;
      case TodaySort.priority:
        sorted.sort((left, right) =>
            right.priority.index.compareTo(left.priority.index));
        break;
    }
    return sorted;
  }

  DateTime _defaultNoteDate() {
    final day = logicalDate();
    return DateTime(day.year, day.month, day.day, 10);
  }

  String _noteTitle(QuickNote note) {
    final lines = note.content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return 'Nota';
    }
    return lines.first;
  }

  String? _noteDescription(QuickNote note) {
    final lines = note.content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length <= 1) {
      return null;
    }
    return lines.skip(1).join('\n');
  }
}
