part of 'app_shell.dart';

enum _ExpenseTab { monthly, annual, fixed, categories, methods }

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({required this.controller, super.key});

  final TodoWorkspace controller;

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  _ExpenseTab _tab = _ExpenseTab.monthly;
  late int _year;
  late int _month;
  String? _categoryFilterId;
  String? _paymentFilterId;
  String _textFilter = '';
  bool _recurringOnly = false;

  TodoWorkspace get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    final now = controller.logicalDate();
    _year = now.year;
    _month = now.month;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: const Color(0xFFE7D9C8)),
          boxShadow: const [
            BoxShadow(
              blurRadius: 26,
              color: Color(0x12000000),
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ExpensesHeader(
                controls: _ExpensesTopControls(
                  year: _year,
                  month: _month,
                  onPrevious: _movePreviousMonth,
                  onNext: _moveNextMonth,
                  onYearChanged: (value) => setState(() => _year = value),
                  onMonthChanged: (value) => setState(() => _month = value),
                  onNewExpense: () => _showExpenseDialog(),
                ),
              ),
              const SizedBox(height: 16),
              _ExpenseTabs(
                selected: _tab,
                onChanged: (value) => setState(() => _tab = value),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 1160;
                    if (!wide || _tab != _ExpenseTab.monthly) {
                      return ListView(
                        children: [
                          _mainContent(shrinkWrap: true),
                          if (_tab == _ExpenseTab.monthly) ...[
                            const SizedBox(height: 16),
                            _sidePanel(shrinkWrap: true),
                          ],
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: _mainContent()),
                        const SizedBox(width: 16),
                        SizedBox(width: 340, child: _sidePanel()),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mainContent({bool shrinkWrap = false}) {
    final child = switch (_tab) {
      _ExpenseTab.monthly => _MonthlyExpenseView(
          controller: controller,
          year: _year,
          month: _month,
          filteredExpenses: _filteredExpenses(),
          onEditExpense: _showExpenseDialog,
          onDuplicateExpense: (expense) =>
              controller.duplicateExpense(expense.id),
          onDeleteExpense: (expense) => controller.deleteExpense(expense.id),
        ),
      _ExpenseTab.annual => _AnnualExpenseView(
          controller: controller,
          year: _year,
          activeMonth: _month,
        ),
      _ExpenseTab.fixed => _FixedPaymentsView(
          controller: controller,
          onCreateFixedPayment: _showFixedPaymentDialog,
        ),
      _ExpenseTab.categories => _ExpenseCategoriesView(
          controller: controller, onCreate: _showCategoryDialog),
      _ExpenseTab.methods => _PaymentMethodsView(
          controller: controller, onCreate: _showPaymentMethodDialog),
    };
    if (shrinkWrap) {
      return child;
    }
    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
      child: ListView(children: [child]),
    );
  }

  Widget _sidePanel({bool shrinkWrap = false}) {
    final panel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuickExpenseSummary(
            controller: controller, year: _year, month: _month),
        const SizedBox(height: 12),
        _RecentExpenseAside(
          controller: controller,
          expenses: _filteredExpenses().take(6).toList(),
          onOpen: _showExpenseDialog,
        ),
        const SizedBox(height: 12),
        _ExpenseFiltersPanel(
          controller: controller,
          categoryFilterId: _categoryFilterId,
          paymentFilterId: _paymentFilterId,
          textFilter: _textFilter,
          recurringOnly: _recurringOnly,
          onCategoryChanged: (value) =>
              setState(() => _categoryFilterId = value),
          onPaymentChanged: (value) => setState(() => _paymentFilterId = value),
          onRecurringChanged: (value) => setState(() => _recurringOnly = value),
          onTextChanged: (value) => setState(() => _textFilter = value),
          onClear: _clearFilters,
        ),
        const SizedBox(height: 12),
        _ExportPanel(controller: controller),
      ],
    );
    if (shrinkWrap) {
      return panel;
    }
    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
      child: ListView(children: [panel]),
    );
  }

  void _clearFilters() {
    setState(() {
      _categoryFilterId = null;
      _paymentFilterId = null;
      _textFilter = '';
      _recurringOnly = false;
    });
  }

  List<Expense> _filteredExpenses() {
    final query = _textFilter.trim().toLowerCase();
    return controller
        .expensesForMonth(_year, _month)
        .where((expense) =>
            _categoryFilterId == null ||
            expense.categoryId == _categoryFilterId)
        .where((expense) =>
            _paymentFilterId == null ||
            expense.paymentMethodId == _paymentFilterId)
        .where((expense) => !_recurringOnly || expense.isRecurringInstance)
        .where((expense) {
      if (query.isEmpty) {
        return true;
      }
      final category =
          controller.expenseCategoryById(expense.categoryId)?.name ?? '';
      final method =
          controller.paymentMethodById(expense.paymentMethodId ?? '')?.name ??
              '';
      return '${expense.concept} ${expense.note ?? ''} $category $method'
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  void _movePreviousMonth() {
    setState(() {
      if (_month == 1) {
        _month = 12;
        _year -= 1;
      } else {
        _month -= 1;
      }
    });
  }

  void _moveNextMonth() {
    setState(() {
      if (_month == 12) {
        _month = 1;
        _year += 1;
      } else {
        _month += 1;
      }
    });
  }

  Future<void> _showExpenseDialog([Expense? expense]) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _ExpenseEditorDialog(
        controller: controller,
        initialExpense: expense,
        initialDate: DateTime(_year, _month, 1),
      ),
    );
  }

  Future<void> _showCategoryDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _ExpenseCategoryDialog(controller: controller),
    );
  }

  Future<void> _showPaymentMethodDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _PaymentMethodDialog(controller: controller),
    );
  }

  Future<void> _showFixedPaymentDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _FixedPaymentDialog(controller: controller),
    );
  }
}

class _ExpensesTopControls extends StatelessWidget {
  const _ExpensesTopControls({
    required this.year,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onNewExpense,
  });

  final int year;
  final int month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onMonthChanged;
  final VoidCallback onNewExpense;

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _IconShell(icon: Icons.chevron_left_rounded, onTap: onPrevious),
        _HeaderSelectPill<int>(
          label: 'Mes',
          value: month,
          display: _expenseMonthName(month),
          width: 176,
          items: List<int>.generate(12, (index) => index + 1),
          itemLabel: _expenseMonthName,
          onChanged: onMonthChanged,
        ),
        _HeaderSelectPill<int>(
          label: 'Año',
          value: year,
          display: '$year',
          width: 142,
          items: List<int>.generate(7, (index) => currentYear - 3 + index),
          itemLabel: (value) => '$value',
          onChanged: onYearChanged,
        ),
        _IconShell(icon: Icons.chevron_right_rounded, onTap: onNext),
        _HeaderActionButton(
          label: 'Nuevo gasto',
          icon: Icons.add_rounded,
          onPressed: onNewExpense,
        ),
      ],
    );
  }
}

class _ExpensesHeader extends StatelessWidget {
  const _ExpensesHeader({required this.controls});

  final Widget controls;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gastos y pagos', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 6),
        Text(
          'Controla tus gastos mensuales y visualiza totales, balances e historial.',
          style: TextStyle(color: context.visuals.textMuted),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titleBlock,
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerRight, child: controls),
      ],
    );
  }
}

class _HeaderSelectPill<T> extends StatelessWidget {
  const _HeaderSelectPill({
    required this.label,
    required this.value,
    required this.display,
    required this.width,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final String display;
  final double width;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      initialValue: value,
      tooltip: label,
      onSelected: onChanged,
      itemBuilder: (context) => items
          .map(
            (item) => PopupMenuItem<T>(
              value: item,
              child: Text(itemLabel(item)),
            ),
          )
          .toList(),
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(18, 9, 12, 10),
        decoration: BoxDecoration(
          color: label == 'Mes'
              ? const Color(0xFFFFF8E5)
              : const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: label == 'Mes'
                ? const Color(0xFFD6B86A)
                : const Color(0xFFE2D1BD),
            width: label == 'Mes' ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: context.visuals.textMuted,
                      fontSize: 12,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    display,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF2D2A25),
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF6E675C)),
          ],
        ),
      ),
    );
  }
}

class _ExpenseTabs extends StatelessWidget {
  const _ExpenseTabs({required this.selected, required this.onChanged});

  final _ExpenseTab selected;
  final ValueChanged<_ExpenseTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = <({String label, IconData icon, _ExpenseTab tab})>[
      (
        label: 'Vista mensual',
        icon: Icons.table_chart_rounded,
        tab: _ExpenseTab.monthly
      ),
      (
        label: 'Resumen anual',
        icon: Icons.bar_chart_rounded,
        tab: _ExpenseTab.annual
      ),
      (
        label: 'Pagos fijos',
        icon: Icons.autorenew_rounded,
        tab: _ExpenseTab.fixed
      ),
      (
        label: 'Categorías',
        icon: Icons.category_rounded,
        tab: _ExpenseTab.categories
      ),
      (
        label: 'Métodos de pago',
        icon: Icons.credit_card_rounded,
        tab: _ExpenseTab.methods
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((item) {
          final isSelected = item.tab == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: isSelected,
              avatar: Icon(item.icon, size: 17),
              label: Text(item.label),
              onSelected: (_) => onChanged(item.tab),
              selectedColor: const Color(0xFF7C9164),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF2D2A25),
                fontWeight: FontWeight.w700,
              ),
              side: const BorderSide(color: Color(0xFFE3D5C4)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MonthlyExpenseView extends StatelessWidget {
  const _MonthlyExpenseView({
    required this.controller,
    required this.year,
    required this.month,
    required this.filteredExpenses,
    required this.onEditExpense,
    required this.onDuplicateExpense,
    required this.onDeleteExpense,
  });

  final TodoWorkspace controller;
  final int year;
  final int month;
  final List<Expense> filteredExpenses;
  final ValueChanged<Expense> onEditExpense;
  final ValueChanged<Expense> onDuplicateExpense;
  final ValueChanged<Expense> onDeleteExpense;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MonthlyCategorySpendCard(
            controller: controller, year: year, month: month),
        const SizedBox(height: 14),
        _MonthlyBalanceTable(controller: controller, year: year, month: month),
        const SizedBox(height: 14),
        _RecentExpensesTable(
          controller: controller,
          expenses: filteredExpenses,
          onEdit: onEditExpense,
          onDuplicate: onDuplicateExpense,
          onDelete: onDeleteExpense,
        ),
      ],
    );
  }
}

class _AnnualCategoryTable extends StatelessWidget {
  const _AnnualCategoryTable({
    required this.controller,
    required this.year,
    required this.activeMonth,
  });

  final TodoWorkspace controller;
  final int year;
  final int activeMonth;

  @override
  Widget build(BuildContext context) {
    return _FinancePanel(
      title: 'Tabla anual por categoría',
      icon: Icons.grid_on_rounded,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8DCCB)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Table(
            defaultColumnWidth: const FlexColumnWidth(1),
            columnWidths: const <int, TableColumnWidth>{
              0: FlexColumnWidth(2.2),
              13: FlexColumnWidth(1.15),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFFFD867)),
                children: [
                  const _DashboardCell('Categoría',
                      height: 44, strong: true, align: TextAlign.left),
                  ...List<Widget>.generate(
                    12,
                    (index) {
                      final highlighted = index + 1 == activeMonth;
                      return _DashboardCell(
                        highlighted
                            ? _expenseMonthName(index + 1)
                            : _expenseMonthShort(index + 1),
                        height: 44,
                        strong: true,
                        highlighted: highlighted,
                        textColor: highlighted ? const Color(0xFF2D2A25) : null,
                      );
                    },
                  ),
                  const _DashboardCell('Total', height: 44, strong: true),
                ],
              ),
              ...controller.expenseCategories.toList().asMap().entries.map(
                (entry) {
                  final category = entry.value;
                  return TableRow(
                    decoration: BoxDecoration(
                      color: category.isActive
                          ? (entry.key.isEven
                              ? const Color(0xFFF4F1FA)
                              : const Color(0xFFEEEAF6))
                          : const Color(0xFFF0E9DE),
                      border: const Border(
                          bottom: BorderSide(color: Color(0xFFE2D8CA))),
                    ),
                    children: [
                      _DashboardCategoryCell(category: category),
                      ...List<Widget>.generate(12, (index) {
                        final value = controller.expenseTotalForCategoryMonth(
                            category.id, year, index + 1);
                        return _DashboardCell(
                          _compactMoneyOrDash(value),
                          highlighted: index + 1 == activeMonth,
                          strong: index + 1 == activeMonth,
                          textColor: value == 0
                              ? const Color(0xFF9A9287)
                              : const Color(0xFF201D19),
                        );
                      }),
                      _DashboardCell(
                        _compactMoney(controller.expenseTotalForCategoryYear(
                            category.id, year)),
                        strong: true,
                      ),
                    ],
                  );
                },
              ),
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF1C1C4)),
                children: [
                  const _DashboardCell('Total',
                      height: 48, strong: true, align: TextAlign.left),
                  ...List<Widget>.generate(
                    12,
                    (index) {
                      final value =
                          controller.expenseTotalForMonth(year, index + 1);
                      return _DashboardCell(
                        _compactMoneyOrDash(value),
                        height: 48,
                        highlighted: index + 1 == activeMonth,
                        strong: true,
                        textColor: value == 0
                            ? const Color(0xFF8F6F72)
                            : const Color(0xFF201D19),
                      );
                    },
                  ),
                  _DashboardCell(
                      _compactMoney(controller.expenseTotalForYear(year)),
                      height: 48,
                      strong: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthlyCategorySpendCard extends StatelessWidget {
  const _MonthlyCategorySpendCard({
    required this.controller,
    required this.year,
    required this.month,
  });

  final TodoWorkspace controller;
  final int year;
  final int month;

  @override
  Widget build(BuildContext context) {
    final monthName = _expenseMonthName(month);
    return _FinancePanel(
      title: 'Gasto de $monthName por categoría',
      icon: Icons.pie_chart_outline_rounded,
      child: Column(
        children: controller.expenseCategories.map((category) {
          final spent =
              controller.expenseTotalForCategoryMonth(category.id, year, month);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE7D9C8)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: category.color.withValues(alpha: 0.16),
                      child:
                          Icon(category.icon, color: category.color, size: 18),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(category.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                            spent == 0
                                ? 'Sin gastos registrados este mes'
                                : 'Gasto registrado este mes',
                            style: TextStyle(color: context.visuals.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(_money(spent),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MonthlyBalanceTable extends StatelessWidget {
  const _MonthlyBalanceTable({
    required this.controller,
    required this.year,
    required this.month,
  });

  final TodoWorkspace controller;
  final int year;
  final int month;

  @override
  Widget build(BuildContext context) {
    final previous = month == 1 ? 12 : month - 1;
    final previousYear = month == 1 ? year - 1 : year;
    return _FinancePanel(
      title: 'Balance mensual por categoría',
      icon: Icons.compare_arrows_rounded,
      child: Table(
        defaultColumnWidth: const FlexColumnWidth(1),
        columnWidths: const <int, TableColumnWidth>{
          0: FlexColumnWidth(2.2),
          1: FlexColumnWidth(1.15),
          2: FlexColumnWidth(1.15),
          3: FlexColumnWidth(1.15),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFFFD867)),
            children: [
              const _DashboardCell('Categoría',
                  height: 44, strong: true, align: TextAlign.left),
              _DashboardCell(_expenseMonthName(month),
                  height: 44, strong: true),
              _DashboardCell(_expenseMonthName(previous),
                  height: 44, strong: true),
              const _DashboardCell('Diferencia', height: 44, strong: true),
            ],
          ),
          ...controller.expenseCategories.toList().asMap().entries.map((entry) {
            final category = entry.value;
            final current = controller.expenseTotalForCategoryMonth(
                category.id, year, month);
            final prev = controller.expenseTotalForCategoryMonth(
                category.id, previousYear, previous);
            final diff = current - prev;
            return TableRow(
              decoration: BoxDecoration(
                color: entry.key.isEven
                    ? const Color(0xFFF3F7EF)
                    : const Color(0xFFEAF2E4),
                border:
                    const Border(bottom: BorderSide(color: Color(0xFFE2D8CA))),
              ),
              children: [
                _DashboardCategoryCell(category: category),
                _DashboardCell(_compactMoney(current)),
                _DashboardCell(_compactMoney(prev)),
                _DashboardCell(_compactSignedMoney(diff),
                    strong: true,
                    textColor: diff > 0
                        ? const Color(0xFF9D4436)
                        : diff < 0
                            ? const Color(0xFF5D8A64)
                            : const Color(0xFF2D2A25)),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _RecentExpensesTable extends StatelessWidget {
  const _RecentExpensesTable({
    required this.controller,
    required this.expenses,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  final TodoWorkspace controller;
  final List<Expense> expenses;
  final ValueChanged<Expense> onEdit;
  final ValueChanged<Expense> onDuplicate;
  final ValueChanged<Expense> onDelete;

  @override
  Widget build(BuildContext context) {
    return _FinancePanel(
      title: 'Historial de gastos recientes',
      icon: Icons.history_rounded,
      child: expenses.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(18),
              child: Text('No hay gastos con estos filtros.'),
            )
          : Column(
              children: expenses.map((expense) {
                final category =
                    controller.expenseCategoryById(expense.categoryId);
                final method =
                    controller.paymentMethodById(expense.paymentMethodId ?? '');
                return _ExpenseHistoryRow(
                  expense: expense,
                  category: category,
                  method: method,
                  projectLabel: _projectLabel(controller, expense),
                  onEdit: () => onEdit(expense),
                  onDuplicate: () => onDuplicate(expense),
                  onDelete: () => onDelete(expense),
                );
              }).toList(),
            ),
    );
  }
}

class _ExpenseHistoryRow extends StatelessWidget {
  const _ExpenseHistoryRow({
    required this.expense,
    required this.category,
    required this.method,
    required this.projectLabel,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  final Expense expense;
  final ExpenseCategory? category;
  final PaymentMethodModel? method;
  final String projectLabel;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = category?.color ?? const Color(0xFF70835D);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7D9C8)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: accent.withValues(alpha: 0.16),
            child: Icon(category?.icon ?? Icons.receipt_long_rounded,
                color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.concept,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  '${_dateLabel(expense.date)} · ${category?.name ?? 'Sin categoría'} · ${method?.name ?? 'Sin método'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.visuals.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              projectLabel == '-' ? (expense.note ?? '-') : projectLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.visuals.textMuted),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 92,
            child: Text(
              _money(expense.amount),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Duplicar',
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: onDuplicate,
          ),
          IconButton(
            tooltip: 'Borrar',
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _QuickExpenseSummary extends StatelessWidget {
  const _QuickExpenseSummary({
    required this.controller,
    required this.year,
    required this.month,
  });

  final TodoWorkspace controller;
  final int year;
  final int month;

  @override
  Widget build(BuildContext context) {
    final expenses = controller.expensesForMonth(year, month);
    final total = controller.expenseTotalForMonth(year, month);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final categoryTotals = {
      for (final category in controller.expenseCategories)
        category.id:
            controller.expenseTotalForCategoryMonth(category.id, year, month)
    };
    final topCategoryId = categoryTotals.entries.isEmpty
        ? null
        : (categoryTotals.entries.toList()
              ..sort((left, right) => right.value.compareTo(left.value)))
            .first
            .key;
    final previousMonth = month == 1 ? 12 : month - 1;
    final previousYear = month == 1 ? year - 1 : year;
    final previousTotal =
        controller.expenseTotalForMonth(previousYear, previousMonth);
    return _FinancePanel(
      title: 'Resumen rápido',
      icon: Icons.insights_outlined,
      child: Column(
        children: [
          _SummaryHero(
              value: _money(total), label: '${_expenseMonthName(month)} $year'),
          _SummaryLine('Promedio diario', _money(total / daysInMonth)),
          _SummaryLine('Mayor categoría',
              controller.expenseCategoryById(topCategoryId ?? '')?.name ?? '-'),
          _SummaryLine('Comparado con ${_expenseMonthName(previousMonth)}',
              _signedMoney(total - previousTotal)),
          _SummaryLine('Gastos registrados', expenses.length.toString()),
        ],
      ),
    );
  }
}

class _ExpenseFiltersPanel extends StatelessWidget {
  const _ExpenseFiltersPanel({
    required this.controller,
    required this.categoryFilterId,
    required this.paymentFilterId,
    required this.textFilter,
    required this.recurringOnly,
    required this.onCategoryChanged,
    required this.onPaymentChanged,
    required this.onRecurringChanged,
    required this.onTextChanged,
    required this.onClear,
  });

  final TodoWorkspace controller;
  final String? categoryFilterId;
  final String? paymentFilterId;
  final String textFilter;
  final bool recurringOnly;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onPaymentChanged;
  final ValueChanged<bool> onRecurringChanged;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _FinancePanel(
      title: 'Filtros',
      icon: Icons.filter_alt_outlined,
      child: Column(
        children: [
          TextFormField(
            key: ValueKey(textFilter),
            initialValue: textFilter,
            onChanged: onTextChanged,
            decoration: const InputDecoration(
              labelText: 'Texto o concepto',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            initialValue: categoryFilterId,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('Todas')),
              ...controller.expenseCategories.map(
                (category) => DropdownMenuItem<String?>(
                  value: category.id,
                  child: Text(category.name),
                ),
              ),
            ],
            onChanged: onCategoryChanged,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            initialValue: paymentFilterId,
            decoration: const InputDecoration(labelText: 'Método de pago'),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('Todos')),
              ...controller.paymentMethods.map(
                (method) => DropdownMenuItem<String?>(
                  value: method.id,
                  child: Text(method.name),
                ),
              ),
            ],
            onChanged: onPaymentChanged,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Solo pagos recurrentes'),
            value: recurringOnly,
            onChanged: onRecurringChanged,
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.cleaning_services_outlined, size: 17),
              label: const Text('Limpiar filtros'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentExpenseAside extends StatelessWidget {
  const _RecentExpenseAside({
    required this.controller,
    required this.expenses,
    required this.onOpen,
  });

  final TodoWorkspace controller;
  final List<Expense> expenses;
  final ValueChanged<Expense> onOpen;

  @override
  Widget build(BuildContext context) {
    return _FinancePanel(
      title: 'Últimos movimientos',
      icon: Icons.receipt_long_rounded,
      child: expenses.isEmpty
          ? const Text('Sin movimientos visibles.')
          : Column(
              children: expenses.map((expense) {
                final category =
                    controller.expenseCategoryById(expense.categoryId);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor:
                        (category?.color ?? const Color(0xFF70835D))
                            .withValues(alpha: 0.16),
                    child: Icon(category?.icon ?? Icons.receipt_long_rounded,
                        color: category?.color ?? const Color(0xFF70835D)),
                  ),
                  title: Text(expense.concept,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      '${_dateLabel(expense.date)} - ${category?.name ?? ''}'),
                  trailing: Text(_money(expense.amount),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  onTap: () => onOpen(expense),
                );
              }).toList(),
            ),
    );
  }
}

class _AnnualExpenseView extends StatelessWidget {
  const _AnnualExpenseView({
    required this.controller,
    required this.year,
    required this.activeMonth,
  });

  final TodoWorkspace controller;
  final int year;
  final int activeMonth;

  @override
  Widget build(BuildContext context) {
    final monthTotals = List<double>.generate(
        12, (index) => controller.expenseTotalForMonth(year, index + 1));
    final maxValue = monthTotals.isEmpty ? 0.0 : monthTotals.reduce(max);
    final minValue = monthTotals.isEmpty ? 0.0 : monthTotals.reduce(min);
    final maxMonth = monthTotals.indexOf(maxValue) + 1;
    final minMonth = monthTotals.indexOf(minValue) + 1;
    final categoryTotals = {
      for (final category in controller.expenseCategories)
        category.name: controller.expenseTotalForCategoryYear(category.id, year)
    };
    final topCategory = categoryTotals.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    return Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _FinanceMetric(
                label: 'Total anual',
                value: _money(controller.expenseTotalForYear(year))),
            _FinanceMetric(
                label: 'Mes con más gasto', value: _expenseMonthName(maxMonth)),
            _FinanceMetric(
                label: 'Mes con menos gasto',
                value: _expenseMonthName(minMonth)),
            _FinanceMetric(
                label: 'Categoría mayor',
                value: topCategory.isEmpty ? '-' : topCategory.first.key),
          ],
        ),
        const SizedBox(height: 14),
        _AnnualCategoryTable(
          controller: controller,
          year: year,
          activeMonth: activeMonth,
        ),
      ],
    );
  }
}

class _FixedPaymentsView extends StatelessWidget {
  const _FixedPaymentsView({
    required this.controller,
    required this.onCreateFixedPayment,
  });

  final TodoWorkspace controller;
  final VoidCallback onCreateFixedPayment;

  @override
  Widget build(BuildContext context) {
    return _FinancePanel(
      title: 'Pagos fijos',
      icon: Icons.autorenew_rounded,
      trailing: FilledButton.icon(
        onPressed: onCreateFixedPayment,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo pago fijo'),
      ),
      child: Column(
        children: controller.fixedPayments.map((payment) {
          final category = controller.expenseCategoryById(payment.categoryId);
          final method =
              controller.paymentMethodById(payment.paymentMethodId ?? '');
          return _FinanceListRow(
            icon: Icons.autorenew_rounded,
            color: category?.color ?? const Color(0xFF70835D),
            title: payment.name,
            subtitle:
                '${category?.name ?? 'Sin categoría'} - ${method?.name ?? 'Sin método'} - ${_frequencyLabel(payment.frequency)}',
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_money(payment.amount),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(_dateLabel(payment.nextPaymentDate)),
              ],
            ),
            onToggle: () => controller.updateFixedPayment(
              payment.copyWith(isActive: !payment.isActive),
            ),
            active: payment.isActive,
          );
        }).toList(),
      ),
    );
  }
}

class _ExpenseCategoriesView extends StatelessWidget {
  const _ExpenseCategoriesView(
      {required this.controller, required this.onCreate});

  final TodoWorkspace controller;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return _FinancePanel(
      title: 'Categorías financieras',
      icon: Icons.category_rounded,
      trailing: FilledButton.icon(
        onPressed: onCreate,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva categoría'),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: controller.expenseCategories.map((category) {
          final spent = controller.expenseTotalForCategoryMonth(
              category.id, DateTime.now().year, DateTime.now().month);
          return SizedBox(
            width: 260,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF8),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE3D5C4)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              category.color.withValues(alpha: 0.16),
                          child: Icon(category.icon, color: category.color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(category.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        Switch(
                          value: category.isActive,
                          onChanged: (value) =>
                              controller.updateExpenseCategory(
                                  category.copyWith(isActive: value)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Gastado este mes: ${_money(spent)}'),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PaymentMethodsView extends StatelessWidget {
  const _PaymentMethodsView({required this.controller, required this.onCreate});

  final TodoWorkspace controller;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return _FinancePanel(
      title: 'Métodos de pago',
      icon: Icons.credit_card_rounded,
      trailing: FilledButton.icon(
        onPressed: onCreate,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo método'),
      ),
      child: Column(
        children: controller.paymentMethods.map((method) {
          return _FinanceListRow(
            icon: method.icon,
            color: method.color,
            title: method.name,
            subtitle: method.isActive ? 'Activo' : 'Inactivo',
            active: method.isActive,
            onToggle: () => controller.updatePaymentMethod(
              method.copyWith(isActive: !method.isActive),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ExportPanel extends StatelessWidget {
  const _ExportPanel({required this.controller});

  final TodoWorkspace controller;

  @override
  Widget build(BuildContext context) {
    return _FinancePanel(
      title: 'Exportación',
      icon: Icons.ios_share_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: () => _copy(context, controller.exportFinancialJson(),
                'JSON financiero copiado.'),
            icon: const Icon(Icons.data_object_rounded),
            label: const Text('Copiar JSON IA/MCP'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _copy(context, controller.exportFinancialCsv(),
                'CSV financiero copiado.'),
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Copiar CSV Excel'),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ExpenseEditorDialog extends StatefulWidget {
  const _ExpenseEditorDialog({
    required this.controller,
    required this.initialDate,
    this.initialExpense,
  });

  final TodoWorkspace controller;
  final DateTime initialDate;
  final Expense? initialExpense;

  @override
  State<_ExpenseEditorDialog> createState() => _ExpenseEditorDialogState();
}

class _ExpenseEditorDialogState extends State<_ExpenseEditorDialog> {
  late final TextEditingController _concept;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _date;
  late String _categoryId;
  String? _paymentMethodId;
  String? _projectId;
  bool _recurring = false;

  @override
  void initState() {
    super.initState();
    final expense = widget.initialExpense;
    _date = expense?.date ?? widget.initialDate;
    _concept = TextEditingController(text: expense?.concept ?? '');
    _amount = TextEditingController(
      text:
          expense == null ? '' : expense.amount.toString().replaceAll('.', ','),
    );
    _note = TextEditingController(text: expense?.note ?? '');
    _categoryId = expense?.categoryId ??
        widget.controller.expenseCategories.firstOrNull?.id ??
        '';
    _paymentMethodId = expense?.paymentMethodId ??
        widget.controller.paymentMethods.firstOrNull?.id;
    _projectId = expense?.projectIds.firstOrNull;
    _recurring = expense?.isRecurringInstance ?? false;
  }

  @override
  void dispose() {
    _concept.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialExpense != null;
    return AlertDialog(
      title: Text(editing ? 'Editar gasto' : 'Nuevo gasto'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: Text(_dateLabel(_date)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Importe'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _concept,
                decoration: const InputDecoration(labelText: 'Concepto'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoryId.isEmpty ? null : _categoryId,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: widget.controller.expenseCategories
                    .where((category) =>
                        category.isActive ||
                        category.id == widget.initialExpense?.categoryId)
                    .map((category) => DropdownMenuItem<String>(
                          value: category.id,
                          child: Text(category.name),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _categoryId = value ?? ''),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _paymentMethodId,
                decoration: const InputDecoration(labelText: 'Método de pago'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Sin método')),
                  ...widget.controller.paymentMethods
                      .where((method) =>
                          method.isActive ||
                          method.id == widget.initialExpense?.paymentMethodId)
                      .map((method) => DropdownMenuItem<String?>(
                            value: method.id,
                            child: Text(method.name),
                          )),
                ],
                onChanged: (value) => setState(() => _paymentMethodId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _projectId,
                decoration:
                    const InputDecoration(labelText: 'Proyecto asociado'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Sin proyecto')),
                  ...widget.controller.projects.map(
                    (project) => DropdownMenuItem<String?>(
                      value: project.id,
                      child: Text(project.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _projectId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Nota opcional'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Gasto recurrente'),
                value: _recurring,
                onChanged: (value) => setState(() => _recurring = value),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recibo o archivo: preparado para una version futura.',
                  style: TextStyle(color: context.visuals.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(editing ? 'Guardar cambios' : 'Guardar gasto'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 5),
      lastDate: DateTime(_date.year + 5),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  void _save() {
    final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0 || _categoryId.isEmpty) {
      return;
    }
    final projects = _projectId == null ? <String>[] : <String>[_projectId!];
    final existing = widget.initialExpense;
    if (existing == null) {
      widget.controller.createExpense(
        date: _date,
        concept: _concept.text,
        amount: amount,
        categoryId: _categoryId,
        paymentMethodId: _paymentMethodId,
        projectIds: projects,
        note: _note.text,
        isRecurringInstance: _recurring,
      );
    } else {
      widget.controller.updateExpense(
        existing.copyWith(
          date: _date,
          concept:
              _concept.text.trim().isEmpty ? 'Gasto' : _concept.text.trim(),
          amount: amount,
          categoryId: _categoryId,
          paymentMethodId: _paymentMethodId,
          clearPaymentMethodId: _paymentMethodId == null,
          projectIds: projects,
          note: _note.text.trim(),
          clearNote: _note.text.trim().isEmpty,
          isRecurringInstance: _recurring,
        ),
      );
    }
    Navigator.of(context).pop();
  }
}

class _ExpenseCategoryDialog extends StatefulWidget {
  const _ExpenseCategoryDialog({required this.controller});

  final TodoWorkspace controller;

  @override
  State<_ExpenseCategoryDialog> createState() => _ExpenseCategoryDialogState();
}

class _ExpenseCategoryDialogState extends State<_ExpenseCategoryDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva categoría financiera'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nombre')),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        FilledButton(onPressed: _save, child: const Text('Crear')),
      ],
    );
  }

  void _save() {
    if (_name.text.trim().isEmpty) return;
    widget.controller.createExpenseCategory(
      name: _name.text,
      colorValue: const Color(0xFF70835D).toARGB32(),
      icon: Icons.label_rounded,
    );
    Navigator.of(context).pop();
  }
}

class _PaymentMethodDialog extends StatefulWidget {
  const _PaymentMethodDialog({required this.controller});

  final TodoWorkspace controller;

  @override
  State<_PaymentMethodDialog> createState() => _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends State<_PaymentMethodDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo método de pago'),
      content: TextField(
        controller: _name,
        decoration: const InputDecoration(labelText: 'Nombre'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        FilledButton(onPressed: _save, child: const Text('Crear')),
      ],
    );
  }

  void _save() {
    if (_name.text.trim().isEmpty) return;
    widget.controller.createPaymentMethod(
      name: _name.text,
      icon: Icons.credit_card_rounded,
      colorValue: const Color(0xFF6C7B8E).toARGB32(),
    );
    Navigator.of(context).pop();
  }
}

class _FixedPaymentDialog extends StatefulWidget {
  const _FixedPaymentDialog({required this.controller});

  final TodoWorkspace controller;

  @override
  State<_FixedPaymentDialog> createState() => _FixedPaymentDialogState();
}

class _FixedPaymentDialogState extends State<_FixedPaymentDialog> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  String? _categoryId;
  String? _paymentMethodId;
  FixedPaymentFrequency _frequency = FixedPaymentFrequency.monthly;
  late DateTime _nextDate;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.controller.expenseCategories.firstOrNull?.id;
    _paymentMethodId = widget.controller.paymentMethods.firstOrNull?.id;
    _nextDate = DateTime.now();
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo pago fijo'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Importe'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: widget.controller.expenseCategories
                    .map((category) => DropdownMenuItem(
                        value: category.id, child: Text(category.name)))
                    .toList(),
                onChanged: (value) => setState(() => _categoryId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _paymentMethodId,
                decoration: const InputDecoration(labelText: 'Método'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Sin método')),
                  ...widget.controller.paymentMethods.map((method) =>
                      DropdownMenuItem<String?>(
                          value: method.id, child: Text(method.name))),
                ],
                onChanged: (value) => setState(() => _paymentMethodId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<FixedPaymentFrequency>(
                initialValue: _frequency,
                decoration: const InputDecoration(labelText: 'Frecuencia'),
                items: FixedPaymentFrequency.values
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(_frequencyLabel(value)),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _frequency = value ?? _frequency),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text('Próxima fecha: ${_dateLabel(_nextDate)}'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        FilledButton(onPressed: _save, child: const Text('Crear')),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _nextDate = picked);
    }
  }

  void _save() {
    final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (_name.text.trim().isEmpty || amount == null || _categoryId == null) {
      return;
    }
    widget.controller.createFixedPayment(
      name: _name.text,
      amount: amount,
      categoryId: _categoryId!,
      paymentMethodId: _paymentMethodId,
      frequency: _frequency,
      nextPaymentDate: _nextDate,
    );
    Navigator.of(context).pop();
  }
}

class _FinancePanel extends StatelessWidget {
  const _FinancePanel({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: _SettingsPanelCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0DE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF70835D), size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _FinanceMetric extends StatelessWidget {
  const _FinanceMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: _SettingsPanelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: context.visuals.textMuted)),
            const SizedBox(height: 8),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 24)),
          ],
        ),
      ),
    );
  }
}

class _FinanceListRow extends StatelessWidget {
  const _FinanceListRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onToggle,
    this.active = true,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onToggle;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7D9C8)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.16),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(color: context.visuals.textMuted)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (onToggle != null) ...[
            const SizedBox(width: 8),
            Switch(value: active, onChanged: (_) => onToggle!()),
          ],
        ],
      ),
    );
  }
}

class _IconShell extends StatelessWidget {
  const _IconShell({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onTap,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFFFFCF8),
        foregroundColor: const Color(0xFF2D2A25),
      ),
    );
  }
}

class _DashboardCell extends StatelessWidget {
  const _DashboardCell(
    this.text, {
    this.height = 42,
    this.strong = false,
    this.highlighted = false,
    this.align = TextAlign.right,
    this.textColor,
  });

  final String text;
  final double height;
  final bool strong;
  final bool highlighted;
  final TextAlign align;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final content = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: align,
      style: TextStyle(
        color: textColor ?? const Color(0xFF201D19),
        fontSize: 14,
        fontFeatures: const [FontFeature.tabularFigures()],
        fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
      ),
    );
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        child: Align(
          alignment: align == TextAlign.left
              ? Alignment.centerLeft
              : Alignment.centerRight,
          child: highlighted
              ? Container(
                  constraints: const BoxConstraints(minWidth: 34),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE6A3),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    child: content,
                  ),
                )
              : content,
        ),
      ),
    );
  }
}

class _DashboardCategoryCell extends StatelessWidget {
  const _DashboardCategoryCell({required this.category});

  final ExpenseCategory category;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          children: [
            Icon(category.icon, size: 18, color: category.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF201D19),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryHero extends StatelessWidget {
  const _SummaryHero({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0E7DA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: context.visuals.textMuted)),
          const SizedBox(height: 6),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontSize: 30)),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(color: context.visuals.textMuted))),
          const SizedBox(width: 10),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

String _money(double value) {
  final fixed = value.toStringAsFixed(2).replaceAll('.', ',');
  return '$fixed €';
}

String _signedMoney(double value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${_money(value)}';
}

String _compactMoney(double value) {
  if (value == 0) {
    return '0';
  }
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 0.005) {
    return rounded.toInt().toString();
  }
  return value.toStringAsFixed(2).replaceAll('.', ',');
}

String _compactMoneyOrDash(double value) {
  if (value == 0) {
    return '–';
  }
  return _compactMoney(value);
}

String _compactSignedMoney(double value) {
  if (value == 0) {
    return '0';
  }
  final sign = value > 0 ? '+' : '';
  return '$sign${_compactMoney(value)}';
}

String _dateLabel(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _expenseMonthName(int month) {
  const names = <String>[
    '',
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  return names[month.clamp(1, 12)];
}

String _expenseMonthShort(int month) {
  const names = <String>[
    '',
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];
  return names[month.clamp(1, 12)];
}

String _frequencyLabel(FixedPaymentFrequency frequency) {
  return switch (frequency) {
    FixedPaymentFrequency.weekly => 'Semanal',
    FixedPaymentFrequency.monthly => 'Mensual',
    FixedPaymentFrequency.yearly => 'Anual',
    FixedPaymentFrequency.custom => 'Personalizada',
  };
}

String _projectLabel(TodoWorkspace controller, Expense expense) {
  if (expense.projectIds.isEmpty) {
    return '-';
  }
  return expense.projectIds
      .map(controller.projectById)
      .whereType<ProjectModel>()
      .map((project) => project.name)
      .join(', ');
}
