import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_state.dart';
import '../modules/module_files.dart';
import '../modules/module_layer.dart';
import '../modules/module_state.dart';
import 'install_sources.dart';
import 'module_store.dart';
import 'repository.dart';
import 'startup.dart';

export 'startup.dart' show ExpansionState, ExpansionStatus;

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
    this.expansions = const {},
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

  /// Where each installed expansion stands: merged, switched off, waiting for its game, broken.
  Map<String, ExpansionStatus> expansions;
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

  /// A module's name for sentences ("install Vale of Eternity first"): installed, else as
  /// the repository lists it, else its id.
  String nameOf(String id) =>
      installedById(id)?.name ?? listing?.entries.where((e) => e.id == id).firstOrNull?.name ?? id;

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
    final loaded = await loadInstalledGames(prefs, installed);
    expansions = loaded.expansions;
    app.setGames([for (final m in loaded.modules) OpenGame.load(prefs, m)]);
    notifyListeners();
  }

  /// The Library's switch: an expansion off plays its game without it. Its tracked cards
  /// stay saved for when it is back on.
  Future<void> setExpansionEnabled(String id, bool on) async {
    if (on) {
      await prefs.remove(expansionEnabledKey(id));
    } else {
      await prefs.setBool(expansionEnabledKey(id), false);
    }
    await refresh();
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
    if (s == null) {
      // The store would have deleted a spooled download; without one, do it here.
      if (src case FileSource(temporary: true, :final file) when file.existsSync()) await file.delete();
      throw InstallException('Installing is not available here');
    }
    return _withBusy('Installing ${label ?? 'module'}…', () async {
      final InstalledModule m;
      try {
        m = await s.install(src, headersFor: headersFor);
      } on MissingBaseException catch (e) {
        throw MissingBaseException(expansion: e.expansion, baseId: e.baseId, baseName: nameOf(e.baseId));
      }
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

  /// Removes the module's files and every saved `mod.<id>.` key. An expansion's tracked
  /// cards live in its game's state: the entries for cards and zones only it provided go
  /// too, while those of the game and its other expansions (switched off or not) stay. A
  /// game's expansions stay installed, waiting for it.
  Future<void> uninstall(String id) async {
    final s = store;
    if (s == null) return;
    if (app.active?.id == id) app.showLibrary();
    final removed = installedById(id);
    final baseId = removed?.expands?.id;
    final removedLayer = baseId == null ? null : await _layerOf(removed!);
    await s.uninstall(id);
    for (final k in prefs.getKeys().where((k) => k.startsWith('mod.$id.')).toList()) {
      await prefs.remove(k);
    }
    await refresh();
    if (baseId == null || removedLayer == null) return;
    final still = [
      for (final m in installed)
        if (m.id == baseId || m.expands?.id == baseId) ?await _layerOf(m),
    ];
    final zones = app.games.where((g) => g.id == baseId).firstOrNull?.zones ?? ZoneState(prefs, baseId);
    zones.forget(
      items: removedLayer.itemIds.difference({for (final l in still) ...l.itemIds}),
      zones: removedLayer.zoneIds.difference({for (final l in still) ...l.zoneIds}),
    );
  }

  /// [m] as read from its folder, or null when it is gone or can't be read.
  Future<ModuleLayer?> _layerOf(InstalledModule m) async {
    final dir = m.dir;
    if (dir == null) return null;
    try {
      return await readModuleLayer(DirectoryModuleFiles(dir));
    } on ModuleLoadException {
      return null;
    }
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
