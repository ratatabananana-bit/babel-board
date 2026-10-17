import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vale_helper/core/settings.dart';
import 'package:vale_helper/library/settings_screen.dart';
import 'package:vale_helper/main.dart';

Future<void> pumpLibraryOnly(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final data = await tester.runAsync(() async => AppData(await SharedPreferences.getInstance(), const []));
  await tester.pumpWidget(HelperApp(loader: () async => data!));
  await tester.pumpAndSettle();
}

Settings settingsOf(WidgetTester tester) => tester.element(find.byType(MaterialApp)).read<Settings>();

void main() {
  testWidgets('the Library has a Settings button that opens the settings screen', (tester) async {
    await pumpLibraryOnly(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    for (final t in [
      'Theme',
      'Cards per row',
      'Flowing family grid',
      'Copy instructions for AI',
      'Table Helper 3.0.0',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
  });

  testWidgets('theme choice applies at once and is remembered', (tester) async {
    await pumpLibraryOnly(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.system);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.dark);
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    expect(Settings(prefs!).themeMode, ThemeMode.dark);
  });

  testWidgets('cards per row and the flowing grid can be set here', (tester) async {
    await pumpLibraryOnly(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsColumns2')));
    await tester.pumpAndSettle();
    expect(settingsOf(tester).columns, 2);
    await tester.tap(find.text('Flowing family grid'));
    await tester.pumpAndSettle();
    expect(settingsOf(tester).flowingSections, isTrue);
  });

  testWidgets('"Copy instructions for AI" in Settings puts them on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpLibraryOnly(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy instructions for AI'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(copied, contains('Reply with one JSON file.'));
  });
}
