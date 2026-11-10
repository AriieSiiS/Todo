// Captura las vistas habilitadas con una copia en memoria del snapshot local.
// Solo se ejecuta al indicar CAPTURAS; nunca guarda contenido en Todo.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/app/app_launch_intent.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/providers/todo_providers.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shared/editors.dart';
import 'package:todo/presentation/knowledge/knowledge_workspace_page.dart';
import 'package:todo/presentation/shell/app_shell.dart';

const _salida = String.fromEnvironment('CAPTURAS');
const _snapshot = String.fromEnvironment('SNAPSHOT',
    defaultValue: 'C:/Users/aries/Documents/Todo/runtime/todo_state.json');
const _seleccion = String.fromEnvironment('VISTAS');
// Tamaño de la ventana maximizada: 1920x1032 (1080p) o 2560x1392 (2K).
const _ancho = int.fromEnvironment('ANCHO', defaultValue: 2048);
const _alto = int.fromEnvironment('ALTO', defaultValue: 1104);

void main() {
  testWidgets('revisión visual de las vistas actuales', (tester) async {
    if (_salida.isEmpty) return;
    final sombrasAnteriores = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = sombrasAnteriores);
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    final fuentes =
        Directory('${Platform.environment['APPDATA']}/com.example/todo');
    const codec = StandardMessageCodec();
    final manifiesto = Map<Object?, Object?>.from(
        codec.decodeMessage(await rootBundle.load('AssetManifest.bin')) as Map);
    final archivosFuente = <String, ByteData>{};
    for (final archivo in fuentes.listSync().whereType<File>()) {
      final nombre = archivo.uri.pathSegments.last;
      if (!nombre.endsWith('.ttf') ||
          !(nombre.startsWith('PlusJakartaSans_') ||
              nombre.startsWith('CormorantGaramond_'))) {
        continue;
      }
      final partes = nombre.split('_');
      final variante = partes[1] == '700' ? 'Bold' : 'Regular';
      final recurso = 'capturas_fuentes/${partes[0]}-$variante.ttf';
      archivosFuente[recurso] = archivo.readAsBytesSync().buffer.asByteData();
      manifiesto[recurso] = [
        {'asset': recurso}
      ];
    }
    final mensajero =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    mensajero.setMockMessageHandler('flutter/assets', (mensaje) async {
      final recurso = utf8.decode(mensaje!.buffer
          .asUint8List(mensaje.offsetInBytes, mensaje.lengthInBytes));
      if (recurso == 'AssetManifest.bin') {
        return codec.encodeMessage(manifiesto);
      }
      if (archivosFuente.containsKey(recurso)) return archivosFuente[recurso];
      return mensajero.delegate.send('flutter/assets', mensaje);
    });
    for (final recurso in {
      'Roboto':
          'C:/src/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      'MaterialIcons':
          'C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final archivo = File(recurso.value);
      if (!archivo.existsSync()) continue;
      final cargador = FontLoader(recurso.key);
      cargador
          .addFont(Future.value(archivo.readAsBytesSync().buffer.asByteData()));
      await cargador.load();
    }
    Directory(_salida).createSync(recursive: true);
    final datos =
        jsonDecode(File(_snapshot).readAsStringSync()) as Map<String, dynamic>;
    final visibilidad = AppStateSnapshot.fromJson(datos).visibilitySettings;
    final registro = <Map<String, dynamic>>[];
    final fallos = <String>[];
    final tamano = Size(_ancho.toDouble(), _alto.toDouble());
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final limite = GlobalKey();
    late TodoWorkspace controller;
    late BuildContext contexto;
    Finder pagina = find.byType(AppShell);
    var prefijo = '';

    Future<void> estabilizar() async {
      for (var ciclo = 0; ciclo < 4; ciclo++) {
        await tester.pump(const Duration(milliseconds: 120));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 120));
        });
      }
      await tester.pump(const Duration(milliseconds: 300));
      Object? error;
      while ((error = tester.takeException()) != null) {
        fallos.add('$prefijo: $error');
      }
    }

    Future<void> capturar(String nombre) async {
      await estabilizar();
      final imagenes = find
          .byType(Image)
          .evaluate()
          .map((elemento) => (elemento.widget as Image).image)
          .toSet();
      await tester.runAsync(() async {
        await Future.wait(imagenes.map((proveedor) =>
                precacheImage(proveedor, contexto, onError: (_, __) {})))
            .timeout(const Duration(milliseconds: 500), onTimeout: () => []);
      });
      await estabilizar();
      await tester.runAsync(() async {
        final render =
            limite.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final imagen = await render.toImage(pixelRatio: 1);
        final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
        File('$_salida/$prefijo-$nombre.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
        imagen.dispose();
      });
      registro.add({
        'vista': '$prefijo-$nombre',
        'ancho': tamano.width,
        'alto': tamano.height
      });
      debugPrint('CAPTURA $prefijo-$nombre');
    }

    Future<bool> pulsar(String texto) async {
      var objetivo =
          find.descendant(of: pagina, matching: find.text(texto)).hitTestable();
      final etiquetaTab = find
          .descendant(
              of: find.descendant(of: pagina, matching: find.byType(Tab)),
              matching: find.text(texto))
          .hitTestable();
      if (etiquetaTab.evaluate().isNotEmpty) objetivo = etiquetaTab;
      if (objetivo.evaluate().isEmpty &&
          find.byType(Dialog).evaluate().isNotEmpty) {
        objetivo = find
            .descendant(
                of: find.byType(Dialog).last, matching: find.text(texto))
            .hitTestable();
      }
      if (objetivo.evaluate().isEmpty) return false;
      await tester.tap(objetivo.first);
      await estabilizar();
      return true;
    }

    Future<void> cerrarDialogo() async {
      final navegacion = Navigator.of(contexto);
      if (navegacion.canPop()) navegacion.pop();
      await estabilizar();
    }

    controller = (await tester.runAsync(() async {
      final copia = TodoWorkspace.createForTest(
          snapshot: AppStateSnapshot.fromJson(datos));
      await Future<void>.delayed(const Duration(seconds: 1));
      return copia;
    }))!;
    final claveProveedor = UniqueKey();
    for (final brillo in [Brightness.dark, Brightness.light]) {
      final tema = brillo == Brightness.dark ? 'oscuro' : 'claro';
      controller.setDarkMode(brillo == Brightness.dark);
      final apariencia = buildTodoTheme(brightness: brillo);
      await tester.runAsync(() async {
        await GoogleFonts.pendingFonts();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpWidget(ProviderScope(
        key: claveProveedor,
        overrides: [todoWorkspaceProvider.overrideWith((ref) => controller)],
        child: RepaintBoundary(
          key: limite,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: apariencia,
            locale: const Locale('es', 'ES'),
            supportedLocales: const [Locale('es', 'ES')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              AppFlowyEditorLocalizations.delegate,
            ],
            home: Builder(builder: (ctx) {
              contexto = ctx;
              return AppShell(launchIntent: AppLaunchIntent.fromArgs([]));
            }),
          ),
        ),
      ));
      for (final seccion in TodoWorkspace.defaultNavOrder) {
        if (!visibilidad.sectionVisible(seccion)) continue;
        if (_seleccion.isNotEmpty &&
            !_seleccion.split(',').contains(seccion.name)) {
          continue;
        }
        prefijo = '$tema-${seccion.name}';
        controller.setSection(seccion);
        pagina = find.byType(switch (seccion) {
          AppSection.today => TodayPage,
          AppSection.inbox => InboxPage,
          AppSection.projects => ProjectsPage,
          AppSection.categories => CategoriesPage,
          AppSection.calendar => CalendarPage,
          AppSection.library => LibraryPage,
          AppSection.miniatures => MiniaturesPage,
          AppSection.wardrobe => WardrobePage,
          AppSection.household => HouseholdPage,
          AppSection.completed => CompletedPage,
          AppSection.settings => SettingsPage,
          _ => AppShell,
        });
        if (seccion == AppSection.library) {
          await estabilizar();
          await pulsar('Biblioteca');
        }
        await capturar('principal');
        if (seccion == AppSection.today) {
          unawaited(showTaskEditor(contexto, controller));
          await capturar('nueva-tarea');
          final fecha = find
              .descendant(
                  of: find.byType(Dialog).last,
                  matching: find.byIcon(Icons.calendar_today_outlined))
              .hitTestable();
          if (fecha.evaluate().isNotEmpty) {
            await tester.tap(fecha.first);
            await capturar('selector-fecha');
            await cerrarDialogo();
          }
          if (await pulsar('Sin hora')) {
            await capturar('selector-hora');
            await cerrarDialogo();
          }
          await cerrarDialogo();
          if (await pulsar('Filtrar')) {
            await capturar('filtros');
            await cerrarDialogo();
          }
          if (await pulsar('Ordenar')) {
            await capturar('orden');
            await cerrarDialogo();
          }
        }
        if (seccion == AppSection.miniatures &&
            controller.miniatureKits.isNotEmpty) {
          final caja = controller.miniatureKits.first;
          await tester.tap(find
              .byKey(ValueKey('miniature-card-${caja.id}'))
              .hitTestable()
              .first);
          await capturar('ficha');
          final pestanas = find.descendant(
              of: find.byType(TabBar).first, matching: find.byType(Tab));
          for (final (indice, nombre) in [
            (1, 'montaje'),
            (2, 'pintura'),
            (3, 'figuras'),
            (4, 'galeria'),
          ]) {
            if (pestanas.evaluate().length <= indice) break;
            await tester.tap(pestanas.at(indice));
            await capturar(nombre);
          }
          await tester.tap(pestanas.at(0));
          await estabilizar();
          if (await pulsar('Editar')) {
            await capturar('editar-caja');
            await cerrarDialogo();
          }
          await tester.tap(find.byKey(const ValueKey('miniature-back')));
          await estabilizar();
        }
        if (seccion == AppSection.calendar) {
          for (final vista in ['Semana', 'Agenda', 'Mes']) {
            if (await pulsar(vista)) await capturar(vista.toLowerCase());
          }
        }
        if (seccion == AppSection.library) {
          for (final estado in [
            'En curso',
            'Pendientes',
            'Completados',
            'Todo'
          ]) {
            if (await pulsar(estado)) {
              await capturar(estado.toLowerCase().replaceAll(' ', '-'));
            }
          }
          if (await pulsar('Propósitos')) await capturar('propositos');
          await pulsar('Biblioteca');
          await pulsar('Todo');
          for (final tipo in ['Todas', 'Juegos', 'Libros', 'Pelis y series']) {
            if (await pulsar(tipo)) {
              await capturar('tipo-${tipo.toLowerCase().replaceAll(' ', '-')}');
            }
          }
          await pulsar('Libros');
          final club =
              find.byKey(const ValueKey('library-reading-club')).hitTestable();
          if (club.evaluate().isNotEmpty) {
            await tester.tap(club.first);
            await pulsar('Por clubes');
            await capturar('club-de-lectura');
            if (await pulsar('Por fecha')) {
              await capturar('club-por-fecha');
              await pulsar('Por clubes');
            }
            final opciones = find
                .descendant(
                    of: find.byType(Dialog).last,
                    matching: find.byIcon(Icons.more_vert_rounded))
                .hitTestable();
            if (opciones.evaluate().isNotEmpty) {
              await tester.tap(opciones.first);
              await capturar('club-menu');
              await cerrarDialogo();
            }
            if (await pulsar('Añadir libro')) {
              await capturar('club-anadir');
              await cerrarDialogo();
            }
            await cerrarDialogo();
          }
          await pulsar('En curso');
          for (final libro in controller.libraryItems
              .where((item) => item.type == LibraryItemType.book)) {
            var portada = find
                .byKey(ValueKey('library-cover-card-${libro.id}'))
                .hitTestable();
            if (portada.evaluate().isEmpty) {
              portada = find
                  .descendant(of: pagina, matching: find.text(libro.title))
                  .hitTestable();
            }
            if (portada.evaluate().isEmpty) continue;
            await tester.tap(portada.first);
            await capturar('ficha-libro');
            for (final tab in ['Citas', 'Estadísticas', 'Información']) {
              if (await pulsar(tab)) {
                await capturar('ficha-${tab.toLowerCase()}');
              }
            }
            if (await pulsar('Editar')) await capturar('editar-libro');
            await cerrarDialogo();
            await cerrarDialogo();
            break;
          }
          if (controller.libraryItems.isNotEmpty) {
            controller.openKnowledgeWorkspace(controller.libraryItems.first);
            pagina = find.byType(KnowledgeWorkspacePage);
            await capturar('documentacion');
            controller.closeKnowledgeWorkspace();
            pagina = find.byType(LibraryPage);
            await estabilizar();
          }
        }
        if (seccion == AppSection.wardrobe || seccion == AppSection.household) {
          for (final tab in AppVisibilitySettings.tabs[seccion]!.entries) {
            if (tab.key == 'twin') continue;
            if (await pulsar(tab.value)) await capturar(tab.key);
          }
          if (seccion == AppSection.wardrobe) {
            await pulsar('Armario');
            for (final prenda in controller.wardrobeItems) {
              if (!await pulsar(prenda.name)) continue;
              await capturar('ficha-prenda');
              if (await pulsar('Editar')) {
                await capturar('editar-prenda');
                await cerrarDialogo();
              }
              await cerrarDialogo();
              break;
            }
            if (await pulsar('Añadir prenda')) {
              await capturar('nueva-prenda');
              await cerrarDialogo();
            }
          } else {
            await pulsar('Inventario');
            for (final articulo in controller.householdItems) {
              if (!await pulsar(articulo.name)) continue;
              await capturar('ficha-articulo');
              if (await pulsar('Editar')) {
                await capturar('editar-articulo');
                await cerrarDialogo();
              }
              await cerrarDialogo();
              break;
            }
            if (await pulsar('Añadir compra')) {
              await capturar('nuevo-articulo');
              await cerrarDialogo();
            }
            await pulsar('Compras');
            if (await pulsar('Añadir a compras')) {
              await capturar('nueva-compra');
              await cerrarDialogo();
            }
          }
        }
        if (seccion == AppSection.inbox && controller.inboxNotes().isNotEmpty) {
          final nota = find
              .byKey(ValueKey('nota-${controller.inboxNotes().first.id}'))
              .hitTestable();
          if (nota.evaluate().isNotEmpty) {
            await tester.tap(nota.first);
            await capturar('detalle');
          }
          if (await pulsar('Editar nota')) {
            await capturar('editar-nota');
            await pulsar('Cancelar');
          }
          if (await pulsar('Nueva nota')) {
            await capturar('nueva-nota');
            await cerrarDialogo();
          }
        }
        if (seccion == AppSection.projects && await pulsar('Nuevo proyecto')) {
          await capturar('nuevo-proyecto');
          await cerrarDialogo();
        }
        if (seccion == AppSection.categories) {
          if (await pulsar('Autocuidado')) await capturar('rutinas');
          if (await pulsar('Editar')) {
            await capturar('editar-categoria');
            await cerrarDialogo();
          }
          if (await pulsar('Nueva categoría')) {
            await capturar('nueva-categoria');
            await cerrarDialogo();
          }
        }
        if (seccion == AppSection.settings) {
          for (final titulo in [
            'Regla del día',
            'Notificaciones',
            'Ropa',
            'Secciones y pestañas',
            'Categorías',
            'Completadas',
            'Steam',
            'Conexión Android',
            'Conexión Kindle',
            'Copias de seguridad',
            'Estado del sistema',
            'Consejos y atajos'
          ]) {
            final control =
                find.descendant(of: pagina, matching: find.text(titulo));
            if (control.evaluate().isEmpty) continue;
            await Scrollable.ensureVisible(tester.element(control.first),
                alignment: .15);
            await estabilizar();
            if (await pulsar(titulo)) {
              await capturar(titulo.toLowerCase().replaceAll(' ', '-'));
              await pulsar(titulo);
            }
          }
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await estabilizar();
    debugDisableShadows = sombrasAnteriores;
    final registroAnterior = File('$_salida/registro.json');
    if (_seleccion.isNotEmpty && registroAnterior.existsSync()) {
      final anterior = jsonDecode(registroAnterior.readAsStringSync()) as Map;
      final actualizadas = registro.map((captura) => captura['vista']).toSet();
      registro.insertAll(0, (anterior['capturas'] as List)
          .map((captura) => Map<String, dynamic>.from(captura as Map))
          .where((captura) => !actualizadas.contains(captura['vista'])));
    }
    File('$_salida/registro.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ')
            .convert({'capturas': registro, 'fallos': fallos}));
    expect(fallos, isEmpty,
        reason: 'Las vistas no deben desbordarse ni fallar.');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
