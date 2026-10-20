import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'module_store.dart';

/// Where a module comes from besides the repository: a file on the phone, a pasted link,
/// or the share sheet. Each gives a [ModuleSource]; a file stays on disk and is streamed by
/// the store, so a big zip is never read whole. Overridable so tests need no plugins.
class InstallSources {
  InstallSources({http.Client? client}) : _client = client;
  final http.Client? _client;

  /// Lets the user pick a .zip or .json; null when they cancel.
  Future<ModuleSource?> pickModuleFile() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['zip', 'json']);
    final f = files.firstOrNull;
    if (f == null) return null;
    final path = f.path;
    if (path != null && path.isNotEmpty) return FileSource(File(path));
    return BytesSource(await f.xFile.readAsBytes());
  }

  /// Download of a pasted link, spooled to a temp file. [headersFor] adds the repository
  /// token for its host only.
  Future<ModuleSource> downloadLink(Uri url, {Map<String, String> Function(Uri)? headersFor}) async {
    final http.StreamedResponse res;
    try {
      final req = http.Request('GET', url)..headers.addAll(headersFor?.call(url) ?? const {});
      res = await (_client ?? http.Client()).send(req);
    } catch (e) {
      throw InstallException('Could not download that link: $e');
    }
    if (res.statusCode != 200) throw InstallException('That link answered HTTP ${res.statusCode}');
    return spoolToTempFile(res.stream);
  }

  /// Files shared or opened with the app (Android). Empty elsewhere.
  Stream<ModuleSource> sharedFiles() async* {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      for (final f in initial) {
        final s = _source(f);
        if (s != null) yield s;
      }
      await ReceiveSharingIntent.instance.reset();
      await for (final list in ReceiveSharingIntent.instance.getMediaStream()) {
        for (final f in list) {
          final s = _source(f);
          if (s != null) yield s;
        }
      }
    } on MissingPluginException {
      // Not available (tests, desktop).
    } on PlatformException {
      // Nothing shared.
    }
  }

  ModuleSource? _source(SharedMediaFile f) {
    try {
      final file = File(f.path);
      return file.existsSync() ? FileSource(file) : null;
    } catch (_) {
      return null;
    }
  }
}
