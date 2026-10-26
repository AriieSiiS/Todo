import 'dart:convert';
import 'dart:io';

import 'package:todo_lan_sync_agent/kindle_gateway.dart';
import 'package:todo_lan_sync_agent/kindle_background_store.dart';

/// Cliente sin Flutter para las pruebas de relevo entre procesos de Windows.
Future<void> main(List<String> args) async {
  final data = jsonDecode(await utf8.decoder.bind(stdin).join()) as Map;
  try {
    final directory = Directory(args.single);
    final command = data['name'] as String;
    final arguments = Map<String, dynamic>.from(data['arguments'] as Map);
    final result = data['direct'] == true
        ? await KindleBackgroundStore(directory).execute(command, arguments)
        : await KindleBridgeClient(directory).call(command, arguments);
    stdout.writeln(jsonEncode(result));
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
