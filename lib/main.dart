import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app_launch_intent.dart';
import 'app/todo_app.dart';
import 'mobile/mobile_background_sync.dart';
import 'mobile/mobile_task_app.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    await initializeMobileBackgroundSync();
    runApp(const MobileTaskApp());
    return;
  }
  MediaKit.ensureInitialized();
  runApp(
    ProviderScope(
      child: TodoApp(launchIntent: AppLaunchIntent.fromArgs(args)),
    ),
  );
}
