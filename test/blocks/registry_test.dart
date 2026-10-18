import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vale_helper/blocks/registry.dart';
import 'package:vale_helper/core/app_state.dart';
import 'package:vale_helper/main.dart';
import 'package:vale_helper/module_format/block_specs.dart';
import 'package:vale_helper/modules/loaded_module.dart';
import 'package:vale_helper/modules/module_files.dart';

Finder navLabel(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<AppState> pumpMini(WidgetTester tester, {Map<String, Object> prefs = const {'app.lastGame': 'mini'}}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final data = await tester.runAsync(() async {
    final p = await SharedPreferences.getInstance();
    final m = await loadModule(DirectoryModuleFiles(Directory('test/fixtures/mini_module')));
    return AppData(p, [m]);
  });
  await tester.pumpWidget(HelperApp(loader: () async => data!));
  await tester.pumpAndSettle();
  return tester.element(find.byType(MaterialApp)).read<AppState>();
}

void main() {
  test('the registry draws every block type the parsers know, except step', () {
    expect(blockRegistry.keys.toSet(), kBlockTypes.difference({'step'}));
  });

  testWidgets('shell shows the module tabs; the text block renders its text', (tester) async {
    await pumpMini(tester);
    for (final l in ['Gallery', 'Board', 'Flow', 'Text']) {
      expect(navLabel(l), findsOneWidget, reason: l);
    }
    await tester.tap(navLabel('Text'));
    await tester.pumpAndSettle();
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Mini game text paragraph.'), findsOneWidget);
    expect(find.text('First bullet.'), findsOneWidget);
  });

  testWidgets('an unregistered block type shows the needs-newer-app message', (tester) async {
    final saved = blockRegistry.remove('text');
    addTearDown(() => blockRegistry['text'] = saved!);
    await pumpMini(tester);
    await tester.tap(navLabel('Text'));
    await tester.pumpAndSettle();
    expect(find.byType(UnknownBlock), findsOneWidget);
    expect(find.textContaining("This game needs a newer Babel Board (unknown block 'text')"), findsOneWidget);
  });

  testWidgets('tabs stay alive when switching away and back', (tester) async {
    await pumpMini(tester);
    await tester.tap(navLabel('Text'));
    await tester.pumpAndSettle();
    expect(find.text('Mini game text paragraph.'), findsOneWidget);
    await tester.tap(navLabel('Gallery'));
    await tester.pumpAndSettle();
    expect(
      find.text('Mini game text paragraph.', skipOffstage: false),
      findsOneWidget,
      reason: 'the Text page is kept alive offstage',
    );
  });

  testWidgets('the game switcher lists installed modules and a Library entry', (tester) async {
    final app = await pumpMini(tester);
    expect(app.active!.module.manifest.id, 'mini');
    await tester.tap(navLabel('Text'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('gameSwitcher')).first);
    await tester.pumpAndSettle();
    expect(find.text('Mini Game'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(app.active, isNull);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('no last game opens the Library; picking a game remembers it', (tester) async {
    await pumpMini(tester, prefs: {});
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('Mini Game'));
    await tester.pumpAndSettle();
    expect(navLabel('Text'), findsOneWidget);
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    expect(prefs!.getString(AppState.lastGameKey), 'mini');
  });
}
