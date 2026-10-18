import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../modules/loaded_module.dart';
import 'item_view.dart';

final _marker = RegExp(r':([A-Za-z0-9_-]+):');

/// Splits [text] at `:name:` markers whose name is in [known]: plain text stays a [String],
/// each marker becomes a [Symbol] of its name. Unknown names are left as written.
List<Object> parseSymbols(String text, Set<String> known) {
  final out = <Object>[];
  var last = 0;
  for (final m in _marker.allMatches(text)) {
    final name = m.group(1)!;
    if (!known.contains(name)) continue;
    if (m.start > last) out.add(text.substring(last, m.start));
    out.add(Symbol(name));
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
    final parts = known.isEmpty ? [text] : parseSymbols(text, known);
    if (parts.every((p) => p is String)) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign);
    }
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final size = (effective.fontSize ?? 14) * (effective.height ?? 1.2);
    return Text.rich(
      TextSpan(
        children: [
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
            else
              TextSpan(text: p as String),
        ],
      ),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
