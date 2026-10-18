import 'package:flutter/material.dart';

/// App colors from the redesign. The three accents (amber, mint, violet) are reserved for
/// tracking state (e.g. Vale zones), never for families or decoration.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.text,
    required this.text2,
    required this.muted,
    required this.amber,
    required this.mint,
    required this.violet,
    required this.danger,
    required this.warn,
    required this.accent,
  });

  final Color bg, surface, surface2, line, text, text2, muted;
  final Color amber, mint, violet, danger, warn;

  /// The neutral accent (cream in the dark theme, ink in the light one): picked states,
  /// the My cards total badge, the Next button. Zone colors mean zones only.
  final Color accent;

  /// A light, colourful tint for the picked cost's cards (band in the flowing grid, panel in
  /// the grouped one). Sky blue: not one of the three zone colours, and visible on dark art.
  Color get highlight => bg == dark.bg ? const Color(0xFF7CC4FF) : const Color(0xFF2F7FD6);

  /// The checklist card is parchment in both themes.
  static const parchment = Color(0xFFF3E9D6);
  static const ink = Color(0xFF1E1B16);
  static const inkMuted = Color(0xFF5B544A);
  static const inkDone = Color(0xFF7A7368);

  static const dark = Palette(
    bg: Color(0xFF121315),
    surface: Color(0xFF1C1D21),
    surface2: Color(0xFF26282D),
    line: Color(0xFF34363C),
    text: Color(0xFFF2EDE4),
    text2: Color(0xFFB9B4AA),
    muted: Color(0xFF8E8A82),
    amber: Color(0xFFF2B544),
    mint: Color(0xFF5ED6B4),
    violet: Color(0xFFB79CFF),
    danger: Color(0xFFFF8A7A),
    warn: Color(0xFFF2B544),
    accent: Color(0xFFEDE2CC),
  );

  static const light = Palette(
    bg: Color(0xFFF5EFE3),
    surface: Color(0xFFFFFDF8),
    surface2: Color(0xFFEDE4D3),
    line: Color(0xFFDDD3C1),
    text: Color(0xFF1E1B16),
    text2: Color(0xFF5B544A),
    muted: Color(0xFF8A8276),
    amber: Color(0xFFA86A00),
    mint: Color(0xFF0E8A68),
    violet: Color(0xFF6B4FD1),
    danger: Color(0xFFC0392B),
    warn: Color(0xFFA86A00),
    accent: Color(0xFF1E1B16),
  );

  /// Foreground on a filled zone/badge color.
  Color get onAccent => bg == dark.bg ? const Color(0xFF121315) : Colors.white;

  /// Foreground on the filled [accent]: near-black ink on cream, white on ink.
  Color get onAccentFill => bg == dark.bg ? const Color(0xFF111115) : Colors.white;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension PaletteX on BuildContext {
  Palette get pal => Theme.of(this).extension<Palette>()!;
}

ThemeData buildTheme(Palette p, Brightness b) {
  final scheme = ColorScheme.fromSeed(
    seedColor: p.violet,
    brightness: b,
    surface: p.bg,
    onSurface: p.text,
    primary: p.text,
    onPrimary: p.bg,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, fontFamily: 'Figtree');
  // Modules may ship Chinese (or other CJK) text, which Figtree lacks: name the system CJK
  // fonts as fallbacks so the glyphs come from the phone instead of showing as boxes.
  TextTheme withFallback(TextTheme t) => t.apply(fontFamilyFallback: cjkFallback);
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    dividerColor: p.line,
    extensions: [p],
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      modalBackgroundColor: p.surface,
      showDragHandle: true,
      dragHandleColor: p.line,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    popupMenuTheme: PopupMenuThemeData(color: p.surface2),
    dialogTheme: DialogThemeData(backgroundColor: p.surface),
    textTheme: withFallback(base.textTheme.apply(bodyColor: p.text, displayColor: p.text)),
    primaryTextTheme: withFallback(base.primaryTextTheme),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onAccentFill : p.text,
        ),
        side: WidgetStateProperty.all(BorderSide(color: p.line)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onAccentFill : p.text2),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : p.surface2),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : p.muted),
    ),
  );
}

/// System CJK font names, tried in order when Figtree has no glyph (Android, iOS, Windows).
const cjkFallback = [
  'Noto Sans TC',
  'Noto Sans SC',
  'Noto Sans CJK TC',
  'Noto Sans CJK SC',
  'PingFang TC',
  'PingFang SC',
  'Microsoft JhengHei',
  'Microsoft YaHei',
];

/// Shared text styles (Figtree, sizes from the redesign's type scale).
class T {
  static const display = TextStyle(fontSize: 30, height: 1.1, fontWeight: FontWeight.w800, letterSpacing: -0.45);
  static const title = TextStyle(fontSize: 24, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.24);
  static const effect = TextStyle(fontSize: 19, height: 1.35, fontWeight: FontWeight.w500);
  static const body = TextStyle(fontSize: 16, height: 1.35, fontWeight: FontWeight.w500);
  static const label = TextStyle(fontSize: 13, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: 1.0);
  static const caption = TextStyle(fontSize: 12.5, height: 1.2, fontWeight: FontWeight.w600);
}
