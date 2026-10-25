import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_version.dart';
import '../core/app_state.dart';
import '../core/game_switcher.dart';
import '../core/theme.dart';
import '../core/widgets/confirm.dart';
import '../module_format/validator.dart' show compareVersions;
import '../modules/module_files.dart';
import 'library_controller.dart';
import 'module_store.dart';
import 'repository.dart';
import 'settings_screen.dart';

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
                    IconButton(
                      tooltip: 'Settings',
                      icon: Icon(Icons.settings_rounded, color: p.text2),
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
                    ),
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
                  Text('Babel Board $kAppVersion', style: T.caption.copyWith(color: p.muted)),
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
    final games = [for (final i in lib.shown) if (!i.isExpansion) i];
    final expansions = [for (final i in lib.shown) if (i.isExpansion) i];
    return [
      if (games.isEmpty)
        Text('No games installed yet.', style: T.body.copyWith(color: p.text2))
      else ...[
        Text('INSTALLED', style: T.label.copyWith(color: p.muted)),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, box) {
            final w = (box.maxWidth - 2 * 12) / 3;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final i in games)
                  SizedBox(
                    width: w,
                    child: _GameTile(installed: i, game: app.games.where((g) => g.id == i.id).firstOrNull),
                  ),
              ],
            );
          },
        ),
      ],
      const SizedBox(height: 24),
      if (expansions.isNotEmpty) ...[
        Text('EXPANSIONS', style: T.label.copyWith(color: p.muted)),
        const SizedBox(height: 4),
        for (final e in expansions) _ExpansionRow(installed: e),
        const SizedBox(height: 24),
      ],
    ];
  }

  List<Widget> _repository(BuildContext context, LibraryController lib) {
    final p = context.pal;
    final name = lib.listing?.name ?? lib.repo!.displayName;
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
        OutlinedButton(onPressed: () => showRepoSheet(context, lib), child: const Text('Edit repository')),
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
          FilledButton(onPressed: () => showRepoSheet(context, lib), child: const Text('Add repository')),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () => installFromFile(context, lib), child: const Text('Install from file')),
        ],
        const SizedBox(height: 24),
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

Future<void> showLinkDialog(BuildContext context, LibraryController lib) async {
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
/// Paste a repository link, tap Connect, pick the games: all in one sheet. A GitHub
/// repository page is enough; the app finds `index.json` on `main` or `master` itself. A
/// token is only for private repositories and stays folded away until needed.
Future<void> showRepoSheet(BuildContext context, LibraryController lib) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _RepoSheet(lib: lib),
  );
}

class _RepoSheet extends StatefulWidget {
  const _RepoSheet({required this.lib});
  final LibraryController lib;

  @override
  State<_RepoSheet> createState() => _RepoSheetState();
}

class _RepoSheetState extends State<_RepoSheet> {
  late final _url = TextEditingController(text: _initialUrl());
  String? _error;
  bool _busy = false;

  /// Show the repository page link, not the raw index link, when it is a GitHub one.
  String _initialUrl() {
    final u = widget.lib.repo?.indexUrl;
    if (u == null) return '';
    if (u.host == 'raw.githubusercontent.com' && u.pathSegments.length >= 2) {
      return 'https://github.com/${u.pathSegments[0]}/${u.pathSegments[1]}';
    }
    return u.toString();
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.lib.connectRepo(_url.text);
    } on RepoException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final lib = context.watch<LibraryController>();
    final listing = lib.listing;
    final connected = lib.repo != null && listing != null && _error == null;
    return Padding(
      key: const Key('repoSheet'),
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        children: [
          const Text('Games from a repository', style: T.title),
          const SizedBox(height: 6),
          Text(
            'Paste the link to a GitHub repository of Babel Board modules. The app lists its games; tap one to install it.',
            style: T.body.copyWith(color: p.text2, fontSize: 15),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('repoUrl'),
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            onSubmitted: (_) => _connect(),
            decoration: const InputDecoration(
              labelText: 'Repository link',
              hintText: 'https://github.com/you/your-games',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: T.caption.copyWith(color: p.danger, fontSize: 13.5)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (lib.repo != null)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await lib.clearRepo();
                          if (mounted) setState(() => _error = null);
                        },
                  child: Text('Remove', style: TextStyle(color: p.danger)),
                ),
              const Spacer(),
              FilledButton(
                key: const Key('connectRepo'),
                onPressed: _busy ? null : _connect,
                child: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(connected ? 'Reconnect' : 'Connect'),
              ),
            ],
          ),
          if (connected) ...[
            const SizedBox(height: 16),
            Text(
              listing.entries.isEmpty
                  ? 'This repository lists no games yet.'
                  : '${listing.name} · ${listing.entries.length} game${listing.entries.length == 1 ? '' : 's'}',
              style: T.label.copyWith(color: p.muted),
            ),
            const SizedBox(height: 4),
            for (final e in listing.entries) _RepoRow(entry: e, lib: lib),
          ],
        ],
      ),
    );
  }
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
                  broken ? "Can't load" : _caption(),
                  textAlign: TextAlign.center,
                  style: T.caption.copyWith(color: broken ? p.danger : p.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The version, and how many expansions are merged into the game.
  String _caption() {
    final n = game?.module.expansions.length ?? 0;
    return n == 0 ? installed.version : '${installed.version} · +$n expansion${n == 1 ? '' : 's'}';
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

  void _showActions(BuildContext context, LibraryController lib) => _showUninstallSheet(context, lib, installed);
}

/// Asks, then uninstalls; the sentence says what goes with it.
Future<void> _confirmUninstall(
  BuildContext context,
  LibraryController lib, {
  required String id,
  required String name,
  required bool expansion,
}) async {
  final ok = await confirm(
    context,
    'Uninstall $name?',
    expansion
        ? 'Removes the expansion. Its cards you tracked are forgotten.'
        : 'Removes the game and everything you tracked in it.',
    'Uninstall',
  );
  if (ok) await lib.uninstall(id);
}

/// The long-press sheet of an installed game or expansion.
void _showUninstallSheet(BuildContext context, LibraryController lib, InstalledModule m) {
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
            onTap: () {
              Navigator.pop(sheet);
              _confirmUninstall(context, lib, id: m.id, name: m.name, expansion: m.isExpansion);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// An installed expansion: its icon, what it is for or what it waits for, and its switch.
class _ExpansionRow extends StatelessWidget {
  const _ExpansionRow({required this.installed});
  final InstalledModule installed;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final lib = context.watch<LibraryController>();
    final status = lib.expansions[installed.id];
    final state = installed.broken ? ExpansionState.broken : status?.state ?? ExpansionState.needsBase;
    final base = lib.nameOf(installed.expands?.id ?? '');
    final (caption, color) = switch (state) {
      ExpansionState.on || ExpansionState.off => ('For $base · ${installed.version}', p.muted),
      ExpansionState.needsBase => ('Needs $base', p.muted),
      ExpansionState.broken => (status?.message ?? installed.error ?? "Can't load", p.danger),
    };
    final dir = installed.dir;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onLongPress: () => _showUninstallSheet(context, lib, installed),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _ModuleAvatar(
              name: installed.name,
              image: dir == null ? null : DirectoryModuleFiles(dir).image(installed.icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(installed.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(caption, style: T.caption.copyWith(color: color)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Its own node, named, so a screen reader says which expansion it turns on or off.
            Semantics(
              container: true,
              label: installed.name,
              child: Switch(
                value: state == ExpansionState.on,
                onChanged: state == ExpansionState.on || state == ExpansionState.off
                    ? (on) => lib.setExpansionEnabled(installed.id, on)
                    : null,
              ),
            ),
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
    final busy = lib.busy != null;
    // An expansion installs only next to its game.
    final base = entry.expands;
    final waitsFor = base != null && lib.installedById(base) == null ? base : null;
    final canInstall = !busy && waitsFor == null;
    // One button per row: Install, then Update when the repository has a newer version,
    // else Uninstall.
    final Widget action;
    if (entry.needsAppUpdate) {
      action = const FilledButton(onPressed: null, child: Text('Needs app update'));
    } else if (have == null) {
      action = FilledButton(onPressed: canInstall ? () => _install(context) : null, child: const Text('Install'));
    } else if (compareVersions(have.version, entry.version) < 0) {
      action = FilledButton(onPressed: canInstall ? () => _install(context) : null, child: const Text('Update'));
    } else {
      action = OutlinedButton(
        onPressed: busy ? null : () => _uninstall(context),
        style: OutlinedButton.styleFrom(foregroundColor: p.danger, side: BorderSide(color: p.danger.withValues(alpha: 0.6))),
        child: const Text('Uninstall'),
      );
    }
    final kind = entry.expands == null ? '' : 'Expansion · ';
    final installed = have == null ? '' : ' · installed ${have.version}';
    final size = entry.size > 0 ? ' · ${(entry.size / 1024).round()} KB' : '';
    final first = waitsFor == null ? '' : ' · install ${lib.nameOf(waitsFor)} first';
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
                Text('$kind${entry.version}$size$installed$first', style: T.caption.copyWith(color: p.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          action,
        ],
      ),
    );
  }

  Future<void> _uninstall(BuildContext context) =>
      _confirmUninstall(context, lib, id: entry.id, name: entry.name, expansion: entry.expands != null);

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
    final icon = entry.iconUrl;
    return _ModuleAvatar(
      name: entry.name,
      image: icon == null ? null : NetworkImage(icon.toString(), headers: lib.headersFor(icon)),
    );
  }
}

/// A module's round 44 dp icon; its initial on a disc when it has none or it fails.
class _ModuleAvatar extends StatelessWidget {
  const _ModuleAvatar({required this.name, this.image});
  final String name;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final fallback = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: p.surface2, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: p.text),
      ),
    );
    final img = image;
    if (img == null) return fallback;
    return ClipOval(
      child: Image(image: img, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
    );
  }
}
