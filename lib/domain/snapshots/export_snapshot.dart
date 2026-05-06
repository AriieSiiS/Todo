import 'dart:convert';

import '../entities/category.dart';
import '../entities/calendar_models.dart';
import '../entities/enums.dart';
import '../entities/financial.dart';
import '../entities/library_goal.dart';
import '../entities/library_item.dart';
import '../entities/project.dart';
import '../entities/quick_note.dart';
import '../entities/settings.dart';
import '../entities/task.dart';

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
    required this.calendarEvents,
    required this.daySettings,
    required this.notificationSettings,
    required this.calendarSettings,
    this.visualMode = AppVisualMode.classic,
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
  final List<CalendarEventModel> calendarEvents;
  final DaySettings daySettings;
  final DeviceNotificationSettings notificationSettings;
  final CalendarIntegrationSettings calendarSettings;
  final AppVisualMode visualMode;

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
      'calendarEvents': calendarEvents.map((event) => event.toJson()).toList(),
      'daySettings': daySettings.toJson(),
      'notificationSettings': notificationSettings.toJson(),
      'calendarSettings': calendarSettings.toJson(),
      'visualMode': visualMode.name,
    });
  }
}
