import 'dart:io';

import 'package:flutter/material.dart';

import 'mobile_task_controller.dart';
import 'mobile_wardrobe_snapshot.dart';

class MobileWardrobePage extends StatefulWidget {
  const MobileWardrobePage({super.key, required this.controller});

  final MobileTaskController controller;

  @override
  State<MobileWardrobePage> createState() => _MobileWardrobePageState();
}

class _MobileWardrobePageState extends State<MobileWardrobePage> {
  String _query = '';
  String? _category;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final snapshot = controller.wardrobeSnapshot;
    final items = (snapshot?.items ?? const <MobileWardrobeItem>[])
        .where((item) => !item.archived)
        .where((item) => _category == null || item.category == _category)
        .where((item) {
      final query = _query.trim().toLowerCase();
      if (query.isEmpty) return true;
      return [
        item.name,
        item.category,
        item.material,
        ...item.colors,
        ...item.tags,
      ].join(' ').toLowerCase().contains(query);
    }).toList()
      ..sort((a, b) {
        if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
        final category = a.category.compareTo(b.category);
        return category != 0 ? category : a.name.compareTo(b.name);
      });
    final categories = (snapshot?.items ?? const <MobileWardrobeItem>[])
        .where((item) => !item.archived)
        .map((item) => item.category)
        .toSet()
        .toList()
      ..sort();
    return Column(children: [
      _WardrobeStatus(controller: controller),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Buscar ropa',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
      if (categories.isNotEmpty)
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              ChoiceChip(
                label: const Text('Todas'),
                selected: _category == null,
                onSelected: (_) => setState(() => _category = null),
              ),
              for (final category in categories) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(category),
                  selected: _category == category,
                  onSelected: (_) => setState(() => _category = category),
                ),
              ],
            ],
          ),
        ),
      Expanded(
        child: snapshot == null
            ? const _WardrobeEmpty(
                'Conecta el móvil al PC para cargar tu ropa.')
            : items.isEmpty
                ? const _WardrobeEmpty('No hay prendas con estos filtros.')
                : LayoutBuilder(builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 650 ? 4 : 2;
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        childAspectRatio: .72,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) => _WardrobeCard(
                        item: items[index],
                        controller: controller,
                      ),
                    );
                  }),
      ),
    ]);
  }
}

class MobilePackingPage extends StatefulWidget {
  const MobilePackingPage({super.key, required this.controller});

  final MobileTaskController controller;

  @override
  State<MobilePackingPage> createState() => _MobilePackingPageState();
}

class _MobilePackingPageState extends State<MobilePackingPage> {
  String? _selectedId;
  bool _showExhausted = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final snapshot = controller.wardrobeSnapshot;
    final lists = snapshot?.packingLists ?? const <MobilePackingList>[];
    MobilePackingList? selected;
    for (final list in lists) {
      if (list.id == _selectedId) selected = list;
    }
    if (selected == null) {
      return Column(children: [
        _WardrobeStatus(controller: controller),
        Expanded(
          child: snapshot == null
              ? const _WardrobeEmpty(
                  'Carga tus maletas desde el PC antes del viaje.')
              : lists.isEmpty
                  ? const _WardrobeEmpty('Todavía no hay maletas preparadas.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: lists.length,
                      itemBuilder: (context, index) {
                        final list = lists[index];
                        final remaining = list.entries.fold<int>(
                          0,
                          (sum, entry) =>
                              sum + controller.remainingUnits(list.id, entry),
                        );
                        final total = list.entries
                            .fold<int>(0, (sum, entry) => sum + entry.quantity);
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.luggage_rounded),
                            title: Text(list.name),
                            subtitle: Text(
                              '$remaining de $total unidades disponibles${list.localOnly ? ' · Solo en este móvil' : ''}',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => setState(() => _selectedId = list.id),
                          ),
                        );
                      },
                    ),
        ),
      ]);
    }
    final list = selected;
    final entries = list.entries
        .where((entry) => _showExhausted
            ? controller.remainingUnits(list.id, entry) == 0
            : controller.remainingUnits(list.id, entry) > 0)
        .toList();
    final remaining = list.entries.fold<int>(
      0,
      (sum, entry) => sum + controller.remainingUnits(list.id, entry),
    );
    final exhausted = list.entries
        .where((entry) => controller.remainingUnits(list.id, entry) == 0)
        .length;
    return Column(children: [
      _WardrobeStatus(controller: controller),
      ListTile(
        leading: IconButton(
          tooltip: 'Volver a maletas',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() => _selectedId = null),
        ),
        title: Text(list.name),
        subtitle: Text('$remaining unidades disponibles'),
      ),
      if (list.localOnly)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Esta maleta ya no figura en el PC. Se conserva aquí.'),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          ChoiceChip(
            label: Text('Disponibles ($remaining)'),
            selected: !_showExhausted,
            onSelected: (_) => setState(() => _showExhausted = false),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text('Agotadas ($exhausted)'),
            selected: _showExhausted,
            onSelected: (_) => setState(() => _showExhausted = true),
          ),
        ]),
      ),
      Expanded(
        child: entries.isEmpty
            ? _WardrobeEmpty(_showExhausted
                ? 'No hay prendas agotadas.'
                : 'No quedan prendas disponibles en esta maleta.')
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final item = snapshot?.itemById(entry.itemId);
                  final available = controller.remainingUnits(list.id, entry);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(children: [
                        SizedBox(
                          width: 76,
                          height: 76,
                          child: item == null
                              ? const Icon(Icons.checkroom_outlined)
                              : MobileWardrobeImage(
                                  item: item, controller: controller),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item?.name ?? 'Prenda eliminada',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              Text(
                                  '$available de ${entry.quantity} disponibles'),
                              if (!entry.packed)
                                const Text('Pendiente de preparar en Windows',
                                    style: TextStyle(fontSize: 12)),
                              Wrap(spacing: 4, children: [
                                TextButton.icon(
                                  onPressed: available == 0
                                      ? null
                                      : () => controller.changeUsedUnits(
                                          list.id, entry, 1),
                                  icon: const Icon(Icons.remove_rounded),
                                  label: const Text('Usada'),
                                ),
                                TextButton.icon(
                                  onPressed: available == entry.quantity
                                      ? null
                                      : () => controller.changeUsedUnits(
                                          list.id, entry, -1),
                                  icon: const Icon(Icons.undo_rounded),
                                  label: const Text('Volver a disponible'),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}

class _WardrobeStatus extends StatelessWidget {
  const _WardrobeStatus({required this.controller});

  final MobileTaskController controller;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.wardrobeSnapshot;
    final text = controller.wardrobeSyncing
        ? 'Descargando fotos ${controller.wardrobeDownloaded} de ${controller.wardrobeTotal}…'
        : controller.wardrobeError.isNotEmpty
            ? controller.wardrobeError
            : snapshot == null
                ? 'Ropa todavía no descargada.'
                : controller.wardrobeReady
                    ? 'Lista para viajar sin conexión${controller.missingPhotos > 0 ? ' · ${controller.missingPhotos} fotos no disponibles' : ''}'
                    : 'La descarga sin conexión está incompleta.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed:
              controller.wardrobeSyncing ? null : controller.syncWardrobe,
          icon: const Icon(Icons.sync_rounded),
          label: const Text('Actualizar ropa y maletas'),
        ),
        if (controller.wardrobeSyncing && controller.wardrobeTotal > 0)
          LinearProgressIndicator(
            value: controller.wardrobeDownloaded / controller.wardrobeTotal,
          ),
      ]),
    );
  }
}

class _WardrobeCard extends StatelessWidget {
  const _WardrobeCard({required this.item, required this.controller});

  final MobileWardrobeItem item;
  final MobileTaskController controller;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => _WardrobeDetail(item: item, controller: controller),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: MobileWardrobeImage(item: item, controller: controller),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(item.category,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ]),
        ),
      );
}

class MobileWardrobeImage extends StatelessWidget {
  const MobileWardrobeImage({
    super.key,
    required this.item,
    required this.controller,
    this.original = false,
  });

  final MobileWardrobeItem item;
  final MobileTaskController controller;
  final bool original;

  @override
  Widget build(BuildContext context) => FutureBuilder<File?>(
        future: controller.wardrobeImageFile(item, original: original),
        builder: (context, snapshot) {
          final file = snapshot.data;
          if (file == null) {
            return const Center(
                child: Icon(Icons.checkroom_outlined, size: 42));
          }
          return Image.file(file,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Center(child: Icon(Icons.broken_image_outlined)));
        },
      );
}

class _WardrobeDetail extends StatelessWidget {
  const _WardrobeDetail({required this.item, required this.controller});

  final MobileWardrobeItem item;
  final MobileTaskController controller;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SizedBox(
              height: 320,
              child: MobileWardrobeImage(
                  item: item, controller: controller, original: true),
            ),
            const SizedBox(height: 16),
            Text(item.name, style: Theme.of(context).textTheme.headlineSmall),
            Text(item.category),
            if (item.colors.isNotEmpty)
              ListTile(
                  title: const Text('Colores'),
                  subtitle: Text(item.colors.join(', '))),
            if (item.material.isNotEmpty)
              ListTile(
                  title: const Text('Material'), subtitle: Text(item.material)),
            if (item.seasons.isNotEmpty)
              ListTile(
                  title: const Text('Temporadas'),
                  subtitle: Text(item.seasons.join(', '))),
            if (item.occasions.isNotEmpty)
              ListTile(
                  title: const Text('Ocasiones'),
                  subtitle: Text(item.occasions.join(', '))),
            if (item.tags.isNotEmpty)
              ListTile(
                  title: const Text('Etiquetas'),
                  subtitle: Text(item.tags.join(', '))),
          ],
        ),
      );
}

class _WardrobeEmpty extends StatelessWidget {
  const _WardrobeEmpty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
}
