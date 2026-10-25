import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_version.dart';
import '../module_format/validator.dart' show compareVersions;
import 'module_store.dart' show InstallException, ModuleSource, spoolToTempFile;

/// Where the owner's module repository lives, and the read-only token for it.
class RepoConfig {
  RepoConfig({required this.indexUrl, this.token});
  final Uri indexUrl;
  final String? token;

  /// "owner/repo" for a GitHub repository, else the host.
  String get displayName {
    final u = indexUrl;
    if (u.host == 'raw.githubusercontent.com' && u.pathSegments.length >= 2) {
      return '${u.pathSegments[0]}/${u.pathSegments[1]}';
    }
    return u.host;
  }
}

final _github = RegExp(r'^(?:https?://)?(?:www\.)?github\.com/([^/\s]+)/([^/\s#?]+?)(?:\.git)?(?:/tree/([^/\s#?]+)(/.*)?|/)?(?:[#?].*)?$');

/// Turns whatever a person pastes into the index links to try, in order: a GitHub
/// repository page (`github.com/owner/repo`, with or without `/tree/branch`), a raw link,
/// a folder link, or the `index.json` link itself. Empty when it is not a link at all.
List<Uri> repoIndexCandidates(String input) {
  var s = input.trim();
  if (s.isEmpty) return const [];
  if (!s.contains('://')) s = 'https://$s';
  final gh = _github.firstMatch(s);
  if (gh != null) {
    final owner = gh.group(1)!;
    final repo = gh.group(2)!;
    final branch = gh.group(3);
    var path = (gh.group(4) ?? '').replaceAll(RegExp(r'^/|/$'), '');
    if (path.isNotEmpty) path = '$path/';
    Uri raw(String b) => Uri.parse('https://raw.githubusercontent.com/$owner/$repo/$b/${path}index.json');
    return branch != null ? [raw(branch)] : [raw('main'), raw('master')];
  }
  final u = Uri.tryParse(s);
  if (u == null || !u.hasScheme || u.host.isEmpty || !u.host.contains('.') || input.trim().contains(' ')) {
    return const [];
  }
  if (u.path.endsWith('.json')) return [u];
  return [u.replace(path: '${u.path.endsWith('/') ? u.path : '${u.path}/'}index.json')];
}

/// Persists [RepoConfig]: the URL in shared preferences, the token in secure storage.
/// The secret reader/writer are injectable so tests (and the web) need no plugin.
class RepoConfigStore {
  RepoConfigStore(this._prefs, {required this.readSecret, required this.writeSecret});

  static const urlKey = 'repo.indexUrl';
  static const tokenKey = 'repo.token';

  final SharedPreferences _prefs;
  final Future<String?> Function(String key) readSecret;
  final Future<void> Function(String key, String? value) writeSecret;

  Future<RepoConfig?> load() async {
    final raw = _prefs.getString(urlKey);
    if (raw == null) return null;
    final url = Uri.tryParse(raw);
    if (url == null) return null;
    final token = await readSecret(tokenKey);
    return RepoConfig(indexUrl: url, token: token == null || token.isEmpty ? null : token);
  }

  Future<void> save(RepoConfig c) async {
    await _prefs.setString(urlKey, c.indexUrl.toString());
    await writeSecret(tokenKey, c.token == null || c.token!.isEmpty ? null : c.token);
  }

  Future<void> clear() async {
    await _prefs.remove(urlKey);
    await writeSecret(tokenKey, null);
  }
}

class RepoEntry {
  RepoEntry({
    required this.id,
    required this.name,
    required this.version,
    required this.minAppVersion,
    required this.zipUrl,
    required this.size,
    this.iconUrl,
    this.expands,
  });

  final String id;
  final String name;
  final String version;
  final String minAppVersion;
  final Uri zipUrl;
  final Uri? iconUrl;
  final int size;

  /// The id of the game this entry is an expansion for; null for a game.
  final String? expands;

  bool get needsAppUpdate => compareVersions(minAppVersion, kAppVersion) > 0;
}

class RepoListing {
  RepoListing({required this.name, required this.entries});
  final String name;
  final List<RepoEntry> entries;
}

enum RepoError { notFound, tokenRejected, network, badIndex }

class RepoException implements Exception {
  RepoException(this.kind, this.message);
  final RepoError kind;
  final String message;

  @override
  String toString() => message;
}

/// Reads a repository index and downloads its files. The token is sent only to the
/// host the index lives on, never to another host an entry might point at.
class RepoClient {
  RepoClient(this.config, {http.Client? client}) : _client = client ?? http.Client();

  final RepoConfig config;
  final http.Client _client;

  Map<String, String> headersFor(Uri url) {
    final t = config.token;
    if (t == null || t.isEmpty || url.host != config.indexUrl.host) return const {};
    return {'Authorization': 'Bearer $t'};
  }

  Future<RepoListing> fetchIndex() async {
    final res = await _get(config.indexUrl);
    final Object? j;
    try {
      j = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw RepoException(RepoError.badIndex, "That file isn't a Babel Board repository");
    }
    if (j is! Map || j['modules'] is! List) {
      throw RepoException(RepoError.badIndex, "That file isn't a Babel Board repository");
    }
    final entries = <RepoEntry>[];
    for (final raw in j['modules'] as List) {
      if (raw is! Map) continue;
      final zip = raw['zip'];
      final id = raw['id'];
      if (zip is! String || id is! String) continue;
      final icon = raw['icon'];
      final expands = raw['expands'];
      entries.add(
        RepoEntry(
          id: id,
          name: raw['name'] as String? ?? id,
          version: '${raw['version'] ?? '0'}',
          minAppVersion: '${raw['minAppVersion'] ?? '0'}',
          zipUrl: config.indexUrl.resolve(zip),
          iconUrl: icon is String && icon.isNotEmpty ? config.indexUrl.resolve(icon) : null,
          size: (raw['size'] as num?)?.toInt() ?? 0,
          expands: expands is String && expands.isNotEmpty ? expands : null,
        ),
      );
    }
    return RepoListing(name: j['name'] as String? ?? config.indexUrl.host, entries: entries);
  }

  /// Downloads a module zip to a temp file as it arrives (never whole in memory).
  Future<ModuleSource> download(Uri url) async {
    final http.StreamedResponse res;
    try {
      res = await _client.send(http.Request('GET', url)..headers.addAll(headersFor(url)));
    } catch (e) {
      throw RepoException(RepoError.network, 'No connection');
    }
    if (res.statusCode != 200) {
      // Let the connection go before reporting the status.
      await res.stream.drain<void>().catchError((_) {});
      _checkStatus(res.statusCode);
    }
    try {
      return await spoolToTempFile(res.stream);
    } on InstallException catch (e) {
      throw RepoException(RepoError.network, e.message);
    }
  }

  Future<http.Response> _get(Uri url) async {
    final http.Response res;
    try {
      res = await _client.get(url, headers: headersFor(url));
    } catch (e) {
      throw RepoException(RepoError.network, 'No connection');
    }
    _checkStatus(res.statusCode);
    return res;
  }

  void _checkStatus(int statusCode) {
    switch (statusCode) {
      case 200:
        return;
      case 401:
      case 403:
        throw RepoException(RepoError.tokenRejected, 'GitHub rejected the token');
      case 404:
        // GitHub answers "not found" (not "forbidden") for a private file and a bad token.
        final t = config.token;
        throw RepoException(
          RepoError.notFound,
          t == null || t.isEmpty
              ? "Couldn't find index.json at that link"
              : "Couldn't find index.json at that link, or GitHub rejected the token "
                    '(for a private repo GitHub answers "not found" to a wrong token)',
        );
      default:
        throw RepoException(RepoError.network, 'The repository answered HTTP $statusCode');
    }
  }
}
