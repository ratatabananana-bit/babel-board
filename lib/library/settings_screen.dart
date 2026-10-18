import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_version.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import 'library_controller.dart';
import 'library_screen.dart';

/// App settings, opened from the Library: games (repository, installing, AI instructions),
/// display (theme, cards per row, the flowing family grid) and the app version.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final lib = context.watch<LibraryController>();
    final settings = context.watch<Settings>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: T.title),
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _Heading('GAMES'),
          _Card(
            children: [
              if (lib.canInstall) ...[
                _Row(
                  icon: Icons.cloud_outlined,
                  title: 'Repository',
                  subtitle: lib.repo?.indexUrl.toString() ?? 'Not set up',
                  onTap: () => showRepoDialog(context, lib),
                ),
                _Row(
                  icon: Icons.folder_open_rounded,
                  title: 'Install from file',
                  onTap: () => installFromFile(context, lib),
                ),
                _Row(icon: Icons.link_rounded, title: 'Install from link', onTap: () => showLinkDialog(context, lib)),
              ],
              _Row(
                icon: Icons.content_copy_rounded,
                title: 'Copy instructions for AI',
                subtitle: 'Paste into Claude or ChatGPT to write a module',
                onTap: () => copyAiInstructions(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _Heading('APPEARANCE'),
          _Card(
            children: [
              _Labeled(
                title: 'Theme',
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('System')),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (s) => settings.themeMode = s.single,
                ),
              ),
              _Labeled(
                title: 'Animation speed',
                subtitle: 'Card sheets, the grid and highlights. Instant skips the animations.',
                child: SegmentedButton<AnimationSpeed>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: AnimationSpeed.instant, label: Text('Instant')),
                    ButtonSegment(value: AnimationSpeed.fast, label: Text('Fast')),
                    ButtonSegment(value: AnimationSpeed.normal, label: Text('Normal')),
                  ],
                  selected: {settings.animationSpeed},
                  onSelectionChanged: (s) => settings.animationSpeed = s.single,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
          const SizedBox(height: 20),
          const _Heading('CARD GALLERY'),
          _Card(
            children: [
              _Labeled(
                title: 'Card size',
                subtitle: 'Small fits 4 per row on a phone; tablets fit more',
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    for (final n in Settings.columnChoices)
                      ButtonSegment(
                        value: n,
                        label: Text(Settings.sizeLabel(n), key: Key('settingsColumns$n')),
                      ),
                  ],
                  selected: {settings.columns},
                  onSelectionChanged: (s) => settings.columns = s.single,
                ),
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: const Text('Flowing family grid', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  'After picking a family: one grid with a marker where each cost starts, instead of a group per cost',
                  style: T.caption.copyWith(color: p.text2),
                ),
                value: settings.flowingSections,
                onChanged: (v) => settings.flowingSections = v,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _Heading('ABOUT'),
          _Card(
            children: [
              _Row(icon: Icons.info_outline_rounded, title: 'Table Helper $kAppVersion', subtitle: 'Module format 1'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(text, style: T.label.copyWith(color: context.pal.muted)),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: context.pal.surface,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, this.subtitle, this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ListTile(
      leading: Icon(icon, color: p.text2),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: T.caption.copyWith(color: p.text2),
            ),
      trailing: onTap == null ? null : Icon(Icons.chevron_right_rounded, color: p.muted),
      onTap: onTap,
    );
  }
}

/// A setting with its control underneath (segmented buttons need the full width).
class _Labeled extends StatelessWidget {
  const _Labeled({required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if (subtitle != null) Text(subtitle!, style: T.caption.copyWith(color: context.pal.text2)),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: child),
      ],
    ),
  );
}
