/// Typed reads from module JSON. Every spec parser reads its fields through [Fields], so a
/// wrong type is reported once, with the path of the offending value, instead of crashing
/// while a tab is drawn.
library;

/// A value in a module's JSON that has the wrong shape. [path] is where in `module.json`
/// (`tabs[0].block.filters[1].path`, `collections.cards.sheet.chips[0]`…).
class SpecFormatException extends FormatException {
  SpecFormatException(this.path, String message) : super(message);

  final String path;

  @override
  String toString() => '$path: $message';
}

/// Joins a path and a key: `''` + `format` → `format`; `zones[0]` + `id` → `zones[0].id`.
String specPath(String where, String key) => where.isEmpty ? key : '$where.$key';

/// Typed access to one JSON object's fields. `opt*` readers return null when the key is
/// absent and throw [SpecFormatException] when it holds the wrong type.
class Fields {
  Fields(this.json, this.where);

  final Map<String, dynamic> json;

  /// Path of the object itself, for error messages.
  final String where;

  String path(String key) => specPath(where, key);

  Never fail(String key, String message) => throw SpecFormatException(path(key), message);

  Object? raw(String key) => json[key];

  bool has(String key) => json[key] != null;

  String? optText(String key) {
    final v = json[key];
    if (v == null) return null;
    if (v is String) return v;
    fail(key, 'Should be text');
  }

  String text(String key) => optText(key) ?? fail(key, 'Missing "$key"');

  bool? optBool(String key) {
    final v = json[key];
    if (v == null) return null;
    if (v is bool) return v;
    fail(key, 'Should be true or false');
  }

  int? optInt(String key) {
    final v = json[key];
    if (v == null) return null;
    if (v is int) return v;
    fail(key, 'Should be a whole number');
  }

  double? optNumber(String key) {
    final v = json[key];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    fail(key, 'Should be a number');
  }

  List<String>? optTextList(String key) {
    final v = json[key];
    if (v == null) return null;
    if (v is List && v.every((e) => e is String)) return v.cast<String>();
    fail(key, 'Should be a list of text');
  }

  /// The object under [key] as its own [Fields], or null when absent.
  Fields? optObject(String key) {
    final v = json[key];
    if (v == null) return null;
    if (v is Map) return Fields(v.cast<String, dynamic>(), path(key));
    fail(key, 'Should be an object');
  }

  /// The objects of the list under [key], each as its own [Fields]; absent → empty.
  List<Fields> objectList(String key) {
    final v = json[key];
    if (v == null) return const [];
    if (v is! List) fail(key, 'Should be a list');
    return [
      for (var i = 0; i < v.length; i++)
        if (v[i] is Map)
          Fields((v[i] as Map).cast<String, dynamic>(), '${path(key)}[$i]')
        else
          throw SpecFormatException('${path(key)}[$i]', 'Should be an object'),
    ];
  }

  /// A map of text to text (`{"instant": "Instant"}`); absent → empty.
  Map<String, String> textMap(String key) {
    final v = json[key];
    if (v == null) return const {};
    if (v is! Map) fail(key, 'Should be an object');
    if (!v.values.every((e) => e is String)) fail(key, 'Values should be text');
    return v.cast<String, String>();
  }
}

/// Runs [parse] and turns a stray cast failure into a [SpecFormatException] at [where], so
/// a slightly wrong module gets a readable error, not a crash.
T guardSpec<T>(String where, T Function() parse) {
  try {
    return parse();
  } on SpecFormatException {
    rethrow;
  } on TypeError {
    throw SpecFormatException(where, 'A value has the wrong type (e.g. a number where text belongs)');
  }
}
