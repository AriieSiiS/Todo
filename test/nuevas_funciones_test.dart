import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/app/app_launch_intent.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shell/app_shell.dart';
import 'package:todo/services/task_scheduler_service.dart';

TodoWorkspace _restaurar(TodoWorkspace origen) {
  final snapshot = AppStateSnapshot.fromJson(
    jsonDecode(origen.exportSnapshot().toPrettyJson()) as Map<String, dynamic>,
  );
  return TodoWorkspace.createForTest(snapshot: snapshot);
}

void _pantallaGrande(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Monta la página como lo hace el shell: escuchando al workspace.
Future<void> _mostrar(
  WidgetTester tester,
  TodoWorkspace controller,
  Widget Function() pagina,
) async {
  await tester.pumpWidget(MaterialApp(
    theme: buildTodoTheme(),
    home: Scaffold(
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => pagina(),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Diario', () {
    test('solo hay una entrada por día y se conserva al reiniciar', () {
      final controller = TodoWorkspace.createForTest();
      addTearDown(controller.dispose);
      final primera = controller.saveJournalEntry(
        date: DateTime(2026, 10, 1, 18, 30),
        text: '  Primer día  ',
        mood: 4,
      );
      final segunda = controller.saveJournalEntry(
        date: DateTime(2026, 10, 1),
        text: 'Primer día, corregido',
        mood: 9,
      );
      expect(segunda.id, primera.id);
      expect(controller.journalEntries, hasLength(1));
      expect(controller.journalEntries.single.mood, 5, reason: 'se acota a 5');
      expect(controller.journalEntries.single.date, DateTime(2026, 10, 1));

      final restaurado = _restaurar(controller);
      addTearDown(restaurado.dispose);
      expect(restaurado.journalEntries.single.text, 'Primer día, corregido');
    });

    test('recuerda las entradas de la misma fecha en años anteriores', () {
      final controller = TodoWorkspace.createForTest();
      addTearDown(controller.dispose);
      controller
        ..saveJournalEntry(date: DateTime(2025, 10, 18), text: 'Hace un año')
        ..saveJournalEntry(date: DateTime(2024, 10, 18), text: 'Hace dos')
        ..saveJournalEntry(date: DateTime(2025, 10, 19), text: 'Otro día');
      final recuerdos = controller.journalOnThisDay(DateTime(2026, 10, 18));
      expect(recuerdos.map((e) => e.text), ['Hace un año', 'Hace dos']);
      controller.deleteJournalEntry(recuerdos.first.id);
      expect(controller.journalEntries, hasLength(2));
    });

    testWidgets('se escribe, se guarda y aparece en la lista', (tester) async {
      _pantallaGrande(tester);
      final controller = TodoWorkspace.createForTest();
      addTearDown(controller.dispose);
      await _mostrar(tester, controller, () => JournalPage(controller: controller));
      expect(find.text('Todavía no hay entradas'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('journal-write-today')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('journal-mood-4')));
      await tester.enterText(
          find.byKey(const ValueKey('journal-text')), 'Un buen día');
      await tester.tap(find.byKey(const ValueKey('journal-save')));
      await tester.pumpAndSettle();
      expect(controller.journalEntries.single.text, 'Un buen día');
      expect(controller.journalEntries.single.mood, 4);
      expect(find.text('Un buen día'), findsOneWidget);
      expect(find.text('Editar hoy'), findsOneWidget);
    });
  });

  group('Viajes', () {
    test('crean su maleta, ordenan reservas y se ven en el calendario', () {
      final controller = TodoWorkspace.createForTest();
      addTearDown(controller.dispose);
      final viaje = controller.createTrip(
        name: 'Lisboa',
        destination: 'Portugal',
        startDate: DateTime(2026, 11, 5),
        endDate: DateTime(2026, 11, 1),
        createPackingList: true,
      );
      expect(viaje.endDate, viaje.startDate, reason: 'la vuelta no precede');
      expect(controller.wardrobePackingLists, hasLength(1));
      expect(viaje.packingListId, controller.wardrobePackingLists.single.id);

      controller.updateTrip(viaje.id, endDate: DateTime(2026, 11, 9));
      controller.saveTripReservation(
        viaje.id,
        title: 'Hotel',
        kind: TripReservationKind.lodging,
        date: DateTime(2026, 11, 5, 15),
      );
      final reserva = controller.saveTripReservation(
        viaje.id,
        title: 'Vuelo',
        kind: TripReservationKind.flight,
      );
      controller.saveTripReservation(
        viaje.id,
        reservationId: reserva.id,
        title: 'Vuelo de ida',
        kind: TripReservationKind.flight,
        confirmation: 'ABC123',
      );
      final actual = controller.tripById(viaje.id)!;
      expect(actual.durationDays, 5);
      expect(actual.reservations, hasLength(2));
      expect(actual.reservations.last.confirmation, 'ABC123');
      expect(controller.tripsOnDay(DateTime(2026, 11, 7)), hasLength(1));
      expect(controller.tripsOnDay(DateTime(2026, 11, 10)), isEmpty);

      final restaurado = _restaurar(controller);
      addTearDown(restaurado.dispose);
      expect(restaurado.tripById(viaje.id)!.reservations, hasLength(2));
    });

    test('al borrar un viaje se conserva la maleta de Ropa', () async {
      final controller = TodoWorkspace.createForTest();
      addTearDown(controller.dispose);
      final viaje = controller.createTrip(
        name: 'Roma',
        startDate: DateTime(2026, 12, 1),
        endDate: DateTime(2026, 12, 3),
        createPackingList: true,
      );
      await controller.deleteTrip(viaje.id);
      expect(controller.trips, isEmpty);
      expect(controller.wardrobePackingLists, hasLength(1));
    });

    testWidgets('se crea desde la pantalla y muestra su cuenta atrás',
        (tester) async {
      _pantallaGrande(tester);
      final controller = TodoWorkspace.createForTest();
      addTearDown(controller.dispose);
      await _mostrar(tester, controller, () => TripsPage(controller: controller));
      expect(find.text('Aún no hay viajes'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('trips-new')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('trip-name')), 'Oporto');
      await tester.tap(find.byKey(const ValueKey('trip-save')));
      await tester.pumpAndSettle();
      expect(controller.trips.single.name, 'Oporto');
      expect(controller.wardrobePackingLists, hasLength(1));
      expect(find.text('Oporto'), findsOneWidget);
      expect(find.textContaining('Faltan'), findsOneWidget);
    });
  });

  group('Enfoque', () {
    test('el temporizador cuenta, se pausa y se descarta', () {
      final inicio = DateTime(2026, 10, 18, 10);
      final activo = ActiveFocus(
        startedAt: inicio,
        plannedSeconds: 1500,
        runningSince: inicio,
      );
      expect(activo.remainingSeconds(inicio.add(const Duration(minutes: 10))),
          900);
      final pausado = activo.paused(inicio.add(const Duration(minutes: 10)));
      expect(pausado.isRunning, isFalse);
      expect(pausado.remainingSeconds(inicio.add(const Duration(hours: 5))),
          900);
      final reanudado = pausado.resumed(inicio.add(const Duration(hours: 5)));
      expect(
          reanudado.remainingSeconds(
              inicio.add(const Duration(hours: 5, minutes: 5))),
          600);
      expect(ActiveFocus.fromJson(reanudado.toJson())!.accumulatedSeconds, 600);

      final controller = TodoWorkspace.createForTest();
      addTearDown(controller.dispose);
      controller.startFocus(minutes: 25, label: 'Leer');
      expect(controller.activeFocus!.plannedSeconds, 1500);
      controller.pauseFocus();
      expect(controller.activeFocus!.isRunning, isFalse);
      controller.resumeFocus();
      expect(controller.activeFocus!.isRunning, isTrue);
      controller.discardFocus();
      expect(controller.activeFocus, isNull);
      expect(controller.focusSessions, isEmpty);
    });

    test('un temporizador vencido se anota al abrir la app', () {
      final tarea = DateTime.now().subtract(const Duration(minutes: 10));
      final origen = TodoWorkspace.createForTest();
      addTearDown(origen.dispose);
      final creada = origen.createTask(title: 'Estudiar');
      final snapshot = AppStateSnapshot.fromJson({
        ...jsonDecode(origen.exportSnapshot().toPrettyJson())
            as Map<String, dynamic>,
        'activeFocus': ActiveFocus(
          taskId: creada.id,
          label: 'Estudiar',
          startedAt: tarea,
          plannedSeconds: 300,
          runningSince: tarea,
        ).toJson(),
      });
      final controller = TodoWorkspace.createForTest(snapshot: snapshot);
      addTearDown(controller.dispose);
      expect(controller.activeFocus, isNotNull);
      controller.resumeFocusAfterStartup();
      expect(controller.activeFocus, isNull);
      expect(controller.focusSessions, hasLength(1));
      expect(controller.focusSessions.single.actualSeconds, 300);
      expect(controller.focusSessions.single.completed, isTrue);
      expect(controller.focusSecondsForTask(creada.id), 300);
    });

    testWidgets('se inicia desde la pantalla y muestra la cuenta atrás',
        (tester) async {
      _pantallaGrande(tester);
      final controller = TodoWorkspace.createForTest();
      addTearDown(controller.dispose);
      await _mostrar(tester, controller, () => FocusPage(controller: controller));
      await tester.tap(find.byKey(const ValueKey('focus-start')));
      await tester.pump();
      expect(find.byKey(const ValueKey('focus-clock')), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('focus-pause')));
      await tester.pump();
      expect(find.byKey(const ValueKey('focus-resume')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('focus-stop')));
      await tester.pump();
      expect(controller.activeFocus, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('Suscripciones', () {
    test('calculan el coste mensual de cada frecuencia', () {
      final controller = TodoWorkspace.createForTest();
      addTearDown(controller.dispose);
      final categoria = controller.expenseCategories.first.id;
      FixedPayment crear(FixedPaymentFrequency frecuencia, double importe,
              {String? intervalo}) =>
          controller.createFixedPayment(
            name: 'Prueba $frecuencia',
            amount: importe,
            categoryId: categoria,
            frequency: frecuencia,
            customInterval: intervalo,
            nextPaymentDate: DateTime(2026, 10, 20),
          );
      expect(
          controller.fixedPaymentMonthlyCost(
              crear(FixedPaymentFrequency.yearly, 120)),
          closeTo(10, 0.001));
      expect(
          controller.fixedPaymentMonthlyCost(
              crear(FixedPaymentFrequency.weekly, 12)),
          closeTo(52, 0.001));
      expect(
          controller.fixedPaymentMonthlyCost(
              crear(FixedPaymentFrequency.custom, 10, intervalo: '15')),
          closeTo(10 * 365 / 12 / 15, 0.001));
      expect(
          controller.fixedPaymentMonthlyCost(
              crear(FixedPaymentFrequency.custom, 10, intervalo: 'a veces')),
          10);
    });

    test('al registrar el cobro se crea el gasto y avanza la fecha', () {
      final controller = TodoWorkspace.createForTest();
      addTearDown(controller.dispose);
      final pago = controller.createFixedPayment(
        name: 'Seguro',
        amount: 30,
        categoryId: controller.expenseCategories.first.id,
        nextPaymentDate: DateTime(2026, 1, 31),
      );
      final gastosAntes = controller.expenses.length;
      controller.markFixedPaymentPaid(pago.id);
      expect(controller.expenses.length, gastosAntes + 1);
      expect(controller.expenses.last.fixedPaymentId, pago.id);
      expect(controller.expenses.last.date, DateTime(2026, 1, 31));
      final tras = controller.fixedPayments.firstWhere((p) => p.id == pago.id);
      expect(tras.nextPaymentDate, DateTime(2026, 2, 28),
          reason: 'febrero no tiene día 31');
      controller.markFixedPaymentPaid(pago.id);
      expect(
          controller.fixedPayments
              .firstWhere((p) => p.id == pago.id)
              .nextPaymentDate,
          DateTime(2026, 3, 31),
          reason: 'recupera el día original');

      final anual = controller.createFixedPayment(
        name: 'Dominio',
        amount: 12,
        categoryId: controller.expenseCategories.first.id,
        frequency: FixedPaymentFrequency.yearly,
        nextPaymentDate: DateTime(2028, 2, 29),
      );
      controller.markFixedPaymentPaid(anual.id);
      expect(
          controller.fixedPayments
              .firstWhere((p) => p.id == anual.id)
              .nextPaymentDate,
          DateTime(2029, 2, 28));
    });

    test('avisan solo dentro de su antelación y programan la notificación', () {
      final controller = TodoWorkspace.createForTest();
      addTearDown(controller.dispose);
      final hoy = controller.logicalDate();
      final categoria = controller.expenseCategories.first.id;
      FixedPayment pago(String nombre, int dias, {int aviso = 3}) =>
          controller.createFixedPayment(
            name: nombre,
            amount: 9.99,
            categoryId: categoria,
            nextPaymentDate: DateTime(hoy.year, hoy.month, hoy.day + dias),
            reminderDaysBefore: aviso,
          );
      pago('Cercano', 2);
      pago('Lejano', 20);
      pago('Sin aviso', 1, aviso: 0);
      final cercanos = controller.fixedPaymentsDueSoon().map((p) => p.name);
      expect(cercanos, contains('Cercano'));
      expect(cercanos, isNot(contains('Lejano')));
      expect(cercanos, isNot(contains('Sin aviso')));

      final planes = TaskSchedulerService().buildPlans(
        tasks: const [],
        notes: const [],
        daySettings: controller.daySettings,
        notificationSettings:
            const DeviceNotificationSettings(notificationsEnabled: true),
        now: DateTime(hoy.year, hoy.month, hoy.day - 1),
        fixedPayments: controller.fixedPayments,
      );
      final titulos = planes.map((plan) => plan.title).toList();
      expect(titulos, contains('Próximo cobro: Lejano'));
      expect(titulos, isNot(contains('Próximo cobro: Sin aviso')));
      final lejano =
          planes.firstWhere((plan) => plan.title == 'Próximo cobro: Lejano');
      expect(lejano.when.hour, 9);
      expect(lejano.when.day, DateTime(hoy.year, hoy.month, hoy.day + 17).day);
      expect(lejano.body, contains('9,99 €'));
    });

    test('un pago antiguo sin aviso guardado usa 3 días', () {
      final json = FixedPayment(
        id: 'x',
        name: 'Antiguo',
        amount: 5,
        categoryId: 'c',
        nextPaymentDate: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ).toJson()
        ..remove('reminderDaysBefore');
      expect(FixedPayment.fromJson(json).reminderDaysBefore, 3);
    });
  });

  group('Resumen semanal', () {
    test('reúne las áreas de la semana pedida y ninguna otra', () async {
      final controller = TodoWorkspace.createForTest();
      addTearDown(controller.dispose);
      final lunes = DateTime(2026, 3, 2);
      final tarea = controller.createTask(title: 'Pagar el alquiler');
      await controller.completeTask(tarea.id);
      controller.createTask(title: 'Sigue pendiente');
      final gasto = controller.createExpense(
        date: DateTime(2026, 3, 4),
        concept: 'Compra',
        amount: 25.5,
        categoryId: controller.expenseCategories.first.id,
      );
      controller.createExpense(
        date: DateTime(2026, 2, 1),
        concept: 'Antiguo',
        amount: 99,
        categoryId: controller.expenseCategories.first.id,
      );
      controller.saveJournalEntry(
          date: DateTime(2026, 3, 3), text: 'Martes', mood: 5);
      controller.saveJournalEntry(
          date: DateTime(2026, 3, 5), text: 'Jueves', mood: 3);
      controller.createTrip(
        name: 'Lisboa',
        destination: 'Portugal',
        startDate: DateTime(2026, 3, 10),
        endDate: DateTime(2026, 3, 14),
      );
      final resumen = controller.buildWeeklySummary(weekStart: lunes);
      expect(resumen, startsWith('# Resumen de la semana'));
      expect(resumen, contains('2 de marzo – 8 de marzo de 2026'));
      expect(resumen, contains('Total: 25,50 € en 1 gastos.'));
      expect(resumen, isNot(contains('Antiguo')));
      expect(resumen, contains('Entradas: 2 de 7 días. Ánimo medio: 4,0 de 5.'));
      expect(resumen, contains('Lisboa (Portugal)'));
      expect(resumen, contains('No has registrado sesiones.'));
      expect(gasto.amount, 25.5);
      // La tarea de este instante solo cuenta en la semana actual.
      expect(resumen, isNot(contains('Pagar el alquiler')));
      final actual = controller.buildWeeklySummary();
      expect(actual, contains('Pagar el alquiler'));
      expect(actual, isNot(contains('Sigue pendiente')));
    });

    test('es de solo lectura: no cambia el estado guardado', () {
      final controller = TodoWorkspace.createForTest();
      addTearDown(controller.dispose);
      controller.createTask(title: 'Tarea');
      final antes = controller.exportSnapshot().toPrettyJson();
      controller.buildWeeklySummary();
      expect(controller.exportSnapshot().toPrettyJson(), antes);
    });

    testWidgets('se abre desde Completadas y permite ver la semana anterior',
        (tester) async {
      _pantallaGrande(tester);
      final controller = TodoWorkspace.createForTest();
      addTearDown(controller.dispose);
      await _mostrar(tester, controller, () => CompletedPage(controller: controller));
      // Con datos vacíos la tarjeta de estadísticas de Completadas ya
      // desbordaba antes de añadir el botón; no es objeto de esta prueba.
      tester.takeException();
      await tester.tap(find.byKey(const ValueKey('weekly-summary-open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('summary-text')), findsOneWidget);
      expect(find.textContaining('# Resumen de la semana'), findsOneWidget);
      final textoActual = tester
          .widget<SelectableText>(find.byKey(const ValueKey('summary-text')))
          .data;
      await tester.tap(find.byKey(const ValueKey('summary-previous')));
      await tester.pumpAndSettle();
      final textoAnterior = tester
          .widget<SelectableText>(find.byKey(const ValueKey('summary-text')))
          .data;
      expect(textoAnterior, isNot(textoActual));
    });
  });

  group('Captura rápida y modo mini', () {
    test('los argumentos de arranque se reconocen', () {
      expect(AppLaunchIntent.fromArgs(['--quick-capture']).quickCapture, isTrue);
      expect(AppLaunchIntent.fromArgs(['--compact']).compact, isTrue);
      final normal = AppLaunchIntent.fromArgs(['--section=trips']);
      expect(normal.section, AppSection.trips);
      expect(normal.quickCapture, isFalse);
      expect(AppLaunchIntent.fromArgs(['--section=journal']).section,
          AppSection.journal);
      expect(AppLaunchIntent.fromArgs(['--section=focus']).section,
          AppSection.focus);
    });

    test('las secciones nuevas están en la barra y en el orden por defecto',
        () {
      final controller = TodoWorkspace.createForTest();
      addTearDown(controller.dispose);
      expect(controller.visibleNavOrder,
          containsAll([AppSection.journal, AppSection.trips, AppSection.focus]));
    });

    testWidgets('la vista mini añade y completa tareas de hoy', (tester) async {
      tester.view.physicalSize = const Size(380, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TodoWorkspace.createForTest();
      addTearDown(controller.dispose);
      var ampliada = false;
      await tester.pumpWidget(MaterialApp(
        theme: buildTodoTheme(),
        home: CompactTodayView(
          controller: controller,
          onExpand: () => ampliada = true,
          onQuickNote: () {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Nada pendiente para hoy.'), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('compact-input')), 'Llamar al médico');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(controller.tasksForToday().map((t) => t.title),
          contains('Llamar al médico'));
      expect(find.text('Llamar al médico'), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(find.text('Nada pendiente para hoy.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('compact-expand')));
      expect(ampliada, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
