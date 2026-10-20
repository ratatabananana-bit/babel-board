import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/modules/module_state.dart';

import '../helpers.dart';

void main() {
  testWidgets('a cardList with an inZone rule follows the tracked zone live', (tester) async {
    await pumpModules(
      tester,
      tab: 'In play',
      edit: (m) {
        m['collections'] = {
          ...(m['collections'] as Map),
          'families': {
            'items': [
              {'id': 'fire', 'name': 'Fire'},
              {'id': 'water', 'name': 'Water'},
            ],
          },
        };
        (m['tabs'] as List).add(<String, Object>{
          'label': 'In play',
          'icon': 'list',
          'block': <String, Object>{
            'type': 'cardList',
            'collection': 'items',
            'style': 'rows',
            'filter': {
              'where': [
                {'path': 'family', 'inZone': 'b'},
              ],
            },
          },
        });
      },
    );
    expect(find.text('Nothing here yet.'), findsOneWidget);
    final zones = scoped<ZoneState>(tester);
    zones.put('fire', 'b');
    await tester.pumpAndSettle();
    expect(find.text('Imp'), findsOneWidget, reason: 'Imp is a fire card');
    expect(find.text('Nessie'), findsNothing, reason: 'Nessie is water');
    zones.remove('fire');
    await tester.pumpAndSettle();
    expect(find.text('Nothing here yet.'), findsOneWidget);
  });
}
