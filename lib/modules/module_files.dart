import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

import '../module_format/expansion.dart' show splitLayerRef;
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
    // Synchronous: module files are small, and an async read's open handle would stall under
    // the test binding's fake async (and block renames on Windows).
    return f.readAsStringSync();
  }

  @override
  ImageProvider? image(String? ref) {
    if (!_usable(ref)) return null;
    final remote = _remote(ref!);
    if (remote != null) return remote;
    final f = _file(ref);
    return f != null && f.existsSync() ? ModuleFileImage(f.path) : null;
  }
}

/// An image read from a module folder. Keyed by path, so the image cache reuses decoded
/// frames across rebuilds. Reads the bytes itself and decodes them from memory: the
/// engine's file-path decoder never completes under flutter_tester, which would stall
/// screenshots and widget tests.
@immutable
class ModuleFileImage extends ImageProvider<ModuleFileImage> {
  const ModuleFileImage(this.path, {this.scale = 1.0});
  final String path;
  final double scale;

  @override
  Future<ModuleFileImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(ModuleFileImage key, ImageDecoderCallback decode) => MultiFrameImageStreamCompleter(
    codec: _load(decode),
    scale: key.scale,
    debugLabel: key.path,
    informationCollector: () => [DiagnosticsProperty<String>('Path', path)],
  );

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    // Read synchronously: module images are small local files, and an async read's
    // continuation is what stalls under the test binding's fake async.
    final bytes = File(path).readAsBytesSync();
    if (bytes.isEmpty) {
      PaintingBinding.instance.imageCache.evict(this);
      throw StateError('$path is empty and cannot be loaded as an image.');
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) => other is ModuleFileImage && other.path == path && other.scale == scale;

  @override
  int get hashCode => Object.hash(path, scale);

  @override
  String toString() => 'ModuleFileImage("$path", scale: $scale)';
}

/// A module served over HTTP (the web preview reads `modules/<id>/` next to the app).
class HttpModuleFiles implements ModuleFiles {
  HttpModuleFiles(this.base, {this.headers = const {}, http.Client? client}) : _client = client;
  final Uri base;
  final Map<String, String> headers;
  final http.Client? _client;

  @override
  Future<String> readText(String path) async {
    final url = base.resolve(path);
    final res = await (_client ?? http.Client()).get(url, headers: headers);
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: url);
    return utf8.decode(res.bodyBytes);
  }

  @override
  ImageProvider? image(String? ref) {
    if (!_usable(ref)) return null;
    return _remote(ref!) ?? NetworkImage(base.resolve(ref).toString(), headers: headers);
  }
}

/// A game merged with its expansions: text from the base, and each picture from the
/// package it came from. Expansion pictures are named `@<expansion id>/<path>` by the
/// merge; an unknown layer is a missing picture, never a fall-through to the base.
class LayeredModuleFiles implements ModuleFiles {
  LayeredModuleFiles(this.base, this.layers);

  final ModuleFiles base;
  final Map<String, ModuleFiles> layers;

  @override
  Future<String> readText(String path) => base.readText(path);

  @override
  ImageProvider? image(String? ref) {
    final layered = ref == null ? null : splitLayerRef(ref);
    if (layered == null) return base.image(ref);
    return layers[layered.layer]?.image(layered.path);
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
