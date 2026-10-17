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
}
