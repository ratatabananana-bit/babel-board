import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../modules/loaded_module.dart';
import '../modules/module_files.dart';

class InstallException implements Exception {
  InstallException(this.message, [this.issues = const []]);
  final String message;
  final List<ValidationIssue> issues;

  @override
  String toString() => issues.isEmpty ? message : '$message\n${issues.where((i) => i.fatal).join('\n')}';
}

class InstalledModule {
  InstalledModule({
    required this.id,
    required this.name,
    required this.version,
    this.dir,
    this.broken = false,
    this.error,
  });
  final String id;
  final String name;
  final String version;

  /// The installed folder; null for a game that wasn't installed through a store (web preview).
  final Directory? dir;
  final bool broken;
  final String? error;
}

/// Installs, updates, lists and removes modules under one folder: `root/<id>/`.
/// Saved state lives in preferences, not here, so updating a module keeps it.
class ModuleStore {
  ModuleStore(this.root, {http.Client? client, this.imageTimeout = const Duration(seconds: 15), this.onInstalled})
    : _client = client;

  final Directory root;
  final http.Client? _client;
  final Duration imageTimeout;

  /// Called with the module id after every successful install (e.g. to adopt legacy state).
  final Future<void> Function(String id)? onInstalled;

  static const maxZipBytes = 50 * 1024 * 1024;
  static const maxTotalBytes = 150 * 1024 * 1024;
  static const maxFileBytes = 15 * 1024 * 1024;
  static const allowedExtensions = {'.json', '.webp', '.png', '.jpg', '.jpeg'};
  static const _maxParallelDownloads = 6;

  String _p(String a, [String? b, String? c]) =>
      [a, ?b, ?c].join(Platform.pathSeparator).replaceAll('/', Platform.pathSeparator);

  Future<List<InstalledModule>> list() async {
    if (!root.existsSync()) return const [];
    final out = <InstalledModule>[];
    final dirs = root.listSync().whereType<Directory>().toList()..sort((a, b) => a.path.compareTo(b.path));
    for (final d in dirs) {
      final folder = d.path.split(Platform.pathSeparator).last;
      if (folder.startsWith('.')) continue;
      try {
        final m = await loadModule(DirectoryModuleFiles(d));
        out.add(InstalledModule(id: m.manifest.id, name: m.manifest.name, version: m.manifest.version, dir: d));
      } catch (e) {
        out.add(InstalledModule(id: folder, name: folder, version: '?', dir: d, broken: true, error: '$e'));
      }
    }
    return out;
  }

  Future<void> uninstall(String id) async {
    final d = Directory(_p(root.path, id));
    if (d.existsSync()) await d.delete(recursive: true);
  }

  /// Installs a zip or a single-JSON module. Validates everything in a staging folder
  /// first, downloads image links, and only then swaps the folder into place.
  Future<InstalledModule> installBytes(
    Uint8List bytes, {
    Uri? sourceUrl,
    Map<String, String> Function(Uri url)? headersFor,
  }) async {
    root.createSync(recursive: true);
    final stagingRoot = Directory(_p(root.path, '.staging'))..createSync();
    final staging = Directory(_p(stagingRoot.path, '${DateTime.now().microsecondsSinceEpoch}'))..createSync();
    try {
      if (_isZip(bytes)) {
        _unzip(bytes, staging);
        // A zip may still carry inline items; store them as files like the single-JSON form,
        // so their image links are downloaded too.
        final manifestFile = _staged(staging, 'module.json');
        final Object? j;
        try {
          j = jsonDecode(manifestFile.readAsStringSync());
        } on FormatException {
          throw InstallException('module.json in this zip is not valid JSON');
        }
        if (j is Map) _writeManifest(j.cast<String, dynamic>(), staging);
      } else {
        _writeSingleJson(bytes, staging);
      }
      await _fetchRemoteImages(staging, headersFor);

      final LoadedModule loaded;
      try {
        loaded = await loadModule(DirectoryModuleFiles(staging));
      } on ModuleLoadException catch (e) {
        final first = e.issues.where((i) => i.fatal).firstOrNull;
        throw InstallException(first == null ? 'This file is not a valid game module' : first.message, e.issues);
      }
      final id = loaded.manifest.id;
      if (!RegExp(r'^[a-z0-9][a-z0-9._-]*$').hasMatch(id)) {
        throw InstallException('Module id "$id" may only use lowercase letters, digits, "-", "_" and "."');
      }
      final target = Directory(_p(root.path, id));
      final old = Directory(_p(root.path, '.old-$id-${DateTime.now().microsecondsSinceEpoch}'));
      if (target.existsSync()) await target.rename(old.path);
      try {
        await staging.rename(target.path);
      } catch (_) {
        if (old.existsSync()) await old.rename(target.path);
        rethrow;
      }
      if (old.existsSync()) await old.delete(recursive: true);
      await onInstalled?.call(id);
      return InstalledModule(id: id, name: loaded.manifest.name, version: loaded.manifest.version, dir: target);
    } on InstallException {
      rethrow;
    } catch (e) {
      // Anything else (a broken zip, a value of the wrong type, a disk error) still reaches
      // the person as a message, never as a silent failure.
      throw InstallException('This module file is broken and was not installed ($e)');
    } finally {
      if (staging.existsSync()) await staging.delete(recursive: true);
      if (stagingRoot.existsSync() && stagingRoot.listSync().isEmpty) await stagingRoot.delete();
    }
  }

  static bool _isZip(Uint8List b) => b.length > 4 && b[0] == 0x50 && b[1] == 0x4B && b[2] == 3 && b[3] == 4;

  /// Rejects paths that could leave the module folder, after turning `\` into `/`.
  static String? safeEntryPath(String name) {
    final n = name.replaceAll(r'\', '/');
    if (n.isEmpty || n.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(n)) return null;
    final parts = n.split('/');
    if (parts.any((p) => p == '..' || p.isEmpty && n.endsWith('/') == false)) return null;
    return n;
  }

  void _unzip(Uint8List bytes, Directory staging) {
    if (bytes.length > maxZipBytes) {
      throw InstallException(
        'This zip is too big (${bytes.length ~/ (1024 * 1024)} MB, limit ${maxZipBytes ~/ (1024 * 1024)} MB)',
      );
    }
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (e) {
      throw InstallException('Could not read this zip file: $e');
    }
    var total = 0;
    var hasManifest = false;
    for (final f in archive) {
      if (!f.isFile) continue;
      final path = safeEntryPath(f.name);
      if (path == null) throw InstallException('Unsafe path inside the zip: "${f.name}"');
      final ext = path.contains('.') ? path.substring(path.lastIndexOf('.')).toLowerCase() : '';
      if (!allowedExtensions.contains(ext)) {
        throw InstallException('File type not allowed in a module: "$path" (only ${allowedExtensions.join(' ')})');
      }
      if (f.size > maxFileBytes) {
        throw InstallException('"$path" is too big (limit ${maxFileBytes ~/ (1024 * 1024)} MB per file)');
      }
      total += f.size;
      if (total > maxTotalBytes) {
        throw InstallException('This module is too big unpacked (limit ${maxTotalBytes ~/ (1024 * 1024)} MB)');
      }
      if (path == 'module.json') hasManifest = true;
      final content = f.readBytes();
      if (content == null) throw InstallException('Could not unpack "$path"');
      _staged(staging, path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(content);
    }
    if (!hasManifest) throw InstallException('This zip has no module.json at its root');
  }

  /// A file inside [staging]. Every read and write of a module being installed goes through
  /// here, so no name taken from module data can reach outside the staging folder.
  File _staged(Directory staging, String rel) {
    final safe = safeEntryPath(rel);
    if (safe == null) throw InstallException('Unsafe path in this module: "$rel"');
    return File(_p(staging.path, safe));
  }

  static final _collectionName = RegExp(r'^[A-Za-z0-9_-]+$');

  void _writeSingleJson(Uint8List bytes, Directory staging) {
    final Object? j;
    try {
      j = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw InstallException('This file is neither a zip nor a module JSON file');
    }
    if (j is! Map || j['format'] == null || j['id'] == null) {
      throw InstallException('This file is neither a zip nor a module JSON file (no "format" and "id")');
    }
    _writeManifest(j.cast<String, dynamic>(), staging);
  }

  /// Writes `module.json` into [staging], first moving each inline collection's items to
  /// `data/<name>.json` (names checked, so they can't point outside the module).
  void _writeManifest(Map<String, dynamic> manifest, Directory staging) {
    final collections = manifest['collections'];
    if (collections is Map) {
      for (final e in collections.entries) {
        final spec = e.value;
        if (spec is Map && spec['items'] is List) {
          if (e.key is! String || !_collectionName.hasMatch(e.key as String)) {
            throw InstallException('Collection name "${e.key}" may only use letters, digits, "-" and "_"');
          }
          final file = 'data/${e.key}.json';
          _staged(staging, file)
            ..createSync(recursive: true)
            ..writeAsStringSync(jsonEncode({'items': spec['items']}));
          spec['items'] = file;
        }
      }
    }
    _staged(staging, 'module.json').writeAsStringSync(jsonEncode(manifest));
  }

  /// Downloads every `https` image ref into `images/remote/` and rewrites the refs.
  /// A failed download leaves the ref empty, which draws the text-only card style.
  Future<void> _fetchRemoteImages(Directory staging, Map<String, String> Function(Uri)? headersFor) async {
    final manifestFile = _staged(staging, 'module.json');
    if (!manifestFile.existsSync()) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(manifestFile.readAsStringSync());
    } catch (_) {
      return; // The loader reports the real error.
    }
    if (decoded is! Map) return;
    final manifest = decoded.cast<String, dynamic>();

    // Collect (holder, key) slots that hold https refs.
    final slots = <(Map, Object)>[];
    final dataFiles = <String, Map<String, dynamic>>{};
    void slot(Map holder, Object key) {
      final v = holder[key];
      if (v is String && v.startsWith('https://')) slots.add((holder, key));
    }

    slot(manifest, 'icon');
    if (manifest['symbols'] is Map) {
      for (final k in (manifest['symbols'] as Map).keys.toList()) {
        slot(manifest['symbols'] as Map, k);
      }
    }
    if (manifest['collections'] is Map) {
      for (final e in (manifest['collections'] as Map).entries) {
        final spec = e.value;
        if (spec is! Map || spec['items'] is! String) continue;
        final path = safeEntryPath(spec['items'] as String);
        if (path == null) continue;
        final f = _staged(staging, path);
        if (!f.existsSync()) continue;
        final Object? dj;
        try {
          dj = jsonDecode(f.readAsStringSync());
        } catch (_) {
          continue;
        }
        if (dj is! Map || dj['items'] is! List) continue;
        dataFiles[path] = dj.cast<String, dynamic>();
        final field = spec['imageField'] as String? ?? 'image';
        for (final it in dj['items'] as List) {
          if (it is Map) slot(it, field);
        }
      }
    }
    if (slots.isEmpty) return;

    final client = _client ?? http.Client();
    final results = <String, String>{}; // url → local ref ('' on failure)
    final urls = {for (final s in slots) s.$1[s.$2] as String};
    final queue = urls.toList();
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final url = queue.removeAt(0);
        results[url] = await _download(client, Uri.parse(url), staging, headersFor);
      }
    }

    try {
      await Future.wait([for (var i = 0; i < _maxParallelDownloads; i++) worker()]);
    } finally {
      if (_client == null) client.close();
    }
    for (final (holder, key) in slots) {
      holder[key] = results[holder[key] as String] ?? '';
    }
    manifestFile.writeAsStringSync(jsonEncode(manifest));
    for (final e in dataFiles.entries) {
      _staged(staging, e.key).writeAsStringSync(jsonEncode(e.value));
    }
  }

  Future<String> _download(
    http.Client client,
    Uri url,
    Directory staging,
    Map<String, String> Function(Uri)? headersFor,
  ) async {
    try {
      final res = await client.get(url, headers: headersFor?.call(url) ?? const {}).timeout(imageTimeout);
      if (res.statusCode != 200 || res.bodyBytes.isEmpty || res.bodyBytes.length > maxFileBytes) return '';
      final ext = _imageExtension(url, res.bodyBytes);
      if (ext == null) return '';
      final name = '${sha1.convert(utf8.encode(url.toString()))}$ext';
      final rel = 'images/remote/$name';
      _staged(staging, rel)
        ..createSync(recursive: true)
        ..writeAsBytesSync(res.bodyBytes);
      return rel;
    } catch (_) {
      return '';
    }
  }

  /// Extension from the bytes' magic numbers, else from the URL; null if neither is an image.
  static String? _imageExtension(Uri url, Uint8List b) {
    if (b.length > 12) {
      if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return '.png';
      if (b[0] == 0xFF && b[1] == 0xD8) return '.jpg';
      if (b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 && b[8] == 0x57 && b[9] == 0x45) return '.webp';
    }
    final path = url.path.toLowerCase();
    for (final e in ['.webp', '.png', '.jpg', '.jpeg']) {
      if (path.endsWith(e)) return e;
    }
    return null;
  }
}
