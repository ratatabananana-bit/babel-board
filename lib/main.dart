import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'blocks/icons.dart';
import 'blocks/registry.dart';
import 'core/app_state.dart';
import 'library/migration.dart';
import 'core/settings.dart';
import 'core/theme.dart';
import 'library/install_sources.dart';
import 'library/library_controller.dart';
import 'library/library_screen.dart';
import 'library/module_store.dart';
import 'library/repository.dart';
import 'library/startup.dart';
import 'modules/loaded_module.dart';
import 'modules/module_files.dart';
import 'modules/module_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HelperApp());
}

/// Everything the app needs before its first frame.
class AppData {
  const AppData(
    this.prefs,
    this.modules, {
    this.installed = const [],
    this.store,
    this.repoConfigStore,
    this.repoClientFactory,
    this.installSources,
  });

  final SharedPreferences prefs;
  final List<LoadedModule> modules;

  /// What the store listed at startup, including broken modules.
  final List<InstalledModule> installed;

  /// Null on the web preview: nothing can be installed there.
  final ModuleStore? store;
  final RepoConfigStore? repoConfigStore;
  final RepoClient Function(RepoConfig config)? repoClientFactory;
  final InstallSources? installSources;

  /// Loads every installed module from [store]; broken ones are left out (the Library
  /// still lists them from the store).
  static Future<AppData> fromStore(
    SharedPreferences prefs,
    ModuleStore store, {
    RepoConfigStore? repoConfigStore,
    RepoClient Function(RepoConfig config)? repoClientFactory,
    InstallSources? installSources,
  }) async {
    final modules = <LoadedModule>[];
    final installed = await store.list();
    for (final i in installed) {
      if (i.broken) continue;
      try {
        modules.add(await loadModule(DirectoryModuleFiles(i.dir)));
      } catch (_) {
        // Listed as broken by the Library.
      }
    }
    return AppData(
      prefs,
      modules,
      installed: installed,
      store: store,
      repoConfigStore: repoConfigStore,
      repoClientFactory: repoClientFactory,
      installSources: installSources,
    );
  }
}

/// Startup. On a phone the module store lives in the app's support folder; the web
/// preview shows the modules published next to it and has no install sources.
Future<AppData> loadAppData() async {
  final prefs = await SharedPreferences.getInstance();
  await migrateLegacyPrefs(prefs);
  if (kIsWeb) return AppData(prefs, await loadWebModules(Uri.base));
  final support = await getApplicationSupportDirectory();
  final store = createModuleStore(Directory('${support.path}${Platform.pathSeparator}modules'), prefs);
  const secure = FlutterSecureStorage();
  final repoConfigStore = RepoConfigStore(
    prefs,
    readSecret: (k) => secure.read(key: k),
    writeSecret: (k, v) => v == null ? secure.delete(key: k) : secure.write(key: k, value: v),
  );
  return AppData.fromStore(prefs, store, repoConfigStore: repoConfigStore);
}

class HelperApp extends StatefulWidget {
  const HelperApp({super.key, this.loader = loadAppData});

  final Future<AppData> Function() loader;

  @override
  State<HelperApp> createState() => _HelperAppState();
}

class _HelperAppState extends State<HelperApp> {
  late final Future<AppData> _data = widget.loader();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  AppState? _app;
  LibraryController? _library;
  List<String> _shortcutIds = const [];

  Widget _material({required Widget home, TransitionBuilder? builder}) => MaterialApp(
    title: 'Table Helper',
    debugShowCheckedModeBanner: false,
    scaffoldMessengerKey: _messenger,
    theme: buildTheme(Palette.light, Brightness.light),
    darkTheme: buildTheme(Palette.dark, Brightness.dark),
    builder: builder,
    home: home,
  );

  /// Long-press the app icon to jump straight into a game (Android only).
  Future<void> _setUpShortcuts(AppState app) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final ids = [for (final g in app.games) g.id];
    if (listEquals(ids, _shortcutIds)) return;
    _shortcutIds = ids;
    const actions = QuickActions();
    try {
      await actions.initialize(app.open);
      await actions.setShortcutItems([for (final g in app.games) ShortcutItem(type: g.id, localizedTitle: g.title)]);
    } on MissingPluginException {
      // Not available here (e.g. in tests); shortcuts are a nice-to-have.
    } on PlatformException {
      // Launcher doesn't support shortcuts.
    }
  }

  void _start(AppData d) {
    final app = AppState(d.prefs, [for (final m in d.modules) OpenGame.load(d.prefs, m)]);
    final library = LibraryController(
      prefs: d.prefs,
      app: app,
      store: d.store,
      repoConfigStore: d.repoConfigStore,
      repoClientFactory: d.repoClientFactory,
      sources: d.installSources,
      installed: d.installed,
    );
    _app = app;
    _library = library;
    app.addListener(() => _setUpShortcuts(app));
    _setUpShortcuts(app);
    library.messages.stream.listen((m) => _messenger.currentState?.showSnackBar(SnackBar(content: Text(m))));
    // The games and installed list are already loaded; init() picks up the repository.
    library.init();
    library.listenForSharedFiles();
  }

  @override
  void dispose() {
    _library?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppData>(
      future: _data,
      builder: (context, snap) {
        if (snap.hasError) {
          return _material(
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load game data:\n${snap.error}', textAlign: TextAlign.center),
                ),
              ),
            ),
          );
        }
        final d = snap.data;
        if (d == null) {
          return _material(
            home: const Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        if (_app == null) _start(d);
        // Shared providers sit above MaterialApp; the active module's scope wraps the
        // Navigator (via builder) so its sheets and dialogs can read it too.
        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: _app!),
            ChangeNotifierProvider.value(value: _library!),
            ChangeNotifierProvider(create: (_) => Settings(d.prefs)),
          ],
          child: Consumer<AppState>(
            builder: (context, app, _) => _material(
              builder: (context, child) {
                final g = app.active;
                if (g == null) return child!;
                return ModuleScope(module: g.module, zones: g.zones, flow: g.flow, child: child!);
              },
              home: const _Home(),
            ),
          ),
        );
      },
    );
  }
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<AppState>().active;
    if (game == null) return const LibraryScreen();
    return GameShell(key: ValueKey(game.id), game: game);
  }
}

/// A game's tabs, one block tree each: swipe between them or use the bottom bar.
class GameShell extends StatefulWidget {
  const GameShell({super.key, required this.game});
  final OpenGame game;

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  final _pages = PageController();
  int _tab = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    setState(() => _tab = i);
    _pages.animateToPage(i, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final tabs = widget.game.module.manifest.tabs;
    final tab = _tab.clamp(0, tabs.length - 1);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: PageView(
          controller: _pages,
          onPageChanged: (i) => setState(() => _tab = i),
          children: [for (final t in tabs) _KeepAlive(Builder(builder: (context) => buildBlock(context, t.block)))],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.surface2)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith(
              (s) => TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: s.contains(WidgetState.selected) ? p.text : p.muted,
              ),
            ),
            iconTheme: WidgetStateProperty.resolveWith(
              (s) => IconThemeData(size: 23, color: s.contains(WidgetState.selected) ? p.text : p.muted),
            ),
          ),
          child: NavigationBar(
            height: 72,
            backgroundColor: Color.lerp(p.bg, p.surface, 0.45),
            indicatorColor: p.surface2,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            selectedIndex: tab,
            onDestinationSelected: _goTo,
            destinations: [
              for (final t in tabs)
                NavigationDestination(
                  label: t.label,
                  icon: Builder(
                    builder: (context) {
                      final n = t.badge == 'zoneCount' ? context.watch<ZoneState>().total : 0;
                      return Badge(
                        isLabelVisible: n > 0,
                        backgroundColor: p.badge,
                        textColor: p.onAccent,
                        label: Text('$n', style: const TextStyle(fontWeight: FontWeight.w800)),
                        child: Icon(moduleIcon(t.icon)),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keeps a tab's state (filters, scroll position) while swiping between tabs.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive(this.child);
  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
