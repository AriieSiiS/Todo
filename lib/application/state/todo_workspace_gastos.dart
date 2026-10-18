part of 'todo_workspace.dart';

extension TodoWorkspaceGastos on TodoWorkspace {
  ExpenseCategory? expenseCategoryById(String id) {
    for (final category in _expenseCategories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }

  PaymentMethodModel? paymentMethodById(String id) {
    for (final method in _paymentMethods) {
      if (method.id == id) {
        return method;
      }
    }
    return null;
  }

  Expense? expenseById(String id) {
    for (final expense in _expenses) {
      if (expense.id == id) {
        return expense;
      }
    }
    return null;
  }

  Expense createExpense({
    required DateTime date,
    String concept = '',
    required double amount,
    required String categoryId,
    String? paymentMethodId,
    List<String> projectIds = const <String>[],
    String? note,
    bool isRecurringInstance = false,
    String? fixedPaymentId,
  }) {
    final now = DateTime.now();
    final expense = Expense(
      id: _id('expense'),
      date: DateTime(date.year, date.month, date.day),
      concept: concept.trim().isEmpty ? 'Gasto' : concept.trim(),
      amount: amount,
      categoryId: categoryId,
      paymentMethodId: paymentMethodId,
      projectIds: List<String>.from(projectIds),
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      isRecurringInstance: isRecurringInstance,
      fixedPaymentId: fixedPaymentId,
      createdAt: now,
      updatedAt: now,
    );
    _expenses.add(expense);
    _commit();
    return expense;
  }

  void updateExpense(Expense updated) {
    final index = _expenses.indexWhere((expense) => expense.id == updated.id);
    if (index == -1) {
      return;
    }
    _expenses[index] = updated.copyWith(updatedAt: DateTime.now());
    _commit();
  }

  void duplicateExpense(String expenseId) {
    final source = expenseById(expenseId);
    if (source == null) {
      return;
    }
    createExpense(
      date: source.date,
      concept: '${source.concept} copia',
      amount: source.amount,
      categoryId: source.categoryId,
      paymentMethodId: source.paymentMethodId,
      projectIds: source.projectIds,
      note: source.note,
      isRecurringInstance: source.isRecurringInstance,
      fixedPaymentId: source.fixedPaymentId,
    );
  }

  void deleteExpense(String expenseId) {
    _expenses.removeWhere((expense) => expense.id == expenseId);
    _commit();
  }

  ExpenseCategory createExpenseCategory({
    required String name,
    required int colorValue,
    required IconData icon,
  }) {
    final now = DateTime.now();
    final category = ExpenseCategory(
      id: _id('expense-category'),
      name: name.trim(),
      colorValue: colorValue,
      icon: icon,
      createdAt: now,
      updatedAt: now,
    );
    _expenseCategories.add(category);
    _commit();
    return category;
  }

  void updateExpenseCategory(ExpenseCategory updated) {
    final index =
        _expenseCategories.indexWhere((category) => category.id == updated.id);
    if (index == -1) {
      return;
    }
    _expenseCategories[index] = updated.copyWith(updatedAt: DateTime.now());
    _commit();
  }

  PaymentMethodModel createPaymentMethod({
    required String name,
    required IconData icon,
    required int colorValue,
  }) {
    final now = DateTime.now();
    final method = PaymentMethodModel(
      id: _id('payment-method'),
      name: name.trim(),
      icon: icon,
      colorValue: colorValue,
      createdAt: now,
      updatedAt: now,
    );
    _paymentMethods.add(method);
    _commit();
    return method;
  }

  void updatePaymentMethod(PaymentMethodModel updated) {
    final index =
        _paymentMethods.indexWhere((method) => method.id == updated.id);
    if (index == -1) {
      return;
    }
    _paymentMethods[index] = updated.copyWith(updatedAt: DateTime.now());
    _commit();
  }

  FixedPayment createFixedPayment({
    required String name,
    required double amount,
    required String categoryId,
    String? paymentMethodId,
    FixedPaymentFrequency frequency = FixedPaymentFrequency.monthly,
    String? customInterval,
    required DateTime nextPaymentDate,
    String? note,
    int reminderDaysBefore = 3,
  }) {
    final now = DateTime.now();
    final payment = FixedPayment(
      id: _id('fixed-payment'),
      name: name.trim(),
      amount: amount,
      categoryId: categoryId,
      paymentMethodId: paymentMethodId,
      frequency: frequency,
      customInterval: customInterval,
      nextPaymentDate: DateTime(
          nextPaymentDate.year, nextPaymentDate.month, nextPaymentDate.day),
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      reminderDaysBefore: reminderDaysBefore.clamp(0, 60),
      anchorDay: nextPaymentDate.day,
      createdAt: now,
      updatedAt: now,
    );
    _fixedPayments.add(payment);
    _commit();
    return payment;
  }

  void updateFixedPayment(FixedPayment updated) {
    final index =
        _fixedPayments.indexWhere((payment) => payment.id == updated.id);
    if (index == -1) {
      return;
    }
    _fixedPayments[index] = updated.copyWith(updatedAt: DateTime.now());
    _commit();
  }

  Expense createExpenseFromFixedPayment(String fixedPaymentId) {
    final payment =
        _fixedPayments.firstWhere((item) => item.id == fixedPaymentId);
    return createExpense(
      date: payment.nextPaymentDate,
      concept: payment.name,
      amount: payment.amount,
      categoryId: payment.categoryId,
      paymentMethodId: payment.paymentMethodId,
      note: payment.note,
      isRecurringInstance: true,
      fixedPaymentId: payment.id,
    );
  }

  /// Coste mensual equivalente de un pago fijo (los personalizados se
  /// interpretan como «cada N días» cuando el intervalo es un número).
  double fixedPaymentMonthlyCost(FixedPayment payment) {
    return switch (payment.frequency) {
      FixedPaymentFrequency.weekly => payment.amount * 52 / 12,
      FixedPaymentFrequency.monthly => payment.amount,
      FixedPaymentFrequency.yearly => payment.amount / 12,
      FixedPaymentFrequency.custom => () {
          final days = int.tryParse(
              RegExp(r'\d+').firstMatch(payment.customInterval ?? '')?.group(0) ??
                  '');
          return days == null || days <= 0
              ? payment.amount
              : payment.amount * 365 / 12 / days;
        }(),
    };
  }

  double get fixedPaymentsMonthlyTotal => _fixedPayments
      .where((payment) => payment.isActive)
      .fold<double>(0, (sum, payment) => sum + fixedPaymentMonthlyCost(payment));

  /// Pagos activos ordenados por su próxima fecha.
  List<FixedPayment> upcomingFixedPayments() {
    return _fixedPayments.where((payment) => payment.isActive).toList()
      ..sort((a, b) => a.nextPaymentDate.compareTo(b.nextPaymentDate));
  }

  /// Pagos activos cuyo aviso ya está en marcha (dentro de su antelación) y
  /// que todavía no han pasado de fecha.
  List<FixedPayment> fixedPaymentsDueSoon([DateTime? reference]) {
    final today = logicalDate(reference);
    return upcomingFixedPayments().where((payment) {
      if (payment.reminderDaysBefore <= 0) return false;
      final days = payment.nextPaymentDate.difference(today).inDays;
      return days >= 0 && days <= payment.reminderDaysBefore;
    }).toList();
  }

  /// Fecha del cobro siguiente a [from] según la frecuencia del pago.
  DateTime nextFixedPaymentDate(FixedPayment payment, DateTime from) {
    switch (payment.frequency) {
      case FixedPaymentFrequency.weekly:
        return DateTime(from.year, from.month, from.day + 7);
      case FixedPaymentFrequency.yearly:
        return _addMonthsClamped(from, 12, payment.anchorDay ?? payment.nextPaymentDate.day);
      case FixedPaymentFrequency.custom:
        final days = int.tryParse(
            RegExp(r'\d+').firstMatch(payment.customInterval ?? '')?.group(0) ??
                '');
        if (days != null && days > 0) {
          return DateTime(from.year, from.month, from.day + days);
        }
        return _addMonthsClamped(from, 1, payment.anchorDay ?? payment.nextPaymentDate.day);
      case FixedPaymentFrequency.monthly:
        return _addMonthsClamped(from, 1, payment.anchorDay ?? payment.nextPaymentDate.day);
    }
  }

  DateTime _addMonthsClamped(DateTime from, int months, int preferredDay) {
    final target = DateTime(from.year, from.month + months, 1);
    final lastDay = DateTime(target.year, target.month + 1, 0).day;
    return DateTime(
        target.year, target.month, preferredDay > lastDay ? lastDay : preferredDay);
  }

  /// Registra el cobro como gasto y adelanta la próxima fecha del pago.
  Expense markFixedPaymentPaid(String fixedPaymentId) {
    final index =
        _fixedPayments.indexWhere((payment) => payment.id == fixedPaymentId);
    if (index == -1) {
      throw StateError('No se encuentra el pago fijo.');
    }
    final payment = _fixedPayments[index];
    final expense = createExpenseFromFixedPayment(fixedPaymentId);
    _fixedPayments[index] = payment.copyWith(
      nextPaymentDate: nextFixedPaymentDate(payment, payment.nextPaymentDate),
      updatedAt: DateTime.now(),
    );
    _commit();
    return expense;
  }

  void deleteFixedPayment(String fixedPaymentId) {
    _fixedPayments.removeWhere((payment) => payment.id == fixedPaymentId);
    _commit();
  }

  List<Expense> expensesForMonth(int year, int month) {
    return _expenses
        .where((expense) =>
            expense.date.year == year && expense.date.month == month)
        .toList()
      ..sort((left, right) => right.date.compareTo(left.date));
  }

  double expenseTotalForMonth(int year, int month) {
    return expensesForMonth(year, month)
        .fold<double>(0, (total, expense) => total + expense.amount);
  }

  double expenseTotalForCategoryMonth(String categoryId, int year, int month) {
    return _expenses
        .where((expense) =>
            expense.categoryId == categoryId &&
            expense.date.year == year &&
            expense.date.month == month)
        .fold<double>(0, (total, expense) => total + expense.amount);
  }

  double expenseTotalForCategoryYear(String categoryId, int year) {
    return _expenses
        .where((expense) =>
            expense.categoryId == categoryId && expense.date.year == year)
        .fold<double>(0, (total, expense) => total + expense.amount);
  }

  double expenseTotalForYear(int year) {
    return _expenses
        .where((expense) => expense.date.year == year)
        .fold<double>(0, (total, expense) => total + expense.amount);
  }

  String exportFinancialJson() {
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'expenses': expenses.map((expense) => expense.toJson()).toList(),
      'expenseCategories':
          expenseCategories.map((category) => category.toJson()).toList(),
      'paymentMethods':
          paymentMethods.map((method) => method.toJson()).toList(),
      'fixedPayments':
          fixedPayments.map((payment) => payment.toJson()).toList(),
      'generatedAt': DateTime.now().toIso8601String(),
    });
  }

  String exportFinancialCsv() {
    final rows = <List<String>>[
      ['fecha', 'concepto', 'importe', 'categoría', 'método', 'nota'],
      ..._expenses.map((expense) {
        return [
          expense.date.toIso8601String().split('T').first,
          expense.concept,
          expense.amount.toStringAsFixed(2),
          expenseCategoryById(expense.categoryId)?.name ?? '',
          paymentMethodById(expense.paymentMethodId ?? '')?.name ?? '',
          expense.note ?? '',
        ];
      }),
    ];
    return rows
        .map((row) =>
            row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','))
        .join('\n');
  }
}
