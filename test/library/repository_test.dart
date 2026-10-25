import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vale_helper/app_version.dart';
import 'package:vale_helper/library/module_store.dart';
import 'package:vale_helper/library/repository.dart';

final indexUrl = Uri.parse('https://raw.githubusercontent.com/owner/repo/main/index.json');

Map<String, dynamic> index() => {
  'name': 'Our games',
  'modules': [
    {
      'id': 'vale-of-eternity',
      'name': 'Vale of Eternity',
      'version': '1.0.0',
      'minAppVersion': '3.0.0',
      'zip': 'vale-of-eternity-1.0.0.zip',
      'icon': 'icons/vale-of-eternity.webp',
      'size': 1234,
    },
    {
      'id': 'future',
      'name': 'Future Game',
      'version': '2.0.0',
      'minAppVersion': '9.0.0',
      'zip': 'https://evil.example/x.zip',
      'size': 99,
    },
  ],
};

void main() {
  group('repository links people paste', _candidates);
  test('entries resolve relative zip and icon against the index url; needsAppUpdate', () async {
    final client = MockClient((req) async => http.Response(jsonEncode(index()), 200));
    final repo = RepoClient(
      RepoConfig(indexUrl: indexUrl, token: 'tok'),
      client: client,
    );
    final listing = await repo.fetchIndex();
    expect(listing.name, 'Our games');
    final v = listing.entries[0];
    expect(v.zipUrl.toString(), 'https://raw.githubusercontent.com/owner/repo/main/vale-of-eternity-1.0.0.zip');
    expect(v.iconUrl.toString(), 'https://raw.githubusercontent.com/owner/repo/main/icons/vale-of-eternity.webp');
    expect(v.size, 1234);
    expect(v.needsAppUpdate, isFalse);
    final f = listing.entries[1];
    expect(f.iconUrl, isNull);
    expect(f.needsAppUpdate, isTrue, reason: 'minAppVersion 9.0.0 > $kAppVersion');
    expect(v.expands, isNull);
  });

  test('an index entry names the game an expansion is for', () async {
    final i = index();
    (i['modules'] as List).add({
      'id': 'vale-of-eternity-curse',
      'name': 'Vale of Eternity: Curse',
      'version': '1.0.0',
      'minAppVersion': '3.3.0',
      'zip': 'vale-of-eternity-curse-1.0.0.zip',
      'expands': 'vale-of-eternity',
    });
    final client = MockClient((req) async => http.Response(jsonEncode(i), 200));
    final listing = await RepoClient(RepoConfig(indexUrl: indexUrl), client: client).fetchIndex();
    expect(listing.entries.last.expands, 'vale-of-eternity');
  });

  test('errors: 404 → notFound, 401/403 → tokenRejected, bad JSON → badIndex, network → network', () async {
    Future<RepoError> kindFor(http.Client client) async {
      try {
        await RepoClient(RepoConfig(indexUrl: indexUrl), client: client).fetchIndex();
      } on RepoException catch (e) {
        return e.kind;
      }
      fail('expected a RepoException');
    }

    expect(await kindFor(MockClient((_) async => http.Response('', 404))), RepoError.notFound);
    expect(await kindFor(MockClient((_) async => http.Response('', 401))), RepoError.tokenRejected);
    expect(await kindFor(MockClient((_) async => http.Response('', 403))), RepoError.tokenRejected);
    expect(await kindFor(MockClient((_) async => http.Response('<html>', 200))), RepoError.badIndex);
    expect(await kindFor(MockClient((_) async => http.Response('{"name":"x"}', 200))), RepoError.badIndex);
    expect(await kindFor(MockClient((_) async => throw http.ClientException('offline'))), RepoError.network);
  });

  test('review: with a token set, "not found" also points at the token (GitHub hides private files)', () async {
    Future<String> messageFor(String? token) async {
      try {
        await RepoClient(
          RepoConfig(indexUrl: indexUrl, token: token),
          client: MockClient((_) async => http.Response('', 404)),
        ).fetchIndex();
      } on RepoException catch (e) {
        expect(e.kind, RepoError.notFound);
        return e.message;
      }
      fail('expected a RepoException');
    }

    expect(await messageFor(null), isNot(contains('token')));
    expect(await messageFor('tok'), contains('token'));
  });

  test('Review Focus 5: the token goes only to the index host', () async {
    final seen = <Uri, Map<String, String>>{};
    final client = MockClient((req) async {
      seen[req.url] = req.headers;
      return http.Response.bytes([1, 2, 3], 200);
    });
    final repo = RepoClient(
      RepoConfig(indexUrl: indexUrl, token: 'secret'),
      client: client,
    );
    expect(repo.headersFor(indexUrl.resolve('a.zip'))['Authorization'], 'Bearer secret');
    expect(repo.headersFor(Uri.parse('https://evil.example/x.zip')).containsKey('Authorization'), isFalse);

    await repo.download(indexUrl.resolve('a.zip'));
    await repo.download(Uri.parse('https://evil.example/x.zip'));
    expect(seen[indexUrl.resolve('a.zip')]!['Authorization'], 'Bearer secret');
    expect(seen[Uri.parse('https://evil.example/x.zip')]!.containsKey('Authorization'), isFalse);
  });

  test('download streams the file to disk and hands back a FileSource', () async {
    final repo = RepoClient(RepoConfig(indexUrl: indexUrl), client: MockClient((_) async => http.Response.bytes([1, 2, 3], 200)));
    final src = await repo.download(indexUrl.resolve('a.zip'));
    expect(src, isA<FileSource>());
    final f = (src as FileSource).file;
    expect(f.readAsBytesSync(), [1, 2, 3]);
    expect(src.temporary, isTrue);
    f.deleteSync();
  });

  test('download errors map to RepoException kinds', () async {
    final repo = RepoClient(
      RepoConfig(indexUrl: indexUrl, token: 't'),
      client: MockClient((_) async => http.Response('', 403)),
    );
    await expectLater(
      repo.download(indexUrl.resolve('a.zip')),
      throwsA(isA<RepoException>().having((e) => e.kind, 'kind', RepoError.tokenRejected)),
    );
  });

  test('RepoConfigStore saves the url in prefs and the token in secure storage', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final secure = <String, String>{};
    final store = RepoConfigStore(
      prefs,
      readSecret: (k) async => secure[k],
      writeSecret: (k, v) async {
        if (v == null) {
          secure.remove(k);
        } else {
          secure[k] = v;
        }
      },
    );
    expect(await store.load(), isNull);
    await store.save(RepoConfig(indexUrl: indexUrl, token: 'tok'));
    expect(prefs.getString('repo.indexUrl'), indexUrl.toString());
    expect(prefs.getKeys().any((k) => prefs.get(k) == 'tok'), isFalse, reason: 'token never in prefs');
    expect(secure['repo.token'], 'tok');
    final loaded = await store.load();
    expect(loaded!.indexUrl, indexUrl);
    expect(loaded.token, 'tok');
    await store.clear();
    expect(await store.load(), isNull);
    expect(secure, isEmpty);
  });
}

void _candidates() {
  List<String> c(String s) => repoIndexCandidates(s).map((u) => u.toString()).toList();
  test('a GitHub repository link resolves to index.json on main, then master', () {
    expect(c('https://github.com/you/games'), [
      'https://raw.githubusercontent.com/you/games/main/index.json',
      'https://raw.githubusercontent.com/you/games/master/index.json',
    ]);
    expect(c('github.com/you/games/'), c('https://github.com/you/games'), reason: 'no scheme, trailing slash');
    expect(c('https://github.com/you/games.git'), c('https://github.com/you/games'));
    expect(c('https://www.github.com/you/games?tab=readme'), c('https://github.com/you/games'));
  });
  test('a branch or folder page pins the branch', () {
    expect(c('https://github.com/you/games/tree/dev'), ['https://raw.githubusercontent.com/you/games/dev/index.json']);
    expect(c('https://github.com/you/games/tree/main/packed'), [
      'https://raw.githubusercontent.com/you/games/main/packed/index.json',
    ]);
  });
  test('raw, folder and index links pass through', () {
    expect(c('https://raw.githubusercontent.com/you/games/main/index.json'), [
      'https://raw.githubusercontent.com/you/games/main/index.json',
    ]);
    expect(c('https://example.org/games'), ['https://example.org/games/index.json']);
    expect(c('https://example.org/games/custom.json'), ['https://example.org/games/custom.json']);
  });
  test('not a link: nothing', () {
    expect(c(''), isEmpty);
    expect(c('   '), isEmpty);
    expect(c('just words'), isEmpty);
  });
  test('displayName is owner/repo for GitHub, else the host', () {
    expect(
      RepoConfig(indexUrl: Uri.parse('https://raw.githubusercontent.com/you/games/main/index.json')).displayName,
      'you/games',
    );
    expect(RepoConfig(indexUrl: Uri.parse('https://example.org/games/index.json')).displayName, 'example.org');
  });
}
