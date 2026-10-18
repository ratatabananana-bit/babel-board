import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_version.dart';
import '../module_format/validator.dart' show compareVersions;

/// Where the owner's module repository lives, and the read-only token for it.
class RepoConfig {
  RepoConfig({required this.indexUrl, this.token});
  final Uri indexUrl;
  final String? token;
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
  });

  final String id;
  final String name;
  final String version;
  final String minAppVersion;
  final Uri zipUrl;
  final Uri? iconUrl;
  final int size;

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
      entries.add(
        RepoEntry(
          id: id,
          name: raw['name'] as String? ?? id,
          version: '${raw['version'] ?? '0'}',
          minAppVersion: '${raw['minAppVersion'] ?? '0'}',
          zipUrl: config.indexUrl.resolve(zip),
          iconUrl: icon is String && icon.isNotEmpty ? config.indexUrl.resolve(icon) : null,
          size: (raw['size'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    return RepoListing(name: j['name'] as String? ?? config.indexUrl.host, entries: entries);
  }

  Future<Uint8List> download(Uri url) async => (await _get(url)).bodyBytes;

  Future<http.Response> _get(Uri url) async {
    final http.Response res;
    try {
      res = await _client.get(url, headers: headersFor(url));
    } catch (e) {
      throw RepoException(RepoError.network, 'No connection');
    }
    switch (res.statusCode) {
      case 200:
        return res;
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
        throw RepoException(RepoError.network, 'The repository answered HTTP ${res.statusCode}');
    }
  }
}
