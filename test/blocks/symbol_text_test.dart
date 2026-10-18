import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/blocks/item_view.dart';
import 'package:vale_helper/blocks/symbol_text.dart';

import '../helpers.dart';

/// Every piece of plain text in the RichText that holds [needle].
String plainOf(WidgetTester tester, Finder f) => tester.widget<RichText>(f).text.toPlainText();

void main() {
  testWidgets(':symbol: in item text becomes the symbol picture, sized to the line and centred', (tester) async {
    await pumpModules(tester);
    await tester.tap(find.bySemanticsLabel('Imp'));
    await tester.pumpAndSettle();
    final effect = find.descendant(of: find.byType(ItemSheet), matching: find.byType(SymbolText)).first;
    // The marker itself is never shown; unknown names stay as written.
    expect(find.textContaining(':stone_red:', findRichText: true), findsNothing);
    expect(find.textContaining(':unknown:', findRichText: true), findsOneWidget);
    final icon = find.descendant(of: effect, matching: find.byType(SymbolImage));
    expect(icon, findsOneWidget);
    expect(tester.widget<SymbolImage>(icon).name, 'stone_red');
    // As tall as one line of the text around it (the wiki's look): font size x line height.
    final style = tester.widget<SymbolText>(effect).style!;
    expect(tester.widget<SymbolImage>(icon).size, closeTo(style.fontSize! * (style.height ?? 1.2), 0.5));
    final span =
        tester.widget<RichText>(find.descendant(of: effect, matching: find.byType(RichText)).first).text as TextSpan;
    final widgetSpans = <WidgetSpan>[];
    span.visitChildren((s) {
      if (s is WidgetSpan) widgetSpans.add(s);
      return true;
    });
    expect(widgetSpans.single.alignment, PlaceholderAlignment.middle);
  });

  testWidgets('board mini cards and flow checklists show the icons too', (tester) async {
    await pumpModules(tester, tab: 'Board', prefs: {'app.lastGame': 'mini', 'mod.mini.zones': '{"imp":"a"}'});
    expect(find.descendant(of: find.byType(SymbolText), matching: find.byType(SymbolImage)), findsWidgets);
    expect(find.textContaining(':stone_red:', findRichText: true), findsNothing);
  });

  test('adjacent markers become adjacent icons', () {
    expect(parseSymbols('Earn :stone_red::stone_red:.', {'stone_red'}), ['Earn ', #stone_red, #stone_red, '.']);
  });

  testWidgets('icons side by side keep a small gap, like the printed card', (tester) async {
    await pumpModules(
      tester,
      edit: (m) {
        final items = m['collections']['items'] as Map;
        items['sheet']['secondary'] = 'Pay :stone_red::stone_red:';
      },
    );
    await tester.tap(find.bySemanticsLabel('Imp'));
    await tester.pumpAndSettle();
    final line = find.byWidgetPredicate((w) => w is SymbolText && w.text == 'Pay :stone_red::stone_red:');
    expect(line, findsOneWidget, reason: 'the secondary line shows icons too');
    final icons = find.descendant(of: line, matching: find.byType(SymbolImage));
    expect(icons, findsNWidgets(2));
    final a = tester.getRect(icons.first), b = tester.getRect(icons.last);
    final gap = b.left - a.right;
    expect(gap, inInclusiveRange(1.5, 4), reason: 'a hairline gap, not touching and not a full space');
  });

  test('parseSymbols splits text and known symbol names', () {
    final parts = parseSymbols('Value of your :stone_blue: counts as :stone_purple:.', {'stone_blue', 'stone_purple'});
    expect(parts, ['Value of your ', #stone_blue, ' counts as ', #stone_purple, '.']);
    expect(parseSymbols('Time: 3:00 :nope:', {'stone_blue'}), ['Time: 3:00 :nope:']);
  });
}
