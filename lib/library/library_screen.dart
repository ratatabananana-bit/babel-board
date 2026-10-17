import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_version.dart';
import '../core/app_state.dart';
import '../core/game_switcher.dart';
import '../core/theme.dart';
import '../core/widgets/confirm.dart';
import '../module_format/validator.dart' show compareVersions;
import 'library_controller.dart';
import 'module_store.dart';
import 'repository.dart';

/// The installed games, like a console's home screen, plus what the repository offers.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final lib = context.watch<LibraryController>();
    final app = context.watch<AppState>();
    final hasAnything = lib.shown.isNotEmpty || lib.repo != null;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 60,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 4, 0),
                child: Row(
                  children: [
                    const Expanded(child: Text('Library', style: T.title)),
                    _Menu(lib: lib),
                  ],
                ),
              ),
            ),
            if (lib.busy != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  children: [
                    const LinearProgressIndicator(minHeight: 3),
                    const SizedBox(height: 6),
                    Text(lib.busy!, style: T.caption.copyWith(color: p.text2)),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (!hasAnything) _EmptyState(lib: lib) else ..._installed(context, lib, app),
                  if (lib.repo != null) ..._repository(context, lib),
                  const SizedBox(height: 24),
                  Text('Table Helper $kAppVersion', style: T.caption.copyWith(color: p.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _installed(BuildContext context, LibraryController lib, AppState app) {
    final p = context.pal;
    if (lib.shown.isEmpty) {
      return [Text('No games installed yet.', style: T.body.copyWith(color: p.text2)), const SizedBox(height: 16)];
    }
    return [
      Text('INSTALLED', style: T.label.copyWith(color: p.muted)),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, box) {
          final w = (box.maxWidth - 2 * 12) / 3;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final i in lib.shown)
                SizedBox(
                  width: w,
                  child: _GameTile(installed: i, game: app.games.where((g) => g.id == i.id).firstOrNull),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _repository(BuildContext context, LibraryController lib) {
    final p = context.pal;
    final name = lib.listing?.name ?? lib.repo!.indexUrl.host;
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              'From $name',
              style: T.label.copyWith(color: p.muted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (lib.loadingRepo)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          else
            IconButton(
              tooltip: 'Refresh',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.refresh_rounded, color: p.text2),
              onPressed: lib.refreshRepo,
            ),
        ],
      ),
      const SizedBox(height: 6),
      if (lib.repoError != null) ...[
        Text(lib.repoError!, style: T.body.copyWith(color: p.danger)),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => showRepoDialog(context, lib), child: const Text('Edit repository')),
      ] else if (lib.listing != null && lib.listing!.entries.isEmpty)
        Text('This repository lists no games yet.', style: T.body.copyWith(color: p.text2))
      else if (lib.listing != null)
        for (final e in lib.listing!.entries) _RepoRow(entry: e, lib: lib),
    ];
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.lib});
  final LibraryController lib;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('No games yet', style: T.display),
        const SizedBox(height: 8),
        Text(
          lib.canInstall
              ? 'Add your games repository, or install a module file from this phone.'
              : 'This preview has no games bundled.',
          style: T.body.copyWith(color: p.text2),
        ),
        const SizedBox(height: 24),
        if (lib.canInstall) ...[
          FilledButton(onPressed: () => showRepoDialog(context, lib), child: const Text('Add repository')),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () => installFromFile(context, lib), child: const Text('Install from file')),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.lib});
  final LibraryController lib;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: Icon(Icons.more_vert_rounded, color: p.text2),
      onSelected: (v) {
        switch (v) {
          case 'repo':
            showRepoDialog(context, lib);
          case 'file':
            installFromFile(context, lib);
          case 'link':
            _showLinkDialog(context, lib);
          case 'ai':
            copyAiInstructions(context);
        }
      },
      itemBuilder: (_) => [
        if (lib.canInstall) ...[
          PopupMenuItem(value: 'repo', child: Text(lib.repo == null ? 'Add repository' : 'Edit repository')),
          const PopupMenuItem(value: 'file', child: Text('Install from file')),
          const PopupMenuItem(value: 'link', child: Text('Install from link')),
        ],
        const PopupMenuItem(value: 'ai', child: Text('Copy instructions for AI')),
      ],
    );
  }
}

/// Copies the compact module spec, to paste into Claude or ChatGPT on the phone.
Future<void> copyAiInstructions(BuildContext context) async {
  final text = await rootBundle.loadString('modules/AI_INSTRUCTIONS.md');
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) _snack(context, 'Copied — paste it into Claude or ChatGPT');
}

Future<void> installFromFile(BuildContext context, LibraryController lib) async {
  try {
    await lib.installFromFile();
  } on InstallException catch (e) {
    if (context.mounted) _snack(context, e.message);
  } catch (e) {
    if (context.mounted) _snack(context, 'Could not install: $e');
  }
}

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));
}

Future<void> _showLinkDialog(BuildContext context, LibraryController lib) async {
  final ctl = TextEditingController();
  final url = await showDialog<Uri>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Install from link'),
      content: TextField(
        controller: ctl,
        key: const Key('linkUrl'),
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(hintText: 'https://… .zip or .json'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final u = Uri.tryParse(ctl.text.trim());
            if (u != null && u.hasScheme) Navigator.pop(d, u);
          },
          child: const Text('Install'),
        ),
      ],
    ),
  );
  if (url == null || !context.mounted) return;
  try {
    await lib.installLink(url);
  } on InstallException catch (e) {
    if (context.mounted) _snack(context, e.message);
  } catch (e) {
    if (context.mounted) _snack(context, 'Could not install: $e');
  }
}

/// Index URL + token. Save tests the connection first and shows the error in words.
Future<void> showRepoDialog(BuildContext context, LibraryController lib) {
  final url = TextEditingController(text: lib.repo?.indexUrl.toString() ?? '');
  final token = TextEditingController(text: lib.repo?.token ?? '');
  String? error;
  var saving = false;
  return showDialog<void>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, setState) => AlertDialog(
        title: const Text('Repository'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('repoUrl'),
              controller: url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'index.json link',
                hintText: 'https://raw.githubusercontent.com/…/index.json',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('repoToken'),
              controller: token,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'GitHub token (private repo)', hintText: 'optional'),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: T.caption.copyWith(color: context.pal.danger)),
            ],
          ],
        ),
        actions: [
          if (lib.repo != null)
            TextButton(
              onPressed: () async {
                await lib.clearRepo();
                if (d.mounted) Navigator.pop(d);
              },
              child: Text('Remove', style: TextStyle(color: context.pal.danger)),
            ),
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    final u = Uri.tryParse(url.text.trim());
                    if (u == null || !u.hasScheme) {
                      setState(() => error = 'Enter the full https link to index.json');
                      return;
                    }
                    setState(() {
                      saving = true;
                      error = null;
                    });
                    try {
                      await lib.saveRepo(
                        RepoConfig(indexUrl: u, token: token.text.trim().isEmpty ? null : token.text.trim()),
                      );
                      if (d.mounted) Navigator.pop(d);
                    } on RepoException catch (e) {
                      setState(() {
                        saving = false;
                        error = e.message;
                      });
                    }
                  },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.installed, required this.game});
  final InstalledModule installed;
  final OpenGame? game;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final lib = context.read<LibraryController>();
    final app = context.read<AppState>();
    final broken = installed.broken || game == null;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: broken ? () => _showError(context) : () => app.open(installed.id),
        onLongPress: () => _showActions(context, lib),
        child: Opacity(
          opacity: broken ? 0.55 : 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
            child: Column(
              children: [
                if (game != null)
                  GameIcon(game!, size: 64)
                else
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: p.surface2, shape: BoxShape.circle),
                    child: Icon(Icons.error_outline_rounded, color: p.danger),
                  ),
                const SizedBox(height: 10),
                Text(
                  installed.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.2),
                ),
                const SizedBox(height: 2),
                Text(
                  broken ? "Can't load" : installed.version,
                  style: T.caption.copyWith(color: broken ? p.danger : p.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showError(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Can't load ${installed.name}", style: T.title),
              const SizedBox(height: 12),
              Text(installed.error ?? 'Unknown error', style: T.body.copyWith(color: context.pal.text2)),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context, LibraryController lib) {
    final p = context.pal;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: p.danger),
              title: Text(
                'Uninstall',
                style: TextStyle(color: p.danger, fontWeight: FontWeight.w700),
              ),
              onTap: () async {
                Navigator.pop(sheet);
                final ok = await confirm(
                  context,
                  'Uninstall ${installed.name}?',
                  'Removes the game and everything you tracked in it.',
                  'Uninstall',
                );
                if (ok) await lib.uninstall(installed.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _RepoRow extends StatelessWidget {
  const _RepoRow({required this.entry, required this.lib});
  final RepoEntry entry;
  final LibraryController lib;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final have = lib.installedById(entry.id);
    final Widget action;
    if (entry.needsAppUpdate) {
      action = const FilledButton(onPressed: null, child: Text('Needs app update'));
    } else if (have != null && compareVersions(have.version, entry.version) >= 0) {
      action = Text('Installed', style: T.caption.copyWith(color: p.muted));
    } else {
      action = FilledButton(
        onPressed: lib.busy != null ? null : () => _install(context),
        child: Text(have == null ? 'Install' : 'Update'),
      );
    }
    final size = entry.size > 0 ? ' · ${(entry.size / 1024).round()} KB' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _EntryIcon(entry: entry, lib: lib),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text('${entry.version}$size', style: T.caption.copyWith(color: p.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          action,
        ],
      ),
    );
  }

  Future<void> _install(BuildContext context) async {
    try {
      await lib.installEntry(entry);
    } on InstallException catch (e) {
      if (context.mounted) _snack(context, e.message);
    } on RepoException catch (e) {
      if (context.mounted) _snack(context, e.message);
    } catch (e) {
      if (context.mounted) _snack(context, 'Could not install: $e');
    }
  }
}

class _EntryIcon extends StatelessWidget {
  const _EntryIcon({required this.entry, required this.lib});
  final RepoEntry entry;
  final LibraryController lib;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final fallback = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: p.surface2, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        entry.name.isEmpty ? '?' : entry.name[0].toUpperCase(),
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: p.text),
      ),
    );
    final icon = entry.iconUrl;
    if (icon == null) return fallback;
    return ClipOval(
      child: Image.network(
        icon.toString(),
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        headers: lib.headersFor(icon),
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
