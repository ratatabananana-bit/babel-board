import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_state.dart';
import '../modules/loaded_module.dart';
import '../modules/module_files.dart';
import 'install_sources.dart';
import 'module_store.dart';
import 'repository.dart';

/// What the Library screen works with: installed modules, the repository listing, and
/// the install/update/uninstall actions. Keeps [AppState.games] in step with the store.
class LibraryController extends ChangeNotifier {
  LibraryController({
    required this.prefs,
    required this.app,
    this.store,
    this.repoConfigStore,
    RepoClient Function(RepoConfig config)? repoClientFactory,
    InstallSources? sources,
    this.installed = const [],
  }) : _repoClientFactory = repoClientFactory ?? ((c) => RepoClient(c)),
       sources = sources ?? InstallSources();

  final SharedPreferences prefs;
  final AppState app;

  /// Null on the web preview, where nothing can be installed.
  final ModuleStore? store;
  final RepoConfigStore? repoConfigStore;
  final RepoClient Function(RepoConfig config) _repoClientFactory;
  final InstallSources sources;

  List<InstalledModule> installed;
  RepoConfig? repo;
  RepoClient? _repoClient;
  RepoListing? listing;
  String? repoError;
  bool loadingRepo = false;

  /// Non-null while an install or download runs; shown as a progress line.
  String? busy;

  /// One-line notices for the UI (snackbars).
  final messages = StreamController<String>.broadcast();

  bool get canInstall => store != null;

  Map<String, String> headersFor(Uri url) => _repoClient?.headersFor(url) ?? const {};

  /// What the Library lists: the store's modules, or (web preview, tests) the loaded games.
  List<InstalledModule> get shown => store != null
      ? installed
      : [for (final g in app.games) InstalledModule(id: g.id, name: g.title, version: g.module.manifest.version)];

  InstalledModule? installedById(String id) => installed.where((i) => i.id == id).firstOrNull;

  /// Loads the repository config and listing, and the installed list.
  Future<void> init() async {
    final c = await repoConfigStore?.load();
    if (c != null) {
      repo = c;
      _repoClient = _repoClientFactory(c);
      notifyListeners();
      unawaited(refreshRepo());
    }
  }

  /// Re-reads the store and rebuilds the app's games from it.
  Future<void> refresh() async {
    final s = store;
    if (s == null) return;
    installed = await s.list();
    final games = <OpenGame>[];
    for (final i in installed) {
      if (i.broken) continue;
      try {
        games.add(OpenGame.load(prefs, await loadModule(DirectoryModuleFiles(i.dir!))));
      } catch (e) {
        // list() already marked it broken; a race here just leaves it out.
      }
    }
    app.setGames(games);
    notifyListeners();
  }

  Future<void> refreshRepo() async {
    final client = _repoClient;
    if (client == null) return;
    loadingRepo = true;
    repoError = null;
    notifyListeners();
    try {
      listing = await client.fetchIndex();
    } on RepoException catch (e) {
      listing = null;
      repoError = e.message;
    } finally {
      loadingRepo = false;
      notifyListeners();
    }
  }

  /// Connects to whatever link a person pasted (a GitHub repository page, a raw link, or
  /// the index itself): tries each candidate index link, saves the first that answers, and
  /// returns its listing. Throws [RepoException] with the last failure, or a
  /// [RepoError.badIndex] one when the text is not a link.
  Future<RepoListing> connectRepo(String input, {String? token}) async {
    final candidates = repoIndexCandidates(input);
    if (candidates.isEmpty) {
      throw RepoException(RepoError.badIndex, 'Paste a link, like https://github.com/you/your-games');
    }
    RepoException? last;
    for (final url in candidates) {
      final config = RepoConfig(indexUrl: url, token: token == null || token.isEmpty ? null : token);
      try {
        await saveRepo(config);
        return listing!;
      } on RepoException catch (e) {
        last = e;
        if (e.kind != RepoError.notFound) break; // a bad token or no network won't improve on another branch
      }
    }
    throw last!;
  }

  /// Tests the connection, then saves. Throws [RepoException] when the index can't be read.
  Future<void> saveRepo(RepoConfig c) async {
    final client = _repoClientFactory(c);
    final l = await client.fetchIndex();
    await repoConfigStore?.save(c);
    repo = c;
    _repoClient = client;
    listing = l;
    repoError = null;
    notifyListeners();
  }

  Future<void> clearRepo() async {
    await repoConfigStore?.clear();
    repo = null;
    _repoClient = null;
    listing = null;
    repoError = null;
    notifyListeners();
  }

  /// Installs module bytes; on success the app's games are refreshed and, if [open], the
  /// game is opened. Throws [InstallException].
  Future<InstalledModule?> installBytes(Uint8List bytes, {bool open = false, String? label}) =>
      installSource(BytesSource(bytes), open: open, label: label);

  /// Installs a module from bytes or a file; on success the app's games are refreshed and,
  /// if [open], the game is opened. Throws [InstallException].
  Future<InstalledModule?> installSource(ModuleSource src, {bool open = false, String? label}) async {
    final s = store;
    if (s == null) throw InstallException('Installing is not available here');
    return _withBusy('Installing ${label ?? 'module'}…', () async {
      final m = await s.install(src, headersFor: headersFor);
      await refresh();
      // The game played last (before an update, or before reinstalling) opens as soon as
      // it is installed again, so the owner lands back in it.
      final remembered = app.active == null && prefs.getString(AppState.lastGameKey) == m.id;
      if (open || remembered) app.open(m.id);
      messages.add('Installed ${m.name} ${m.version}');
      return m;
    });
  }

  Future<InstalledModule?> installEntry(RepoEntry e) async {
    final client = _repoClient;
    if (client == null) throw InstallException('No repository is set up');
    final src = await _withBusy('Downloading ${e.name}…', () => client.download(e.zipUrl));
    return installSource(src!, label: e.name);
  }

  Future<InstalledModule?> installLink(Uri url) async {
    final src = await _withBusy('Downloading…', () => sources.downloadLink(url, headersFor: headersFor));
    return installSource(src!, open: true);
  }

  Future<InstalledModule?> installFromFile() async {
    final src = await sources.pickModuleFile();
    if (src == null) return null;
    return installSource(src, open: true);
  }

  /// Removes the module's files and every saved `mod.<id>.` key.
  Future<void> uninstall(String id) async {
    final s = store;
    if (s == null) return;
    if (app.active?.id == id) app.showLibrary();
    await s.uninstall(id);
    for (final k in prefs.getKeys().where((k) => k.startsWith('mod.$id.')).toList()) {
      await prefs.remove(k);
    }
    await refresh();
  }

  /// Installs whatever arrives from the share sheet and opens it.
  void listenForSharedFiles() {
    sources.sharedFiles().listen((src) async {
      try {
        await installSource(src, open: true);
      } on InstallException catch (e) {
        messages.add(e.message);
      } catch (e) {
        messages.add('Could not install: $e');
      }
    });
  }

  Future<T?> _withBusy<T>(String what, Future<T> Function() run) async {
    busy = what;
    notifyListeners();
    try {
      return await run();
    } finally {
      busy = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    messages.close();
    super.dispose();
  }
}
