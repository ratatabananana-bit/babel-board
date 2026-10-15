import 'package:flutter/material.dart';

import '../theme.dart';

/// Red confirm dialog for destructive actions. Returns true if confirmed.
Future<bool> confirm(BuildContext context, String title, String body, String action) async {
  final p = context.pal;
  return await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: p.danger, foregroundColor: p.onAccent),
              onPressed: () => Navigator.pop(d, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
}
