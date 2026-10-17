import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';

import '../module_format/validator.dart' show isSafeImageRef;

/// Where a module's files come from: a folder on the phone, a web server (preview), or
/// memory (tests). Paths are relative to the module root, with `/` separators.
abstract class ModuleFiles {
  Future<String> readText(String path);

  /// An image for [ref], or null when the ref is null, empty, unsafe or not found.
  /// `https://` refs give a [NetworkImage] in every implementation.
  ImageProvider? image(String? ref);
}

bool _usable(String? ref) => ref != null && ref.isNotEmpty && isSafeImageRef(ref);

ImageProvider? _remote(String ref) => ref.startsWith('https://') ? NetworkImage(ref) : null;

/// A module installed in a folder. Refs that would escape [root] are refused.
class DirectoryModuleFiles implements ModuleFiles {
  DirectoryModuleFiles(this.root);
  final Directory root;

  File? _file(String? ref) {
    if (!_usable(ref) || ref!.startsWith('https://')) return null;
    return File('${root.path}${Platform.pathSeparator}${ref.replaceAll('/', Platform.pathSeparator)}');
  }

  @override
  Future<String> readText(String path) async {
    final f = _file(path);
    if (f == null) throw FileSystemException('Refused path', path);
    return f.readAsString();
  }

  @override
  ImageProvider? image(String? ref) {
    if (!_usable(ref)) return null;
    final remote = _remote(ref!);
    if (remote != null) return remote;
    final f = _file(ref);
    return f != null && f.existsSync() ? FileImage(f) : null;
  }
}

/// A module served over HTTP (the web preview reads `modules/<id>/` next to the app).
class HttpModuleFiles implements ModuleFiles {
  HttpModuleFiles(this.base, {this.headers = const {}});
  final Uri base;
  final Map<String, String> headers;

  @override
  Future<String> readText(String path) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(base.resolve(path));
      headers.forEach(req.headers.set);
      final res = await req.close();
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: base.resolve(path));
      return res.transform(utf8.decoder).join();
    } finally {
      client.close();
    }
  }

  @override
  ImageProvider? image(String? ref) {
    if (!_usable(ref)) return null;
    return _remote(ref!) ?? NetworkImage(base.resolve(ref).toString(), headers: headers);
  }
}

/// A module held in memory, keyed by relative path.
class MemoryModuleFiles implements ModuleFiles {
  MemoryModuleFiles(this.files);
  final Map<String, Uint8List> files;

  @override
  Future<String> readText(String path) async {
    final b = files[path];
    if (b == null) throw FileSystemException('Not found', path);
    return utf8.decode(b);
  }

  @override
  ImageProvider? image(String? ref) {
    if (!_usable(ref)) return null;
    final remote = _remote(ref!);
    if (remote != null) return remote;
    final b = files[ref];
    return b == null ? null : MemoryImage(b);
  }
}
