import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'mobile_task_controller.dart';

class MobileShoppingPage extends StatelessWidget {
  const MobileShoppingPage({required this.controller, super.key});

  final MobileTaskController controller;

  @override
  Widget build(BuildContext context) {
    final lists = controller.shoppingLists;
    return RefreshIndicator(
      onRefresh: controller.sync,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Text('Compra', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          const Text('Tus listas y precios se conservan sin conexión.'),
          const SizedBox(height: 18),
          if (lists.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Todavía no hay listas. Crea una en Recetas del ordenador y actualiza el móvil cuando estés en la misma red.',
                ),
              ),
            ),
          for (final list in lists) ...[
            _ShoppingListCard(controller: controller, list: list),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ShoppingListCard extends StatelessWidget {
  const _ShoppingListCard({required this.controller, required this.list});

  final MobileTaskController controller;
  final TaskModel list;

  @override
  Widget build(BuildContext context) {
    final items = controller.snapshot?.subtasksOf(list) ?? const <TaskModel>[];
    final progress = controller.shoppingProgress;
    final bought =
        items.where((item) => progress.isBought(list.id, item.id)).length;
    final computed = progress.totalCents(list.id, items.map((item) => item.id));
    final receiptTotal = progress.receiptTotalCents(list.id);
    return Card(
      child: ExpansionTile(
        key: PageStorageKey(list.id),
        initiallyExpanded: true,
        leading: const Icon(Icons.shopping_cart_outlined),
        title: Text(list.title),
        subtitle: Text('$bought de ${items.length} productos comprados'),
        children: [
          if (list.description?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(list.description!),
              ),
            ),
          for (final item in items)
            ListTile(
              leading: Checkbox(
                value: progress.isBought(list.id, item.id),
                onChanged: (value) => controller.setShoppingBought(
                  list.id,
                  item.id,
                  value ?? false,
                ),
              ),
              title: Text(
                item.title,
                style: progress.isBought(list.id, item.id)
                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                    : null,
              ),
              subtitle: item.description?.isNotEmpty == true
                  ? Text(item.description!)
                  : null,
              onTap: () => controller.setShoppingBought(
                list.id,
                item.id,
                !progress.isBought(list.id, item.id),
              ),
              trailing: TextButton(
                onPressed: () => _editPrice(
                  context,
                  title: 'Precio de ${item.title}',
                  initialCents: progress.priceCents(list.id, item.id),
                  onSaved: (cents) =>
                      controller.setShoppingPrice(list.id, item.id, cents),
                ),
                child: Text(progress.priceCents(list.id, item.id) == null
                    ? 'Precio'
                    : _money(progress.priceCents(list.id, item.id)!)),
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                Expanded(child: Text('Suma de precios: ${_money(computed)}')),
                TextButton(
                  onPressed: () => _editPrice(
                    context,
                    title: 'Total del ticket',
                    initialCents: receiptTotal,
                    onSaved: (cents) =>
                        controller.setShoppingReceiptTotal(list.id, cents),
                  ),
                  child: Text(receiptTotal == null
                      ? 'Anotar total'
                      : 'Ticket: ${_money(receiptTotal)}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _money(int cents) =>
    '${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';

Future<void> _editPrice(
  BuildContext context, {
  required String title,
  required int? initialCents,
  required Future<void> Function(int?) onSaved,
}) async {
  final field = TextEditingController(
    text: initialCents == null
        ? ''
        : (initialCents / 100).toStringAsFixed(2).replaceAll('.', ','),
  );
  String? error;
  final result = await showDialog<int?>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: field,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Importe en euros',
            hintText: '0,00',
            errorText: error,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final raw = field.text.trim().replaceAll(',', '.');
              final parsed = raw.isEmpty ? null : double.tryParse(raw);
              if (raw.isNotEmpty &&
                  (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(raw) ||
                      parsed == null ||
                      parsed > 1000000)) {
                setDialogState(() => error = 'Introduce un importe válido.');
                return;
              }
              Navigator.pop(
                  dialogContext, parsed == null ? -1 : (parsed * 100).round());
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
  field.dispose();
  if (result != null) await onSaved(result == -1 ? null : result);
}
