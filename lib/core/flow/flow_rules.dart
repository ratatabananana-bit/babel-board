import 'dart:convert';

import 'package:flutter/services.dart';

class ChecklistItem {
  const ChecklistItem({required this.id, required this.text, this.sub, this.action, this.actionLabel});

  final String id;
  final String text;

  /// Optional second line with detail.
  final String? sub;

  /// Optional in-app shortcut, e.g. `clearTable`.
  final String? action;

  /// Text on the action pill, e.g. "Clear".
  final String? actionLabel;

  factory ChecklistItem.fromJson(Map<String, dynamic> j) => ChecklistItem(
    id: j['id'] as String,
    text: j['text'] as String,
    sub: j['sub'] as String?,
    action: j['action'] as String?,
    actionLabel: j['actionLabel'] as String?,
  );
}

class PhaseInfo {
  const PhaseInfo({
    required this.id,
    required this.title,
    required this.summary,
    required this.listTitle,
    required this.steps,
    required this.checklist,
    this.nextLabel,
    this.tag,
    this.emptyText,
    this.short,
  });

  final String id;
  final String title;
  final String summary;

  /// Heading of this phase's checklist card.
  final String listTitle;

  /// "How this phase works" lines.
  final List<String> steps;
  final List<ChecklistItem> checklist;

  /// Overrides the default `Next: <phase>` label.
  final String? nextLabel;

  /// Small note under the step in the progress bar, e.g. "Mild" or "Wild".
  final String? tag;

  /// Shown on the checklist when the step has no items.
  final String? emptyText;

  /// Shorter label for the progress bar when [title] is long.
  final String? short;

  factory PhaseInfo.fromJson(Map<String, dynamic> j) => PhaseInfo(
    id: j['id'] as String,
    title: j['title'] as String,
    summary: j['summary'] as String,
    listTitle: j['listTitle'] as String? ?? 'Checklist',
    steps: (j['steps'] as List).cast<String>(),
    checklist: (j['checklist'] as List).map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>)).toList(),
    nextLabel: j['nextLabel'] as String?,
    tag: j['tag'] as String?,
    emptyText: j['emptyText'] as String?,
    short: j['short'] as String?,
  );
}

class Rules {
  const Rules({
    required this.title,
    required this.setup,
    required this.phases,
    required this.reminders,
    this.cyclic = true,
  });

  /// Header of the flow tab, e.g. "Round".
  final String title;

  /// True when the steps repeat (rounds); false when they run once (e.g. races 1-4, then final).
  final bool cyclic;

  final PhaseInfo setup;

  /// The steps shown in the progress bar.
  final List<PhaseInfo> phases;

  /// Always-true rules worth keeping in view.
  final List<String> reminders;

  factory Rules.fromJson(Map<String, dynamic> j) => Rules(
    title: j['title'] as String? ?? 'Round',
    cyclic: j['cyclic'] as bool? ?? true,
    setup: PhaseInfo.fromJson(j['setup'] as Map<String, dynamic>),
    phases: (j['phases'] as List).map((e) => PhaseInfo.fromJson(e as Map<String, dynamic>)).toList(),
    reminders: (j['reminders'] as List).cast<String>(),
  );
}

Future<Rules> loadRules(AssetBundle bundle, String path) async =>
    Rules.fromJson(jsonDecode(await bundle.loadString(path)) as Map<String, dynamic>);
