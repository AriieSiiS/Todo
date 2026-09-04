import 'dart:convert';

import '../entities/category.dart';
import '../entities/calendar_models.dart';
import '../entities/enums.dart';
import '../entities/financial.dart';
import '../entities/household.dart';
import '../entities/library_goal.dart';
import '../entities/library_item.dart';
import '../entities/project.dart';
import '../entities/quick_note.dart';
import '../entities/recipe.dart';
import '../entities/settings.dart';
import '../entities/task.dart';
import '../entities/wardrobe.dart';

class ExportSnapshot {
  const ExportSnapshot({
    required this.tasks,
    required this.categories,
    required this.projects,
    required this.notes,
    required this.expenses,
    required this.expenseCategories,
    required this.paymentMethods,
    required this.fixedPayments,
    required this.libraryItems,
    required this.libraryGoals,
    this.wardrobeItems = const <WardrobeItem>[],
    this.wardrobeOutfits = const <WardrobeOutfit>[],
    this.wardrobeWearLogs = const <WardrobeWearLog>[],
    this.wardrobePlanEntries = const <WardrobePlanEntry>[],
    this.wardrobePackingLists = const <WardrobePackingList>[],
    this.householdItems = const <HouseholdItem>[],
    this.recipes = const <Recipe>[],
    this.weeklyMenus = const <WeeklyMenu>[],
    required this.calendarEvents,
    required this.daySettings,
    this.wardrobeDisplaySettings = const WardrobeDisplaySettings(),
    required this.notificationSettings,
    required this.calendarSettings,
    this.visualMode = AppVisualMode.classic,
    this.navOrder = const <AppSection>[],
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
  final List<WardrobeItem> wardrobeItems;
  final List<WardrobeOutfit> wardrobeOutfits;
  final List<WardrobeWearLog> wardrobeWearLogs;
  final List<WardrobePlanEntry> wardrobePlanEntries;
  final List<WardrobePackingList> wardrobePackingLists;
  final List<HouseholdItem> householdItems;
  final List<Recipe> recipes;
  final List<WeeklyMenu> weeklyMenus;
  final List<CalendarEventModel> calendarEvents;
  final DaySettings daySettings;
  final WardrobeDisplaySettings wardrobeDisplaySettings;
  final DeviceNotificationSettings notificationSettings;
  final CalendarIntegrationSettings calendarSettings;
  final AppVisualMode visualMode;
  final List<AppSection> navOrder;

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
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
      'wardrobeItems': wardrobeItems.map((item) => item.toJson()).toList(),
      'wardrobeOutfits': wardrobeOutfits.map((item) => item.toJson()).toList(),
      'wardrobeWearLogs':
          wardrobeWearLogs.map((item) => item.toJson()).toList(),
      'wardrobePlanEntries':
          wardrobePlanEntries.map((item) => item.toJson()).toList(),
      'wardrobePackingLists':
          wardrobePackingLists.map((item) => item.toJson()).toList(),
      'householdItems': householdItems.map((item) => item.toJson()).toList(),
      'recipes': recipes.map((item) => item.toJson()).toList(),
      'weeklyMenus': weeklyMenus.map((item) => item.toJson()).toList(),
      'calendarEvents': calendarEvents.map((event) => event.toJson()).toList(),
      'daySettings': daySettings.toJson(),
      'wardrobeDisplaySettings': wardrobeDisplaySettings.toJson(),
      'notificationSettings': notificationSettings.toJson(),
      'calendarSettings': calendarSettings.toJson(),
      'visualMode': visualMode.name,
      'navOrder': navOrder.map((section) => section.name).toList(),
    });
  }
}
