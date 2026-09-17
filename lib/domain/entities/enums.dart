enum AppSection {
  today,
  projects,
  categories,
  expenses,
  calendar,
  library,
  wardrobe,
  household,
  recipes,
  inbox,
  completed,
  settings,
}

enum WardrobeLaundryStatus { available, toWash, washing, drying }

enum WardrobeWeather { hot, mild, cold, rain }

enum WardrobeImportStatus { pending, approved, discarded, error }

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

enum ReminderDeliveryMode { normal, important }

enum FixedPaymentFrequency { weekly, monthly, yearly, custom }

enum LibraryItemType { game, book, movieSeries }

enum LibraryMediaType { movie, series }

enum LibraryItemStatus { pending, inProgress, completed }

enum LibraryAreaView { library, goals }

enum LibraryGoalStatus { pending, completed }

enum LibrarySortOrder {
  newestFirst,
  oldestFirst,
  titleAsc,
  titleDesc,
  highestRating,
  releaseYearDesc,
  releaseYearAsc,
  creatorAsc,
  genreAsc,
  platformAsc,
  formatAsc,
  pagesDesc,
  pagesAsc,
  durationDesc,
  durationAsc,
  countryAsc,
}
