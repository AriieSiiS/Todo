import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers/todo_providers.dart';
import '../application/state/todo_workspace.dart';
import 'app_launch_intent.dart';
import '../presentation/shell/app_shell.dart';
import 'todo_theme.dart';

class TodoApp extends StatefulWidget {
  const TodoApp({
    required this.launchIntent,
    super.key,
  });

  final AppLaunchIntent launchIntent;

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  late final Future<TodoWorkspace> _controllerFuture;

  @override
  void initState() {
    super.initState();
    _controllerFuture = TodoWorkspace.create().then((controller) {
      controller.setSection(widget.launchIntent.section);
      return controller;
    });
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
            home: const _LoadingScreen(),
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

class _TodoMaterialApp extends ConsumerWidget {
  const _TodoMaterialApp({required this.launchIntent});

  final AppLaunchIntent launchIntent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(todoWorkspaceProvider);
    return MaterialApp(
      title: 'Todo',
      debugShowCheckedModeBanner: false,
      theme: buildTodoTheme(workspace.visualMode),
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
