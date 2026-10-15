// Renders every screen to design/screenshots/*.png at phone size (1080x2340).
// Run from the project root: flutter test tool/screenshot_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vale_helper/main.dart';

final _shotKey = GlobalKey();

Future<void> _loadFonts() async {
  Future<ByteData> f(String path) async =>
      ByteData.view(Uint8List.fromList(await File(path).readAsBytes()).buffer);
  final figtree = FontLoader('Figtree');
  for (final w in [400, 500, 600, 700, 800]) {
    figtree.addFont(f('assets/fonts/Figtree-$w.ttf'));
  }
  await figtree.load();
  final root = Platform.environment['FLUTTER_ROOT'] ?? r'C:\Users\Benny\scoop\apps\flutter\current';
  await (FontLoader('MaterialIcons')
        ..addFont(f('$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf')))
      .load();
}

/// Decodes every visible image (asset decoding needs real async in tests), then captures.
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

Finder _nav(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> _pumpApp(WidgetTester tester, Brightness brightness) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  // This is a test, it just lives outside test/ so `flutter test` doesn't run it by default.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    'tracker.zones': jsonEncode({
      'sea_spirit': 'table',
      'balog': 'table',
      'imp': 'hand',
      'succubus': 'hand',
      'nessie': 'hand',
      'horned_salamander': 'field',
      'undine': 'field',
      'ifrit': 'field',
    }),
    'phase.checked': ['hunting.reveal'],
  });
  final data = await tester.runAsync(loadAppData);
  await tester.pumpWidget(RepaintBoundary(key: _shotKey, child: ValeApp(loader: () async => data!)));
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('dark screenshots', (tester) async {
    await _pumpApp(tester, Brightness.dark);

    // Cards
    await _shot(tester, '01_cards_all');
    await tester.tap(find.bySemanticsLabel('Family Fire'));
    await _shot(tester, '02_cards_fire_by_cost');
    await tester.tap(find.text('3').last);
    await _shot(tester, '03_cards_fire_jump_cost3');
    await tester.tap(find.bySemanticsLabel('Family Fire'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('density2')));
    await _shot(tester, '04_cards_2_per_row');
    await tester.tap(find.byKey(const Key('density4')));
    await tester.pumpAndSettle();

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
}
