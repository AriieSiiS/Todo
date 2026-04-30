enum AppSection {
  today,
  projects,
  categories,
  calendar,
  inbox,
  completed,
  settings,
}

enum TaskStatus { active, completed, archived }

enum TaskPriority { low, medium, high, urgent }

enum ProjectStatus { active, paused, completed, cancelled }

enum NoteStatus { inbox, converted, archived }

enum TaskOrigin { manual, recurring, project, calendar, note }

enum RecurrenceType { none, daily, everyXDays, weekly, yearly }

enum TodaySort { manual, category, time, project, priority }

enum CalendarProvider { google }

enum CalendarSyncStatus { idle, synced, pending, error }

enum ReminderTriggerMode { minutesBefore, atTime }

enum AppVisualMode { classic, phantom }
