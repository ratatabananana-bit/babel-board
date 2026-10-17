import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vale_helper/core/app_state.dart';
import 'package:vale_helper/main.dart';
import 'package:vale_helper/modules/loaded_module.dart';
import 'package:vale_helper/modules/module_files.dart';

final miniDir = Directory('test/fixtures/mini_module');

/// Every file of the mini module, keyed by relative path with `/` separators.
Map<String, Uint8List> miniFiles() => {
      for (final f in miniDir.listSync(recursive: true).whereType<File>())
        f.path.substring(miniDir.path.length + 1).replaceAll(r'\', '/'): f.readAsBytesSync(),
    };

/// Loads the mini module, optionally after editing its manifest in memory.
Future<LoadedModule> loadMini({void Function(Map<String, dynamic> manifest)? edit}) async {
  if (edit == null) return loadModule(DirectoryModuleFiles(miniDir));
  final files = miniFiles();
  final manifest = jsonDecode(utf8.decode(files['module.json']!)) as Map<String, dynamic>;
  edit(manifest);
  files['module.json'] = Uint8List.fromList(utf8.encode(jsonEncode(manifest)));
  return loadModule(MemoryModuleFiles(files));
}

Finder navLabel(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

/// Pumps the app with the given modules (default: the mini module) and opens [tab].
Future<AppState> pumpModules(
  WidgetTester tester, {
  List<LoadedModule>? modules,
  Map<String, Object> prefs = const {'app.lastGame': 'mini'},
  String? tab,
  void Function(Map<String, dynamic> manifest)? edit,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final data = await tester.runAsync(() async {
    final p = await SharedPreferences.getInstance();
    return AppData(p, modules ?? [await loadMini(edit: edit)]);
  });
  await tester.pumpWidget(HelperApp(loader: () async => data!));
  await tester.pumpAndSettle();
  if (tab != null) {
    await tester.tap(navLabel(tab));
    await tester.pumpAndSettle();
  }
  return tester.element(find.byType(MaterialApp)).read<AppState>();
}

/// Reads a provided object from inside the open module's scope.
T scoped<T>(WidgetTester tester) => tester.element(find.byType(NavigationBar)).read<T>();

/// A touch long-press drag from [from] to [to], moved in steps like a real finger.
Future<void> longPressDrag(WidgetTester tester, Offset from, Offset to) async {
  final g = await tester.startGesture(from);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
  for (var i = 1; i <= 10; i++) {
    await g.moveTo(Offset.lerp(from, to, i / 10)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await tester.pumpAndSettle();
}
