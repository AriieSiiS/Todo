import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appflowy_editor/appflowy_editor.dart';

import '../application/providers/todo_providers.dart';
import '../application/state/todo_workspace.dart';
import 'app_launch_intent.dart';
import '../presentation/shell/app_shell.dart';
import 'todo_theme.dart';

class TodoApp extends StatefulWidget {
  const TodoApp({
    required this.launchIntent,
    this.workspaceLoader,
    super.key,
  });

  final AppLaunchIntent launchIntent;
  final Future<TodoWorkspace> Function()? workspaceLoader;

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  late Future<TodoWorkspace> _controllerFuture;

  @override
  void initState() {
    super.initState();
    _controllerFuture = _loadWorkspace();
  }

  Future<TodoWorkspace> _loadWorkspace() async {
    final controller = await (widget.workspaceLoader?.call() ??
        TodoWorkspace.create(
          initialImportantAlarmId: widget.launchIntent.importantAlarmId,
        ));
    try {
      final requestedSection = widget.launchIntent.section;
      if (requestedSection != null) {
        controller.setSection(requestedSection);
      }
      if (widget.launchIntent.testNotification) {
        await controller.sendTestNotification();
      }
      if (!mounted) controller.dispose();
      return controller;
    } catch (_) {
      controller.dispose();
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TodoWorkspace>(
      future: _controllerFuture,
      builder: (context, snapshot) {
        final controller = snapshot.data;
        if (controller == null) {
          return MaterialApp(
            title: 'Todo',
            debugShowCheckedModeBanner: false,
            theme: buildTodoTheme(),
            locale: const Locale('es', 'ES'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              AppFlowyEditorLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('es', 'ES'),
            ],
            home: snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasError
                ? Scaffold(
                    body: Center(
                        child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No se pudo abrir Todo'),
                      const SizedBox(height: 12),
                      const Text('No se pudieron cargar los datos locales.'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => setState(() {
                          _controllerFuture = _loadWorkspace();
                        }),
                        child: const Text('Volver a intentar'),
                      ),
                    ],
                  )))
                : const _LoadingScreen(),
          );
        }
        return ProviderScope(
          overrides: [
            todoWorkspaceProvider.overrideWith((ref) => controller),
          ],
          child: _TodoMaterialApp(launchIntent: widget.launchIntent),
        );
      },
    );
  }
}

class _TodoMaterialApp extends StatelessWidget {
  const _TodoMaterialApp({required this.launchIntent});

  final AppLaunchIntent launchIntent;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo',
      debugShowCheckedModeBanner: false,
      theme: buildTodoTheme(),
      locale: const Locale('es', 'ES'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppFlowyEditorLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
      ],
      home: AppShell(launchIntent: launchIntent),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando tu sistema personal...'),
          ],
        ),
      ),
    );
  }
}
