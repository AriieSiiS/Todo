part of 'app_shell.dart';

String _priceDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

class _ShoppingTrackingSummary extends StatelessWidget {
  const _ShoppingTrackingSummary({required this.controller});
  final TodoWorkspace controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller.priceTracking,
        builder: (context, _) {
          final service = controller.priceTracking;
          if (!service.enabled) return const SizedBox.shrink();
          return Row(children: [
            Icon(
                service.available
                    ? Icons.notifications_active_outlined
                    : Icons.cloud_off_outlined,
                size: 18,
                color: context.visuals.textMuted),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
                    service.available
                        ? '${service.activeCount} en seguimiento · Revisión cada 24 h · Sin IA'
                        : 'Seguimiento de precios sin conexión',
                    style: TextStyle(
                        fontSize: 12, color: context.visuals.textMuted))),
            TextButton.icon(
                onPressed: () => _showShoppingPriceAlerts(context, controller),
                icon: const Icon(Icons.notifications_none_rounded, size: 18),
                label: Text(
                    'Avisos${service.unreadCount == 0 ? '' : ' (${service.unreadCount})'}')),
            IconButton(
                tooltip: 'Actualizar seguimiento',
                onPressed: service.refresh,
                icon: const Icon(Icons.refresh_rounded, size: 18)),
          ]);
        },
      );
}

class _ShoppingTrackingPanel extends StatefulWidget {
  const _ShoppingTrackingPanel({required this.controller, required this.item});
  final TodoWorkspace controller;
  final ShoppingItem item;
  @override
  State<_ShoppingTrackingPanel> createState() => _ShoppingTrackingPanelState();
}

class _ShoppingTrackingPanelState extends State<_ShoppingTrackingPanel> {
  bool _busy = false;
  String _feedback = '';

  Future<void> _run(Future<void> Function() action,
      {String success = ''}) async {
    setState(() {
      _busy = true;
      _feedback = '';
    });
    try {
      await action();
      if (mounted) setState(() => _feedback = success);
    } catch (error) {
      if (mounted)
        setState(() => _feedback = error is StateError
            ? error.message.toString()
            : 'No se pudo contactar con el servicio de precios.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.controller.priceTracking,
        builder: (context, _) {
          final service = widget.controller.priceTracking;
          final item = widget.item;
          final watch = service.watch(item.id);
          final tracking = watch?.enabled == true;
          final supported = ShoppingPriceService.supports(item);
          final pending =
              !item.archived && item.status != ShoppingStatus.purchased;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.visuals.accent.withValues(alpha: .06),
              border: Border.all(color: context.visuals.panelBorder),
              borderRadius: BorderRadius.circular(14),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.monitor_heart_outlined,
                    size: 18, color: context.visuals.accent),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text('Seguimiento de precio',
                        style: TextStyle(fontWeight: FontWeight.w700))),
                if (_busy)
                  const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ]),
              const SizedBox(height: 8),
              Text(
                  tracking
                      ? 'Cada 24 horas · Sin IA ni suscripciones'
                      : watch == null
                          ? 'Sin activar'
                          : 'Seguimiento pausado',
                  style: TextStyle(
                      fontSize: 12, color: context.visuals.textMuted)),
              if (watch?.currentPrice != null) ...[
                const SizedBox(height: 10),
                Text(_shoppingMoney(watch!.currentPrice!),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 22)),
                if (watch.lastSuccessAt != null)
                  Text('Precio observado: ${_priceDate(watch.lastSuccessAt!)}',
                      style: TextStyle(
                          fontSize: 11, color: context.visuals.textMuted)),
              ] else if (tracking && item.offers.isEmpty) ...[
                const SizedBox(height: 8),
                const Text('Esperando una lectura válida.',
                    style: TextStyle(fontSize: 12)),
              ],
              if (watch?.error.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(watch!.error, style: const TextStyle(fontSize: 12)),
                if (watch.checkedAt != null)
                  Text('Último intento: ${_priceDate(watch.checkedAt!)}',
                      style: TextStyle(
                          fontSize: 11, color: context.visuals.textMuted)),
              ],
              if (item.offers.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final offer in item.offers)
                  _ShoppingOfferPrice(
                      offer: offer,
                      watch: watch?.offers
                          .where((entry) =>
                              _shoppingOfferUrl(entry.url) ==
                              _shoppingOfferUrl(offer.sourceUrl))
                          .firstOrNull),
              ],
              if (!service.available && service.enabled) ...[
                const SizedBox(height: 8),
                Text(service.issue, style: const TextStyle(fontSize: 12)),
              ],
              if (!supported) ...[
                const SizedBox(height: 8),
                const Text(
                    'Añade una ficha exacta de Amazon España para seguir su precio; '
                    'un enlace de búsqueda no sirve.',
                    style: TextStyle(fontSize: 12)),
              ],
              if (!service.notificationsEnabled) ...[
                const SizedBox(height: 8),
                const Text(
                    'Los avisos de Windows están desactivados en Ajustes. '
                    'Los cambios se guardarán en Compras.',
                    style: TextStyle(fontSize: 12)),
              ],
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  onPressed: _busy ||
                          !service.available ||
                          (!tracking && (!supported || !pending))
                      ? null
                      : () => _run(() => service.setTracking(item, !tracking)),
                  icon: Icon(
                      tracking
                          ? Icons.pause_rounded
                          : Icons.notifications_active_outlined,
                      size: 16),
                  label: Text(tracking ? 'Pausar' : 'Seguir precio'),
                ),
                if (tracking)
                  TextButton(
                      onPressed: _busy || !service.available
                          ? null
                          : () => _run(() => service.checkNow(item.id),
                              success:
                                  'Revisión solicitada. El resultado aparecerá en unos segundos.'),
                      child: const Text('Revisar ahora')),
              ]),
              if (_feedback.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_feedback, style: const TextStyle(fontSize: 12)),
              ],
              if (item.offers.isEmpty && watch?.history.isNotEmpty == true)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: const Text('Historial de precios',
                      style: TextStyle(fontSize: 13)),
                  children: [
                    for (final entry in watch!.history)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            Expanded(
                                child: Text(_priceDate(entry.checkedAt),
                                    style: const TextStyle(fontSize: 12))),
                            Text(_shoppingMoney(entry.price),
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                          ])),
                  ],
                ),
              const SizedBox(height: 6),
              Text(
                  'Precio visible sin cupones ni envío. Requiere el PC encendido.',
                  style: TextStyle(
                      fontSize: 11, color: context.visuals.textMuted)),
            ]),
          );
        },
      );
}

String _shoppingOfferUrl(String value) {
  final asin = RegExp(r'/(?:dp|gp/product)/([a-zA-Z0-9]{10})(?:/|$)')
      .firstMatch(Uri.tryParse(value)?.path ?? '');
  return asin?.group(1)?.toUpperCase() ?? value;
}

class _ShoppingOfferPrice extends StatelessWidget {
  const _ShoppingOfferPrice({required this.offer, this.watch});
  final ShoppingOffer offer;
  final PriceWatch? watch;

  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(offer.name, style: const TextStyle(fontSize: 13)),
        subtitle: Text(watch?.currentPrice == null
            ? 'Sin precio observado'
            : _shoppingMoney(watch!.currentPrice!)),
        children: [
          if (watch?.lastSuccessAt != null)
            Text('Última lectura: ${_priceDate(watch!.lastSuccessAt!)}',
                style: const TextStyle(fontSize: 11)),
          if (watch?.error.isNotEmpty == true)
            Text(watch!.error, style: const TextStyle(fontSize: 12)),
          for (final entry in watch?.history ?? <PriceObservation>[])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(
                    child: Text(_priceDate(entry.checkedAt),
                        style: const TextStyle(fontSize: 12))),
                Text(_shoppingMoney(entry.price)),
              ]),
            ),
          TextButton.icon(
              onPressed: () => launchUrl(Uri.parse(offer.sourceUrl),
                  mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Abrir esta opción')),
        ],
      );
}

Future<void> _showShoppingPriceAlerts(
    BuildContext context, TodoWorkspace controller) async {
  final service = controller.priceTracking;
  await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
            title: const Text('Avisos de precios'),
            content: SizedBox(
                width: 520,
                height: 400,
                child: AnimatedBuilder(
                  animation: service,
                  builder: (context, _) => service.alerts.isEmpty
                      ? const Center(
                          child: Text(
                              'Todavía no hay cambios de precio registrados.'))
                      : ListView.separated(
                          itemCount: service.alerts.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final alert = service.alerts[index];
                            return ListTile(
                              leading: Icon(alert.price < alert.previousPrice
                                  ? Icons.trending_down_rounded
                                  : Icons.trending_up_rounded),
                              title: Text(alert.name),
                              subtitle: Text(
                                  '${_shoppingMoney(alert.previousPrice)} → ${_shoppingMoney(alert.price)}\n'
                                  '${_priceDate(alert.checkedAt)}${alert.notificationError.isEmpty ? '' : '\n${alert.notificationError}'}'),
                              onTap: controller
                                          .shoppingItemById(alert.itemId) ==
                                      null
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      _showShoppingDetail(
                                          context, controller, alert.itemId);
                                    },
                            );
                          },
                        ),
                )),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'))
            ],
          ));
  if (service.available) {
    try {
      await service.markAlertsRead();
    } catch (_) {/* El historial permanece visible. */}
  }
}
