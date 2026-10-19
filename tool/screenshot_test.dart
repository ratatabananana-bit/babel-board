// Renders every screen to design/screenshots/*.png at phone size (1080x2340).
// Run from the project root: flutter test tool/screenshot_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vale_helper/blocks/item_sheet.dart';
import 'package:vale_helper/blocks/item_tile.dart';
import 'package:vale_helper/core/settings.dart';
import 'package:vale_helper/library/module_store.dart';
import 'package:vale_helper/library/repository.dart';
import 'package:vale_helper/main.dart';
import 'package:vale_helper/modules/loaded_module.dart';
import 'package:vale_helper/modules/module_files.dart';

final _shotKey = GlobalKey();

const _vale = 'vale-of-eternity';
const _ma = 'magical-athlete';

Future<void> _loadFonts() async {
  Future<ByteData> f(String path) async => ByteData.view(Uint8List.fromList(await File(path).readAsBytes()).buffer);
  final figtree = FontLoader('Figtree');
  for (final w in [400, 500, 600, 700, 800]) {
    figtree.addFont(f('assets/fonts/Figtree-$w.ttf'));
  }
  await figtree.load();
  // The app names the system CJK fonts as fallbacks; this test runs on Windows, so load
  // the one Windows ships (Noto Sans SC) under that name when it is there.
  final noto = File(r'C:\Windows\Fonts\NotoSansSC-VF.ttf');
  if (noto.existsSync()) await (FontLoader('Noto Sans SC')..addFont(f(noto.path))).load();
  // The Material icon font ships with the SDK; FLUTTER_ROOT points at it (scoop's shim sets it).
  final root = Platform.environment['FLUTTER_ROOT'] ?? _sdkRootFromPath();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(f('$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf'))).load();
}

/// The SDK folder, found from the `flutter` on PATH (`<sdk>/bin/flutter`), when FLUTTER_ROOT is unset.
String _sdkRootFromPath() {
  final sep = Platform.isWindows ? ';' : ':';
  for (final dir in (Platform.environment['PATH'] ?? '').split(sep)) {
    if (File('$dir${Platform.pathSeparator}flutter').existsSync() ||
        File('$dir${Platform.pathSeparator}flutter.bat').existsSync()) {
      return Directory(dir).parent.path;
    }
  }
  throw StateError('Set FLUTTER_ROOT to your Flutter SDK folder');
}

/// Decodes every visible image (file decoding needs real async in tests), then captures.
Future<void> _shot(WidgetTester tester, String name, {bool settle = true}) async {
  if (settle) await tester.pumpAndSettle();
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shotKey));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: tester.view.devicePixelRatio);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('design/screenshots/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Finder _nav(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

/// Taps the density button until it reads [n] cards per row (it cycles 4 → 3 → 2).
Future<void> _density(WidgetTester tester, int n) async {
  final cycle = find.byKey(const Key('densityCycle'));
  for (var i = 0; i < 3 && find.descendant(of: cycle, matching: find.text(Settings.sizeLetter(n))).evaluate().isEmpty; i++) {
    await tester.tap(cycle);
    await tester.pumpAndSettle();
  }
}

Future<void> _pumpApp(WidgetTester tester, Brightness brightness, {String game = _vale}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  // This is a test, it just lives outside test/ so `flutter test` doesn't run it by default.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    'app.lastGame': game,
    'mod.$_ma.zones': jsonEncode({'banana': 'race', 'baba_yaga': 'race', 'suckerfish': 'race'}),
    'mod.$_vale.zones': jsonEncode({
      'sea_spirit': 'table',
      'balog': 'table',
      'imp': 'hand',
      'succubus': 'hand',
      'nessie': 'hand',
      'horned_salamander': 'field',
      'undine': 'field',
      'ifrit': 'field',
    }),
    'mod.$_vale.phase.checked': ['hunting.reveal'],
    'mod.$_ma.phase.index': 2,
    'mod.$_ma.phase.checked': ['race2.reveal', 'race2.start'],
  });
  final data = await tester.runAsync(() async {
    final prefs = await SharedPreferences.getInstance();
    return AppData(prefs, [
      await loadModule(DirectoryModuleFiles(Directory('modules/$_vale'))),
      await loadModule(DirectoryModuleFiles(Directory('modules/$_ma'))),
    ]);
  });
  await tester.pumpWidget(
    RepaintBoundary(
      key: _shotKey,
      child: HelperApp(loader: () async => data!),
    ),
  );
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('dark screenshots', (tester) async {
    await _pumpApp(tester, Brightness.dark);

    // Cards
    await _shot(tester, '01_cards_all');
    await tester.tap(find.bySemanticsLabel('Family Fire'));
    await _shot(tester, '02_cards_fire_by_cost');
    await tester.tap(find.descendant(of: find.byKey(const Key('sectionRail')), matching: find.text('3')));
    await _shot(tester, '03_cards_fire_jump_cost3');
    await tester.tap(find.bySemanticsLabel('Family Fire'));
    await tester.pumpAndSettle();
    await _density(tester, 2);
    await _shot(tester, '04_cards_2_per_row');
    await _density(tester, 4);

    // Card sheet
    await tester.tap(find.bySemanticsLabel('Imp, in Hand'));
    await _shot(tester, '05_card_sheet');
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();

    // My cards
    await tester.tap(_nav('My cards'));
    await _shot(tester, '06_my_cards');
    final g = await tester.startGesture(tester.getCenter(find.text('Imp')));
    await tester.pump(const Duration(milliseconds: 400));
    await g.moveBy(const Offset(0, 20));
    await tester.pump(const Duration(milliseconds: 200));
    await g.moveTo(tester.getCenter(find.text('Drop here').last) + const Offset(-120, 40));
    await tester.pump();
    await g.moveBy(const Offset(1, 1));
    await tester.pump(const Duration(milliseconds: 200));
    await _shot(tester, '07_my_cards_dragging', settle: false);
    await g.cancel();
    await tester.pumpAndSettle();

    // Round
    await tester.tap(_nav('Round'));
    await _shot(tester, '08_round_hunting');
    await tester.tap(find.text('Next: Action'));
    await _shot(tester, '09_round_next_armed');
    await tester.tap(find.text('Resolution'));
    await _shot(tester, '10_round_resolution');
    await tester.tap(find.text('End of round'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('How this phase works'));
    await _shot(tester, '11_round_end_of_round');
    await tester.tap(find.text('Rules'));
    await _shot(tester, '12_rules_sheet');
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Setup checklist'));
    await _shot(tester, '13_setup_sheet');
  });

  testWidgets('light screenshots', (tester) async {
    await _pumpApp(tester, Brightness.light);
    await _shot(tester, '14_light_cards');
    await tester.tap(_nav('My cards'));
    await _shot(tester, '15_light_my_cards');
    await tester.tap(_nav('Round'));
    await _shot(tester, '16_light_round');
  });

  testWidgets('magical athlete screenshots', (tester) async {
    await _pumpApp(tester, Brightness.dark, game: _ma);
    await _shot(tester, '17_ma_racers');
    await _density(tester, 2);
    await _shot(tester, '18_ma_racers_2_per_row');
    await _density(tester, 4);
    await tester.tap(find.bySemanticsLabel('Baba Yaga, in This race'));
    await _shot(tester, '19_ma_racer_sheet');
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();
    await tester.tap(_nav('This race'));
    await _shot(tester, '20_ma_this_race');
    await tester.tap(_nav('Game'));
    await _shot(tester, '21_ma_game_race2');
    await tester.tap(find.byKey(const Key('gameSwitcher')).last);
    await _shot(tester, '22_game_switcher');
  });

  testWidgets('flowing family grid, settings and tablet screenshots', (tester) async {
    await _pumpApp(tester, Brightness.dark);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Family Fire'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('layoutToggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(const Key('sectionRail')), matching: find.text('2')));
    await _shot(tester, '25_cards_fire_flowing_cost2');

    // Grouped again, with cost 3 picked on the rail: its section is highlighted.
    await tester.tap(find.byKey(const Key('layoutToggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(const Key('sectionRail')), matching: find.text('3')));
    await _shot(tester, '26_cards_fire_grouped_cost3_highlight');

    // A 10-inch tablet in portrait.
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2;
    await tester.tap(find.bySemanticsLabel('Family Fire'));
    await _shot(tester, '27_tablet_cards');
  });

  testWidgets('drag-up details screenshot', (tester) async {
    await _pumpApp(tester, Brightness.dark);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hae');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ItemTile));
    await _shot(tester, '29_card_sheet_details_hidden');
    await tester.tap(find.byKey(const Key('detailsHint')));
    await _shot(tester, '30_card_sheet_details_open');
  });

  testWidgets('card sheet flick screenshots (Hae-tae)', (tester) async {
    await _pumpApp(tester, Brightness.dark);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hae');
    await tester.pumpAndSettle();
    var n = 31;
    for (final (dx, name) in [(14.0, 'hand'), (-14.0, 'table')]) {
      await tester.tap(find.byType(ItemTile).first);
      await tester.pumpAndSettle();
      // Mid-flick: the card tints in the target zone's colour.
      final g = await tester.startGesture(tester.getCenter(find.byType(ItemSheet)));
      for (var i = 0; i < 10; i++) {
        await g.moveBy(Offset(dx, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await _shot(tester, '${n++}_card_sheet_flick_to_$name', settle: false);
      await g.cancel();
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 60));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('settings screenshot', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final data = await tester.runAsync(() async => AppData(await SharedPreferences.getInstance(), const []));
    await tester.pumpWidget(
      RepaintBoundary(
        key: _shotKey,
        child: HelperApp(key: UniqueKey(), loader: () async => data!),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await _shot(tester, '28_settings');
  });

  testWidgets('library screenshots', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    // First launch after the update: nothing installed, no repository yet.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final tmp = (await tester.runAsync(() => Directory.systemTemp.createTemp('shots_')))!;
    addTearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException {
        // Disposable.
      }
    });
    final empty = await tester.runAsync(
      () async => AppData.fromStore(await SharedPreferences.getInstance(), ModuleStore(Directory('${tmp.path}/empty'))),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: _shotKey,
        child: HelperApp(key: UniqueKey(), loader: () async => empty!),
      ),
    );
    await _shot(tester, '23_library_empty');

    // Vale installed; the repository offers Magical Athlete and a game for a newer app.
    final indexUrl = Uri.parse('https://raw.githubusercontent.com/owner/games/main/index.json');
    final client = MockClient((req) async {
      if (req.url != indexUrl) return http.Response('', 404);
      return http.Response(
        jsonEncode({
          'name': 'Our games',
          'modules': [
            {
              'id': _vale,
              'name': 'Vale of Eternity',
              'version': '1.0.0',
              'minAppVersion': '3.0.0',
              'zip': 'v.zip',
              'size': 1531506,
            },
            {
              'id': _ma,
              'name': 'Magical Athlete',
              'version': '1.0.0',
              'minAppVersion': '3.0.0',
              'zip': 'm.zip',
              'size': 396436,
            },
            {
              'id': 'heat',
              'name': 'Heat: Pedal to the Metal',
              'version': '1.0.0',
              'minAppVersion': '3.1.0',
              'zip': 'h.zip',
              'size': 2048000,
            },
          ],
        }),
        200,
      );
    });
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({'repo.indexUrl': indexUrl.toString()});
    final withRepo = await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      final store = ModuleStore(Directory('${tmp.path}/repo'));
      final archive = Archive();
      final dir = Directory('modules/$_vale');
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        final bytes = f.readAsBytesSync();
        archive.addFile(ArchiveFile(f.path.substring(dir.path.length + 1).replaceAll(r'\', '/'), bytes.length, bytes));
      }
      await store.installBytes(Uint8List.fromList(ZipEncoder().encode(archive)));
      return AppData.fromStore(
        prefs,
        store,
        repoConfigStore: RepoConfigStore(prefs, readSecret: (_) async => 'token', writeSecret: (_, _) async {}),
        repoClientFactory: (c) => RepoClient(c, client: client),
      );
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: _shotKey,
        child: HelperApp(key: UniqueKey(), loader: () async => withRepo!),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await _shot(tester, '24_library_repository');

    // The repository sheet, connected: link, folded token, the games with Install buttons.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repository'));
    await _shot(tester, '33_repository_sheet');
  });
}
