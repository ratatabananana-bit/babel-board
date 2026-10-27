import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../modules/loaded_module.dart';
import 'item_picture.dart';

/// `*text*` (italics, no line break inside) or `:name:` (a symbol).
final _marker = RegExp(r'\*([^*\n]+)\*|:([A-Za-z0-9_-]+):');

/// A run of parts drawn in italics: `*+1 Clank!*`. Since 3.3.3.
@immutable
class Emph {
  const Emph(this.parts);
  final List<Object> parts;

  @override
  bool operator ==(Object other) => other is Emph && listEquals(other.parts, parts);
  @override
  int get hashCode => Object.hashAll(parts);
  @override
  String toString() => 'Emph($parts)';
}

/// Splits [text] at `:name:` markers whose name is in [known] and at `*…*` runs: plain text
/// stays a [String], each marker becomes a [Symbol] of its name, each starred run an [Emph]
/// holding its own parts. Unknown names, and lone or empty stars, are left as written.
List<Object> parseSymbols(String text, Set<String> known) {
  final out = <Object>[];
  var last = 0;
  for (final m in _marker.allMatches(text)) {
    final Object part;
    if (m.group(2) != null) {
      if (!known.contains(m.group(2))) continue;
      part = Symbol(m.group(2)!);
    } else {
      part = Emph(parseSymbols(m.group(1)!, known));
    }
    if (m.start > last) out.add(text.substring(last, m.start));
    out.add(part);
    last = m.end;
  }
  if (last < text.length) out.add(text.substring(last));
  return out;
}

String _nameOf(Symbol s) {
  final t = s.toString(); // Symbol("name")
  return t.substring(8, t.length - 2);
}

/// Module text with inline symbol pictures: `Earn 2 :stone_red:` shows the red stone.
/// Like the fan wiki, each picture is as tall as one line of the text around it and sits on
/// the line's middle, with the text's own spaces around it, so lines don't spread apart.
/// `*…*` draws its run in italics (a printed "+1 Clank!").
class SymbolText extends StatelessWidget {
  const SymbolText(this.text, {super.key, this.style, this.maxLines, this.overflow, this.textAlign});

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final known = context.read<LoadedModule>().manifest.symbols.keys.toSet();
    final parts = parseSymbols(text, known);
    if (parts.every((p) => p is String)) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign);
    }
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final size = (effective.fontSize ?? 14) * (effective.height ?? 1.2);
    return Text.rich(
      TextSpan(children: _spans(parts, size)),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }

  List<InlineSpan> _spans(List<Object> parts, double size) => [
    for (final p in parts)
      if (p is Symbol)
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          // A hairline either side: icons in a row (like a printed cost) don't touch.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: SymbolImage(_nameOf(p), size: size, label: _nameOf(p).replaceAll('_', ' ')),
          ),
        )
      else if (p is Emph)
        p.parts.every((q) => q is String)
            ? TextSpan(
                text: p.parts.join(),
                style: const TextStyle(fontStyle: FontStyle.italic),
              )
            : TextSpan(
                style: const TextStyle(fontStyle: FontStyle.italic),
                children: _spans(p.parts, size),
              )
      else
        TextSpan(text: p as String),
  ];
}
