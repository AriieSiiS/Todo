import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_launch_intent.dart';
import 'app/todo_app.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      child: TodoApp(launchIntent: AppLaunchIntent.fromArgs(args)),
    ),
  );
}
