import 'dart:convert';

import '../entities/category.dart';
import '../entities/calendar_models.dart';
import '../entities/enums.dart';
import '../entities/financial.dart';
import '../entities/household.dart';
import '../entities/json_helpers.dart';
import '../entities/library_goal.dart';
import '../entities/library_item.dart';
import '../entities/project.dart';
import '../entities/quick_note.dart';
import '../entities/recipe.dart';
import '../entities/settings.dart';
import '../entities/task.dart';
import '../entities/wardrobe.dart';

class AppStateSnapshot {
  const AppStateSnapshot({
    required this.tasks,
    required this.categories,
    required this.projects,
    required this.notes,
    this.expenses = const <Expense>[],
    this.expenseCategories = const <ExpenseCategory>[],
    this.paymentMethods = const <PaymentMethodModel>[],
    this.fixedPayments = const <FixedPayment>[],
    this.libraryItems = const <LibraryItem>[],
    this.libraryGoals = const <LibraryGoal>[],
    this.libraryStatusView = LibraryItemStatus.completed,
    this.wardrobeItems = const <WardrobeItem>[],
    this.wardrobeOutfits = const <WardrobeOutfit>[],
    this.wardrobeWearLogs = const <WardrobeWearLog>[],
    this.wardrobePlanEntries = const <WardrobePlanEntry>[],
    this.wardrobePackingLists = const <WardrobePackingList>[],
    this.wardrobeImportBatches = const <WardrobeImportBatch>[],
    this.householdItems = const <HouseholdItem>[],
    this.recipes = const <Recipe>[],
    this.weeklyMenus = const <WeeklyMenu>[],
    required this.daySettings,
    this.wardrobeDisplaySettings = const WardrobeDisplaySettings(),
    required this.notificationSettings,
    required this.calendarSettings,
    required this.section,
    required this.todaySort,
    this.navOrder = const <AppSection>[],
    this.calendarEvents = const <CalendarEventModel>[],
    this.visualMode = AppVisualMode.classic,
    this.manualLogicalDate,
    this.manualLogicalDateStartedAt,
    this.updatedAt,
    this.schemaVersion = 1,
    this.lastModifiedBy = '',
  });

  final List<TaskModel> tasks;
  final List<CategoryModel> categories;
  final List<ProjectModel> projects;
  final List<QuickNote> notes;
  final List<Expense> expenses;
  final List<ExpenseCategory> expenseCategories;
  final List<PaymentMethodModel> paymentMethods;
  final List<FixedPayment> fixedPayments;
  final List<LibraryItem> libraryItems;
  final List<LibraryGoal> libraryGoals;
  final LibraryItemStatus libraryStatusView;
  final List<WardrobeItem> wardrobeItems;
  final List<WardrobeOutfit> wardrobeOutfits;
  final List<WardrobeWearLog> wardrobeWearLogs;
  final List<WardrobePlanEntry> wardrobePlanEntries;
  final List<WardrobePackingList> wardrobePackingLists;
  final List<WardrobeImportBatch> wardrobeImportBatches;
  final List<HouseholdItem> householdItems;
  final List<Recipe> recipes;
  final List<WeeklyMenu> weeklyMenus;
  final List<CalendarEventModel> calendarEvents;
  final DaySettings daySettings;
  final WardrobeDisplaySettings wardrobeDisplaySettings;
  final DeviceNotificationSettings notificationSettings;
  final CalendarIntegrationSettings calendarSettings;
  final AppSection section;
  final TodaySort todaySort;
  final List<AppSection> navOrder;
  final AppVisualMode visualMode;
  final DateTime? manualLogicalDate;
  final DateTime? manualLogicalDateStartedAt;
  final DateTime? updatedAt;
  final int schemaVersion;
  final String lastModifiedBy;

  DateTime get resolvedUpdatedAt =>
      updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tasks': tasks.map((task) => task.toJson()).toList(),
      'categories': categories.map((category) => category.toJson()).toList(),
      'projects': projects.map((project) => project.toJson()).toList(),
      'notes': notes.map((note) => note.toJson()).toList(),
      'expenses': expenses.map((expense) => expense.toJson()).toList(),
      'expenseCategories':
          expenseCategories.map((category) => category.toJson()).toList(),
      'paymentMethods':
          paymentMethods.map((method) => method.toJson()).toList(),
      'fixedPayments':
          fixedPayments.map((payment) => payment.toJson()).toList(),
      'libraryItems': libraryItems.map((item) => item.toJson()).toList(),
      'libraryGoals': libraryGoals.map((goal) => goal.toJson()).toList(),
      'libraryStatusView': libraryStatusView.name,
      'wardrobeItems': wardrobeItems.map((item) => item.toJson()).toList(),
      'wardrobeOutfits': wardrobeOutfits.map((item) => item.toJson()).toList(),
      'wardrobeWearLogs':
          wardrobeWearLogs.map((item) => item.toJson()).toList(),
      'wardrobePlanEntries':
          wardrobePlanEntries.map((item) => item.toJson()).toList(),
      'wardrobePackingLists':
          wardrobePackingLists.map((item) => item.toJson()).toList(),
      'wardrobeImportBatches':
          wardrobeImportBatches.map((item) => item.toJson()).toList(),
      'householdItems': householdItems.map((item) => item.toJson()).toList(),
      'recipes': recipes.map((item) => item.toJson()).toList(),
      'weeklyMenus': weeklyMenus.map((item) => item.toJson()).toList(),
      'calendarEvents': calendarEvents.map((event) => event.toJson()).toList(),
      'daySettings': daySettings.toJson(),
      'wardrobeDisplaySettings': wardrobeDisplaySettings.toJson(),
      'notificationSettings': notificationSettings.toJson(),
      'calendarSettings': calendarSettings.toJson(),
      'section': section.name,
      'todaySort': todaySort.name,
      'navOrder': navOrder.map((section) => section.name).toList(),
      'visualMode': visualMode.name,
      'manualLogicalDate': manualLogicalDate?.toIso8601String(),
      'manualLogicalDateStartedAt':
          manualLogicalDateStartedAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'schemaVersion': schemaVersion,
      'lastModifiedBy': lastModifiedBy,
    };
  }

  String toEncodedJson() => jsonEncode(toJson());

  factory AppStateSnapshot.fromJson(Map<String, dynamic> json) {
    return AppStateSnapshot(
      tasks: (json['tasks'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => TaskModel.fromJson(
              (item as Map<dynamic, dynamic>).cast<String, dynamic>()))
          .toList(),
      categories: (json['categories'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => CategoryModel.fromJson(
              (item as Map<dynamic, dynamic>).cast<String, dynamic>()))
          .toList(),
      projects: (json['projects'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => ProjectModel.fromJson(
              (item as Map<dynamic, dynamic>).cast<String, dynamic>()))
          .toList(),
      notes: (json['notes'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => QuickNote.fromJson(
              (item as Map<dynamic, dynamic>).cast<String, dynamic>()))
          .toList(),
      expenses: (json['expenses'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => Expense.fromJson(
              (item as Map<dynamic, dynamic>).cast<String, dynamic>()))
          .toList(),
      expenseCategories:
          (json['expenseCategories'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => ExpenseCategory.fromJson(
                  (item as Map<dynamic, dynamic>).cast<String, dynamic>()))
              .toList(),
      paymentMethods:
          (json['paymentMethods'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => PaymentMethodModel.fromJson(
                  (item as Map<dynamic, dynamic>).cast<String, dynamic>()))
              .toList(),
      fixedPayments:
          (json['fixedPayments'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => FixedPayment.fromJson(
                  (item as Map<dynamic, dynamic>).cast<String, dynamic>()))
              .toList(),
      libraryItems:
          (json['libraryItems'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => LibraryItem.fromJson(
                  (item as Map<dynamic, dynamic>).cast<String, dynamic>()))
              .toList(),
      libraryGoals:
          (json['libraryGoals'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => LibraryGoal.fromJson(
                  (item as Map<dynamic, dynamic>).cast<String, dynamic>()))
              .toList(),
      libraryStatusView: enumByName(
        LibraryItemStatus.values,
        json['libraryStatusView'] as String?,
        LibraryItemStatus.completed,
      ),
      wardrobeItems:
          (json['wardrobeItems'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => WardrobeItem.fromJson(
                  (item as Map<dynamic, dynamic>).cast<String, dynamic>()))
              .toList(),
      wardrobeOutfits:
          (json['wardrobeOutfits'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => WardrobeOutfit.fromJson(
                  (item as Map<dynamic, dynamic>).cast<String, dynamic>()))
              .toList(),
      wardrobeWearLogs:
          (json['wardrobeWearLogs'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => WardrobeWearLog.fromJson(
                  (item as Map<dynamic, dynamic>).cast<String, dynamic>()))
              .toList(),
      wardrobePlanEntries:
          (json['wardrobePlanEntries'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => WardrobePlanEntry.fromJson(
                  (item as Map<dynamic, dynamic>).cast<String, dynamic>()))
              .toList(),
      wardrobePackingLists:
          (json['wardrobePackingLists'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => WardrobePackingList.fromJson(
                  (item as Map<dynamic, dynamic>).cast<String, dynamic>()))
              .toList(),
      wardrobeImportBatches:
          (json['wardrobeImportBatches'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => WardrobeImportBatch.fromJson(
                  (item as Map<dynamic, dynamic>).cast<String, dynamic>()))
              .toList(),
      householdItems:
          (json['householdItems'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => HouseholdItem.fromJson(
                  (item as Map<dynamic, dynamic>).cast<String, dynamic>()))
              .toList(),
      recipes: (json['recipes'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => Recipe.fromJson(
              (item as Map<dynamic, dynamic>).cast<String, dynamic>()))
          .toList(),
      weeklyMenus: (json['weeklyMenus'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => WeeklyMenu.fromJson(
              (item as Map<dynamic, dynamic>).cast<String, dynamic>()))
          .toList(),
      calendarEvents:
          (json['calendarEvents'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => CalendarEventModel.fromJson(
                  (item as Map<dynamic, dynamic>).cast<String, dynamic>()))
              .toList(),
      daySettings: DaySettings.fromJson(
          (json['daySettings'] as Map<dynamic, dynamic>? ??
                  const <dynamic, dynamic>{})
              .cast<String, dynamic>()),
      wardrobeDisplaySettings: WardrobeDisplaySettings.fromJson(
        (json['wardrobeDisplaySettings'] as Map<dynamic, dynamic>? ??
                const <dynamic, dynamic>{})
            .cast<String, dynamic>(),
      ),
      notificationSettings: DeviceNotificationSettings.fromJson(
        (json['notificationSettings'] as Map<dynamic, dynamic>? ??
                const <dynamic, dynamic>{})
            .cast<String, dynamic>(),
      ),
      calendarSettings: CalendarIntegrationSettings.fromJson(
        (json['calendarSettings'] as Map<dynamic, dynamic>? ??
                const <dynamic, dynamic>{})
            .cast<String, dynamic>(),
      ),
      section: enumByName(
          AppSection.values, json['section'] as String?, AppSection.today),
      todaySort: enumByName(
          TodaySort.values, json['todaySort'] as String?, TodaySort.manual),
      navOrder: (json['navOrder'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) =>
              enumByName(AppSection.values, item as String?, AppSection.today))
          .toList(),
      visualMode: enumByName(AppVisualMode.values,
          json['visualMode'] as String?, AppVisualMode.classic),
      manualLogicalDate: json['manualLogicalDate'] == null
          ? null
          : DateTime.tryParse(json['manualLogicalDate'] as String),
      manualLogicalDateStartedAt: json['manualLogicalDateStartedAt'] == null
          ? null
          : DateTime.tryParse(json['manualLogicalDateStartedAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      lastModifiedBy: json['lastModifiedBy'] as String? ?? '',
    );
  }

  factory AppStateSnapshot.fromEncodedJson(String encoded) {
    return AppStateSnapshot.fromJson(
        (jsonDecode(encoded) as Map<dynamic, dynamic>).cast<String, dynamic>());
  }
}
