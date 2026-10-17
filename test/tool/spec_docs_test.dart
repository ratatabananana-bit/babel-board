import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vale_helper/library/library_screen.dart';
import 'package:vale_helper/main.dart';
import 'package:vale_helper/module_format/block_types.dart';

void main() {
  final ai = File('modules/AI_INSTRUCTIONS.md');
  final spec = File('modules/MODULE_SPEC.md');

  test('AI_INSTRUCTIONS.md is small enough to paste and covers the essentials', () {
    final text = ai.readAsStringSync();
    expect(text.length, lessThanOrEqualTo(24000));
    for (final t in kBlockTypes) {
      expect(text, contains(t), reason: 'block type $t');
    }
    for (final w in ['single JSON', 'https', 'verified']) {
      expect(text, contains(w));
    }
    expect(text.trimRight(), endsWith('Reply with one JSON file.'));
  });

  test('MODULE_SPEC.md documents every block type', () {
    final text = spec.readAsStringSync();
    for (final t in kBlockTypes) {
      expect(text, contains('`$t`'), reason: 'block type $t');
    }
    for (final w in ['verified', 'rulebook', 'https', 'single JSON']) {
      expect(text, contains(w));
    }
  });

  testWidgets('"Copy instructions for AI" puts the instructions on the clipboard', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    SharedPreferences.setMockInitialValues({});
    final data = await tester.runAsync(() async => AppData(await SharedPreferences.getInstance(), const []));
    await tester.pumpWidget(HelperApp(loader: () async => data!));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy instructions for AI'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(copied, ai.readAsStringSync());
    expect(find.text('Copied — paste it into Claude or ChatGPT'), findsOneWidget);
  });
}
