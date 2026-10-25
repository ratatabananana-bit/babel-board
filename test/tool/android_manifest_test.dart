import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the release app may use the internet (repositories, links, image downloads)', () {
    // Debug and profile builds get the permission from their own manifests; a release build
    // has only the main one, and without it every repository reads "No connection".
    final main = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(main, contains('<uses-permission android:name="android.permission.INTERNET"/>'));
  });
}
