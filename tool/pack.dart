// Zips every module folder and writes a repository index for the app.
//   dart run tool/pack.dart <modules dir> <out dir> [--name "Repo name"] [--unpacked]
// Validates every module first; on any error nothing is written and the exit code is 1.
// Writes <out>/<id>-<version>.zip, <out>/icons/<id>.<ext> and <out>/index.json, with
// links relative to the index so the app can add the repository token itself.
// --unpacked also writes <out>/<id>/ (the web preview reads modules unzipped).
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import 'validate.dart';

const _allowed = {'.json', '.webp', '.png', '.jpg', '.jpeg'};

String _ext(String path) {
  final dot = path.lastIndexOf('.');
  return dot < 0 ? '' : path.substring(dot).toLowerCase();
}

/// Files of a module folder that belong in its zip, keyed by `/`-separated relative path.
Map<String, File> _moduleFiles(Directory dir) {
  final out = <String, File>{};
  for (final f in dir.listSync(recursive: true).whereType<File>()) {
    final rel = f.path.substring(dir.path.length + 1).replaceAll(r'\', '/');
    if (_allowed.contains(_ext(rel)) && !rel.split('/').any((p) => p.startsWith('.'))) out[rel] = f;
  }
  return out;
}

ToolResult packModules(
  Directory modulesDir,
  Directory out, {
  String name = 'Babel Board modules',
  bool unpacked = false,
}) {
  final lines = <String>[];
  if (!modulesDir.existsSync()) return ToolResult(1, ['ERROR ${modulesDir.path}: folder not found']);
  final folders =
      modulesDir.listSync().whereType<Directory>().where((d) => File('${d.path}/module.json').existsSync()).toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  if (folders.isEmpty) return ToolResult(1, ['ERROR ${modulesDir.path}: no module folders (with module.json) found']);

  final read = <ModuleFolder>[];
  final ids = <String>{};
  var failed = false;
  // Games first, so each expansion is checked merged into the game it expands, wherever
  // that game's folder is among those packed.
  final firstRead = {for (final d in folders) d: readModuleFolder(d)};
  final gameDirs = {
    for (final e in firstRead.entries)
      if (e.value.ok && !e.value.isExpansion) '${e.value.manifest!['id']}': e.key,
  };
  for (final d in folders) {
    final label = d.path.split(Platform.pathSeparator).last.split('/').last;
    final expands = firstRead[d]!.isExpansion ? firstRead[d]!.manifest!['expands'] : null;
    final f = expands is Map ? readModuleFolder(d, base: gameDirs[expands['id']]) : firstRead[d]!;
    for (final i in f.issues) {
      lines.add('$label: $i');
    }
    if (!f.ok) {
      failed = true;
      continue;
    }
    final id = f.manifest!['id'] as String;
    if (!ids.add(id)) {
      lines.add('$label: ERROR id: Another module folder already uses id "$id"');
      failed = true;
    }
    read.add(f);
  }
  if (failed) return ToolResult(1, lines);

  out.createSync(recursive: true);
  final entries = <Map<String, Object?>>[];
  for (final f in read) {
    final m = f.manifest!;
    final id = m['id'] as String;
    final version = m['version'] as String;
    final files = _moduleFiles(f.dir);

    final archive = Archive();
    for (final e in files.entries) {
      final bytes = e.value.readAsBytesSync();
      archive.addFile(ArchiveFile(e.key, bytes.length, bytes));
    }
    final zipName = '$id-$version.zip';
    final zipFile = File('${out.path}/$zipName')..writeAsBytesSync(ZipEncoder().encode(archive));

    String? icon;
    final iconRef = m['icon'];
    if (iconRef is String && iconRef.startsWith('https://')) {
      icon = iconRef;
    } else if (iconRef is String && files.containsKey(iconRef)) {
      icon = 'icons/$id${_ext(iconRef)}';
      File('${out.path}/$icon')
        ..createSync(recursive: true)
        ..writeAsBytesSync(files[iconRef]!.readAsBytesSync());
    }

    if (unpacked) {
      final dest = Directory('${out.path}/$id');
      if (dest.existsSync()) dest.deleteSync(recursive: true);
      for (final e in files.entries) {
        File('${dest.path}/${e.key}')
          ..createSync(recursive: true)
          ..writeAsBytesSync(e.value.readAsBytesSync());
      }
    }

    entries.add({
      'id': id,
      'name': m['name'],
      'version': version,
      'minAppVersion': m['minAppVersion'],
      'zip': zipName,
      'icon': ?icon,
      'size': zipFile.lengthSync(),
      if (m['expands'] case {'id': final String base}) 'expands': base,
    });
    lines.add('Packed $id $version → $zipName (${zipFile.lengthSync()} bytes)');
  }
  File(
    '${out.path}/index.json',
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert({'name': name, 'modules': entries})}\n');
  lines.add('Wrote ${out.path}/index.json with ${entries.length} module${entries.length == 1 ? '' : 's'}');
  return ToolResult(0, lines);
}

void main(List<String> args) {
  final positional = <String>[];
  var name = 'Babel Board modules';
  var unpacked = false;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--name' && i + 1 < args.length) {
      name = args[++i];
    } else if (args[i] == '--unpacked') {
      unpacked = true;
    } else {
      positional.add(args[i]);
    }
  }
  if (positional.length != 2) {
    stderr.writeln('Usage: dart run tool/pack.dart <modules dir> <out dir> [--name "Repo name"] [--unpacked]');
    exit(2);
  }
  final r = packModules(Directory(positional[0]), Directory(positional[1]), name: name, unpacked: unpacked);
  r.lines.forEach(stdout.writeln);
  exit(r.exitCode);
}
