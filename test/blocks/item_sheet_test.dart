import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/blocks/item_picture.dart';
import 'package:vale_helper/blocks/item_sheet.dart';
import 'package:vale_helper/modules/loaded_module.dart';
import 'package:vale_helper/modules/module_files.dart';

import '../helpers.dart';

/// The mini module whose items have a `back` picture field; Imp has one (the water art),
/// and Nessie carries [nessie] extra fields.
Future<LoadedModule> miniWithBacks({Map<String, Object> nessie = const {}, List<Object>? chips}) async {
  final files = withManifest(miniFiles(), (m) {
    final items = m['collections']['items'] as Map;
    items['backImageField'] = 'back';
    if (chips != null) (items['sheet']['chips'] as List).addAll(chips);
  });
  final data = jsonDecode(utf8.decode(files['data/items.json']!)) as Map<String, dynamic>;
  for (final it in data['items'] as List) {
    if (it['id'] == 'imp') it['back'] = 'images/water.webp';
    if (it['id'] == 'nessie') (it as Map).addAll(nessie);
  }
  files['data/items.json'] = Uint8List.fromList(utf8.encode(jsonEncode(data)));
  return loadModule(MemoryModuleFiles(files));
}

final backFaces = find.byWidgetPredicate((w) => w is ItemPicture && w.back);

Future<void> openSheet(WidgetTester tester, String name) async {
  await tester.tap(find.bySemanticsLabel(name));
  await tester.pumpAndSettle();
  expect(find.byType(ItemSheet), findsOneWidget);
}

void main() {
  testWidgets('an item with a back picture flips on its sheet', (tester) async {
    await pumpModules(tester, load: () async => [await miniWithBacks()]);
    await openSheet(tester, 'Imp');
    expect(find.bySemanticsLabel('Flip card'), findsOneWidget);
    expect(backFaces, findsNothing, reason: 'the front shows first');

    await tester.tap(find.bySemanticsLabel('Flip card'));
    await tester.pumpAndSettle();
    expect(backFaces, findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Flip card'));
    await tester.pumpAndSettle();
    expect(backFaces, findsNothing, reason: 'and back again');
  });

  testWidgets('an item without a back picture has no flip button', (tester) async {
    await pumpModules(tester, load: () async => [await miniWithBacks()]);
    await openSheet(tester, 'Nessie');
    expect(find.bySemanticsLabel('Flip card'), findsNothing);
  });

  testWidgets('the zoomed picture opens on the side the sheet shows, and flips there too', (tester) async {
    await pumpModules(tester, load: () async => [await miniWithBacks()]);
    await openSheet(tester, 'Imp');
    await tester.tap(find.bySemanticsLabel('Flip card'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.open_in_full_rounded));
    await tester.pumpAndSettle();
    final zoomed = find.descendant(of: find.byType(InteractiveViewer), matching: find.byType(ItemPicture));
    expect(tester.widget<ItemPicture>(zoomed).back, isTrue);

    await tester.tap(find.bySemanticsLabel('Flip card').last);
    await tester.pumpAndSettle();
    expect(tester.widget<ItemPicture>(zoomed).back, isFalse);
  });

  testWidgets('a chip too long for the sheet is cut short, never overflows', (tester) async {
    await pumpModules(
      tester,
      load: () async => [
        await miniWithBacks(
          nessie: {'start': 'Start with three broken wards, one sheltered card and a very long note besides'},
          chips: [
            {'label': 'Also', 'text': '{start}'},
          ],
        ),
      ],
    );
    await openSheet(tester, 'Nessie');
    expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow');
    expect(find.textContaining('Start with three broken wards'), findsOneWidget);
  });

  testWidgets('a labelled chip with no value is hidden', (tester) async {
    await pumpModules(
      tester,
      load: () async => [
        await miniWithBacks(
          nessie: {
            'curses': ['fire', 'fire'],
          },
          chips: [
            {'label': 'Curses', 'symbols': 'curses'},
          ],
        ),
      ],
    );
    await openSheet(tester, 'Imp');
    expect(find.text('Curses'), findsNothing, reason: 'Imp has no curses: no lone label');
    await tester.tapAt(const Offset(20, 40));
    await tester.pumpAndSettle();
    await openSheet(tester, 'Nessie');
    expect(find.text('Curses'), findsOneWidget);
  });
}
