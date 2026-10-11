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
