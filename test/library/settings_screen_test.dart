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
      'Animation speed',
      'Card size',
      'Flowing family grid',
      'Copy instructions for AI',
      'Babel Board 3.1.1',
    ]) {
      await tester.scrollUntilVisible(find.text(t), 100, scrollable: find.byType(Scrollable).first);
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

  testWidgets('theme and card gallery settings are separate sections', (tester) async {
    await pumpLibraryOnly(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('CARD GALLERY'), findsOneWidget);
    expect(find.text('DISPLAY'), findsNothing);
    final appearance = tester.getTopLeft(find.text('APPEARANCE')).dy;
    final gallery = tester.getTopLeft(find.text('CARD GALLERY')).dy;
    final theme = tester.getTopLeft(find.text('Theme')).dy;
    final perRow = tester.getTopLeft(find.text('Card size')).dy;
    expect(appearance < theme && theme < gallery && gallery < perRow, isTrue);
  });

  testWidgets('animation speed is under Appearance: Instant, Fast (default), Normal', (tester) async {
    await pumpLibraryOnly(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(settingsOf(tester).animationSpeed, AnimationSpeed.fast);
    final speed = tester.getTopLeft(find.text('Animation speed')).dy;
    expect(speed, lessThan(tester.getTopLeft(find.text('CARD GALLERY')).dy));
    await tester.tap(find.text('Instant'));
    await tester.pumpAndSettle();
    expect(settingsOf(tester).animationSpeed, AnimationSpeed.instant);
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    expect(Settings(prefs!).animationSpeed, AnimationSpeed.instant);
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
