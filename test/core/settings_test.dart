import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vale_helper/core/settings.dart';

void main() {
  test('Settings clamps the column count to 2..4 and persists it', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final s = Settings(prefs)..columns = 20;
    expect(s.columns, Settings.maxColumns);
    s.columns = 3;
    expect(Settings(prefs).columns, 3);
  });

  test('cards per row grow with the screen: phones keep 4/3/2, tablets get more', () {
    expect(Settings.columnsFor(4, 392), 4);
    expect(Settings.columnsFor(3, 392), 3);
    expect(Settings.columnsFor(2, 360), 2);
    expect(Settings.columnsFor(4, 800), 8);
    expect(Settings.columnsFor(3, 800), 6);
    expect(Settings.columnsFor(2, 800), 4);
    expect(Settings.columnsFor(4, 1280), 12);
  });
}
