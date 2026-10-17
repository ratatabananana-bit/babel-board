import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'module_store.dart';

/// Where module bytes come from besides the repository: a file on the phone, a pasted
/// link, or the share sheet. Overridable so tests need no plugins.
class InstallSources {
  InstallSources({http.Client? client}) : _client = client;
  final http.Client? _client;

  /// Lets the user pick a .zip or .json; null when they cancel.
  Future<Uint8List?> pickModuleFile() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['zip', 'json']);
    final f = files.firstOrNull;
    if (f == null) return null;
    return f.xFile.readAsBytes();
  }

  /// Plain download of a pasted link. [headersFor] adds the repository token for its host only.
  Future<Uint8List> downloadLink(Uri url, {Map<String, String> Function(Uri)? headersFor}) async {
    final http.Response res;
    try {
      res = await (_client ?? http.Client()).get(url, headers: headersFor?.call(url) ?? const {});
    } catch (e) {
      throw InstallException('Could not download that link: $e');
    }
    if (res.statusCode != 200) throw InstallException('That link answered HTTP ${res.statusCode}');
    return res.bodyBytes;
  }

  /// Files shared or opened with the app (Android). Empty elsewhere.
  Stream<Uint8List> sharedFiles() async* {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      for (final f in initial) {
        final b = await _read(f);
        if (b != null) yield b;
      }
      await ReceiveSharingIntent.instance.reset();
      await for (final list in ReceiveSharingIntent.instance.getMediaStream()) {
        for (final f in list) {
          final b = await _read(f);
          if (b != null) yield b;
        }
      }
    } on MissingPluginException {
      // Not available (tests, desktop).
    } on PlatformException {
      // Nothing shared.
    }
  }

  Future<Uint8List?> _read(SharedMediaFile f) async {
    try {
      final file = File(f.path);
      if (!file.existsSync()) return null;
      if (file.lengthSync() > ModuleStore.maxZipBytes) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }
}
