import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/core/app_state.dart';
import 'package:vale_helper/modules/loaded_module.dart';
import 'package:vale_helper/modules/module_files.dart';

import '../helpers.dart';

const valeId = 'vale-of-eternity';
const maId = 'magical-athlete';

Future<LoadedModule> loadVale() => loadModule(DirectoryModuleFiles(Directory('modules/$valeId')));
Future<LoadedModule> loadMa() => loadModule(DirectoryModuleFiles(Directory('modules/$maId')));

/// Pumps the app with both real modules installed.
Future<AppState> pumpGames(WidgetTester tester, {Map<String, Object> prefs = const {}, String? tab}) =>
    pumpModules(tester, load: () async => [await loadVale(), await loadMa()], prefs: prefs, tab: tab);
