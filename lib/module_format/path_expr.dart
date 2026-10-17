/// The tiny path language used by templates and filters.
///
/// `a.b` walks maps; lists are flattened, so `effects.type` over a list of effects gives
/// every type. `a[k=v].b` keeps only list elements whose `k` equals `v`. Anything missing
/// resolves to nothing.
library;

final _segment = RegExp(r'^([^\[\]]+)(?:\[([^=\]]+)=([^\]]*)\])?$');

List<Object?> resolvePath(Object? data, String path) {
  var current = <Object?>[data];
  for (final seg in path.split('.')) {
    if (seg.isEmpty) return const [];
    final m = _segment.firstMatch(seg);
    if (m == null) return const [];
    final key = m.group(1)!;
    final filterKey = m.group(2);
    final filterValue = m.group(3);
    final next = <Object?>[];
    for (final c in current) {
      final v = c is Map ? c[key] : null;
      if (v == null) continue;
      if (v is List) {
        for (final e in v) {
          if (filterKey == null || (e is Map && '${e[filterKey]}' == filterValue)) next.add(e);
        }
      } else if (filterKey == null) {
        next.add(v);
      }
    }
    current = next;
    if (current.isEmpty) return const [];
  }
  return current;
}

final _hole = RegExp(r'\{([^{}]+)\}');

/// Replaces each `{path}` with the resolved values joined by `, `; missing → empty.
String fillTemplate(String template, Map<String, dynamic> item) =>
    template.replaceAllMapped(_hole, (m) => resolvePath(item, m.group(1)!.trim()).map((v) => '$v').join(', '));
