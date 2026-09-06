import 'dart:async';
import 'dart:math' show max, min;
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/providers/todo_providers.dart';
import '../../application/state/todo_workspace.dart';
import '../../app/app_launch_intent.dart';
import '../../app/todo_theme.dart';
import '../../services/ambient_music_controller.dart';
import '../../domain/models.dart';
import '../shared/editors.dart';
import '../knowledge/knowledge_workspace_page.dart';

part 'shell_chrome.dart';
part 'today_page.dart';
part 'projects_page.dart';
part 'categories_page.dart';
part 'expenses_page.dart';
part 'calendar_page.dart';
part 'library_page.dart';
part 'wardrobe_page.dart';
part 'household_page.dart';
part 'recipes_page.dart';
part 'inbox_page.dart';
part 'completed_page.dart';
part 'settings_page.dart';
part 'shared_widgets.dart';
