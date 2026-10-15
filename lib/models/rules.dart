class ChecklistItem {
  const ChecklistItem({required this.id, required this.text, this.sub, this.action});

  final String id;
  final String text;

  /// Optional second line with detail.
  final String? sub;

  /// Optional in-app shortcut, e.g. `clearTable`.
  final String? action;

  factory ChecklistItem.fromJson(Map<String, dynamic> j) => ChecklistItem(
        id: j['id'] as String,
        text: j['text'] as String,
        sub: j['sub'] as String?,
        action: j['action'] as String?,
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

  factory PhaseInfo.fromJson(Map<String, dynamic> j) => PhaseInfo(
        id: j['id'] as String,
        title: j['title'] as String,
        summary: j['summary'] as String,
        listTitle: j['listTitle'] as String? ?? 'Checklist',
        steps: (j['steps'] as List).cast<String>(),
        checklist: (j['checklist'] as List)
            .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextLabel: j['nextLabel'] as String?,
      );
}

class Rules {
  const Rules({required this.setup, required this.phases, required this.reminders});

  final PhaseInfo setup;

  /// The repeating cycle: hunting, action, resolution, end of round.
  final List<PhaseInfo> phases;

  /// Always-true rules worth keeping in view.
  final List<String> reminders;

  factory Rules.fromJson(Map<String, dynamic> j) => Rules(
        setup: PhaseInfo.fromJson(j['setup'] as Map<String, dynamic>),
        phases: (j['phases'] as List)
            .map((e) => PhaseInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        reminders: (j['reminders'] as List).cast<String>(),
      );
}
