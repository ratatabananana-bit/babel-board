import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vale_helper/core/app_state.dart';
import 'package:vale_helper/library/install_sources.dart';
import 'package:vale_helper/library/library_controller.dart';
import 'package:vale_helper/library/library_screen.dart';
import 'package:vale_helper/library/module_store.dart';
import 'package:vale_helper/library/repository.dart';
import 'package:vale_helper/main.dart';

import '../helpers.dart';

Uint8List zipOf(Map<String, List<int>> files) {
  final a = Archive();
  for (final e in files.entries) {
    a.addFile(ArchiveFile(e.key, e.value.length, e.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(a));
}

Uint8List jsonBytes(Object j) => Uint8List.fromList(utf8.encode(jsonEncode(j)));

/// The mini module zipped, with the given id/name/version.
Uint8List miniZip({String id = 'mini', String name = 'Mini Game', String version = '1.0.0'}) {
  final files = miniFiles();
  final m = jsonDecode(utf8.decode(files['module.json']!)) as Map<String, dynamic>;
  m['id'] = id;
  m['name'] = name;
  m['version'] = version;
  files['module.json'] = jsonBytes(m);
  return zipOf(files);
}

final indexUrl = Uri.parse('https://repo.example/games/index.json');

class FakeSources extends InstallSources {
  FakeSources({this.picked, this.pickError});
  Uint8List? picked;
  Object? pickError;
  @override
  Future<Uint8List?> pickModuleFile() async {
    if (pickError != null) throw pickError!;
    return picked;
  }
}

late Directory tempRoot;

Future<AppState> pumpLibrary(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  List<Uint8List> preinstalled = const [],
  Map<String, Object>? repoIndex,
  Map<String, Uint8List> zips = const {},
  String? token,
  FakeSources? sources,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    ...prefs,
    RepoConfigStore.urlKey: ?(repoIndex == null ? null : indexUrl.toString()),
  });
  final secrets = <String, String>{RepoConfigStore.tokenKey: ?token};
  final client = MockClient((req) async {
    if (req.url == indexUrl) {
      return repoIndex == null ? http.Response('', 404) : http.Response(jsonEncode(repoIndex), 200);
    }
    final z = zips[req.url.pathSegments.last];
    return z == null ? http.Response('', 404) : http.Response.bytes(z, 200);
  });
  final data = await tester.runAsync(() async {
    final p = await SharedPreferences.getInstance();
    tempRoot = await Directory.systemTemp.createTemp('library_test_');
    final store = ModuleStore(Directory('${tempRoot.path}/modules'), client: client);
    for (final z in preinstalled) {
      await store.installBytes(z);
    }
    return AppData.fromStore(
      p,
      store,
      repoConfigStore: RepoConfigStore(
        p,
        readSecret: (k) async => secrets[k],
        writeSecret: (k, v) async {
          if (v == null) {
            secrets.remove(k);
          } else {
            secrets[k] = v;
          }
        },
      ),
      repoClientFactory: (c) => RepoClient(c, client: client),
      installSources: sources ?? FakeSources(),
    );
  });
  addTearDown(() {
    try {
      tempRoot.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may still hold a handle for a moment; the temp dir is disposable.
    }
  });
  await tester.pumpWidget(HelperApp(loader: () async => data!));
  await tester.pumpAndSettle();
  return tester.element(find.byType(MaterialApp)).read<AppState>();
}

/// Lets real async work (file IO, mock HTTP) started from a tap run to completion:
/// each cycle gives it real time, then a pump flushes its continuations.
Future<void> settleAsync(WidgetTester tester) async {
  for (var i = 0; i < 25; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

LibraryController library(WidgetTester tester) => tester.element(find.byType(MaterialApp)).read<LibraryController>();

void main() {
  testWidgets('empty Library shows "No games yet" with Add repository and Install from file', (tester) async {
    await pumpLibrary(tester);
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.text('No games yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add repository'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Install from file'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('startup opens the last game when installed, the Library otherwise', (tester) async {
    await pumpLibrary(tester, preinstalled: [miniZip()], prefs: {'app.lastGame': 'mini'});
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(navLabel('Gallery'), findsOneWidget);
  });

  testWidgets('a game that is not installed is not opened at startup', (tester) async {
    await pumpLibrary(tester, preinstalled: [miniZip()], prefs: {'app.lastGame': 'gone'});
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.text('Mini Game'), findsOneWidget);
  });

  testWidgets('tapping an installed game opens it; the switcher leads back to the Library', (tester) async {
    final app = await pumpLibrary(tester, preinstalled: [miniZip()]);
    await tester.tap(find.text('Mini Game'));
    await tester.pumpAndSettle();
    expect(app.active?.id, 'mini');
    expect(navLabel('Text'), findsOneWidget);
    await tester.tap(navLabel('Text'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('gameSwitcher')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);
  });

  testWidgets('repository entries show Install, Update and a disabled Needs app update (Review Focus 2)', (
    tester,
  ) async {
    await pumpLibrary(
      tester,
      preinstalled: [miniZip()],
      token: 'tok',
      repoIndex: {
        'name': 'Test repo',
        'modules': [
          {
            'id': 'mini',
            'name': 'Mini Game',
            'version': '2.0.0',
            'minAppVersion': '3.0.0',
            'zip': 'mini-2.zip',
            'size': 10,
          },
          {
            'id': 'other',
            'name': 'Other Game',
            'version': '1.0.0',
            'minAppVersion': '3.0.0',
            'zip': 'other.zip',
            'size': 10,
          },
          {
            'id': 'future',
            'name': 'Future Game',
            'version': '1.0.0',
            'minAppVersion': '9.0.0',
            'zip': 'future.zip',
            'size': 10,
          },
        ],
      },
      zips: {
        'mini-2.zip': miniZip(version: '2.0.0'),
        'other.zip': miniZip(id: 'other', name: 'Other Game'),
      },
    );
    expect(find.text('From Test repo'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Update'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Install'), findsOneWidget);
    final needs = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Needs app update'));
    expect(needs.onPressed, isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Install'));
    await settleAsync(tester);
    expect(library(tester).installed.map((i) => i.id), containsAll(['mini', 'other']));
    expect(find.text('Other Game'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Update'));
    await settleAsync(tester);
    expect(library(tester).installed.firstWhere((i) => i.id == 'mini').version, '2.0.0');
    expect(find.widgetWithText(FilledButton, 'Update'), findsNothing);
  });

  testWidgets('repository errors are shown in words', (tester) async {
    await pumpLibrary(tester, repoIndex: null, prefs: {RepoConfigStore.urlKey: indexUrl.toString()});
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't find index.json"), findsOneWidget);
  });

  testWidgets('long-press a game to uninstall it, behind a confirm', (tester) async {
    await pumpLibrary(tester, preinstalled: [miniZip()]);
    await tester.longPress(find.text('Mini Game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uninstall'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Uninstall Mini Game?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Mini Game'), findsOneWidget);

    await tester.longPress(find.text('Mini Game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uninstall'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Uninstall'));
    await settleAsync(tester);
    expect(find.text('No games yet'), findsOneWidget);
    expect(library(tester).installed, isEmpty);
  });

  testWidgets('review: an unexpected error while installing is shown, not swallowed', (tester) async {
    await pumpLibrary(tester, sources: FakeSources(pickError: StateError('picker exploded')));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Install from file'));
    await settleAsync(tester);
    expect(find.textContaining('picker exploded'), findsOneWidget);
  });

  testWidgets('Install from file installs the picked module and opens it', (tester) async {
    final app = await pumpLibrary(tester, sources: FakeSources(picked: miniZip()));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Install from file'));
    await settleAsync(tester);
    expect(app.active?.id, 'mini');
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('Review Focus 3: updating the open module keeps the screen and its zone badge', (tester) async {
    final app = await pumpLibrary(
      tester,
      preinstalled: [miniZip()],
      prefs: {
        'app.lastGame': 'mini',
        'mod.mini.zones': jsonEncode({'imp': 'a'}),
      },
    );
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('1')), findsOneWidget);
    await tester.runAsync(() => library(tester).installBytes(miniZip(version: '2.0.0')));
    await tester.pumpAndSettle();
    expect(app.active?.module.manifest.version, '2.0.0');
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the repository dialog saves url and token and reports a bad link', (tester) async {
    await pumpLibrary(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Add repository'));
    await tester.pumpAndSettle();
    expect(find.text('Repository'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('repoUrl')), 'https://nowhere.example/index.json');
    await tester.enterText(find.byKey(const Key('repoToken')), 'abc');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settleAsync(tester);
    expect(find.textContaining("Couldn't find index.json"), findsWidgets);
  });
}
