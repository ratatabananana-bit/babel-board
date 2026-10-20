import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/blocks/item_sheet.dart';

import '../helpers.dart';

/// The mini module with its gallery and a text block moved under a hub on the first tab.
void hubEdit(Map<String, dynamic> m) {
  final tabs = m['tabs'] as List;
  final gallery = (tabs[0] as Map)['block'];
  m['tabs'] = [
    {
      'label': 'Menu',
      'icon': 'grid',
      'block': {
        'type': 'hub',
        'title': 'Cards',
        'children': [
          {'type': 'entry', 'label': 'Gallery', 'summary': 'All cards', 'image': 'images/fire.webp', 'block': gallery},
          {
            'type': 'entry',
            'label': 'Rules',
            'icon': 'book',
            'block': {
              'type': 'text',
              'title': 'Rules',
              'paragraphs': ['Hello'],
            },
          },
        ],
      },
    },
    tabs[1],
  ];
}

void main() {
  testWidgets('hub lists entries; tapping opens the entry block with a back arrow', (tester) async {
    await pumpModules(tester, edit: hubEdit);
    expect(find.text('Cards'), findsOneWidget, reason: 'hub title');
    expect(find.text('All cards'), findsOneWidget, reason: 'entry summary');
    expect(find.text('Hello'), findsNothing);

    await tester.tap(find.text('Rules'));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('All cards'), findsOneWidget);

    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Imp'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemSheet), findsOneWidget, reason: 'sheets open from a pushed screen');
  });
}
