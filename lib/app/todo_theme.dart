import 'package:flutter/material.dart';
import 'dart:ui' show lerpDouble;
import 'package:google_fonts/google_fonts.dart';

class TodoVisuals extends ThemeExtension<TodoVisuals> {
  const TodoVisuals({
    required this.backgroundStart,
    required this.backgroundEnd,
    required this.pageSurface,
    required this.pageBorder,
    required this.sidebar,
    required this.sidebarAccent,
    required this.panel,
    required this.panelAlt,
    required this.panelBorder,
    required this.textStrong,
    required this.textMuted,
    required this.accent,
    required this.accentAlt,
    required this.success,
    required this.danger,
    required this.cut,
  });

  final Color backgroundStart;
  final Color backgroundEnd;
  final Color pageSurface;
  final Color pageBorder;
  final Color sidebar;
  final Color sidebarAccent;
  final Color panel;
  final Color panelAlt;
  final Color panelBorder;
  final Color textStrong;
  final Color textMuted;
  final Color accent;
  final Color accentAlt;
  final Color success;
  final Color danger;
  final double cut;

  @override
  TodoVisuals copyWith({
    Color? backgroundStart,
    Color? backgroundEnd,
    Color? pageSurface,
    Color? pageBorder,
    Color? sidebar,
    Color? sidebarAccent,
    Color? panel,
    Color? panelAlt,
    Color? panelBorder,
    Color? textStrong,
    Color? textMuted,
    Color? accent,
    Color? accentAlt,
    Color? success,
    Color? danger,
    double? cut,
  }) {
    return TodoVisuals(
      backgroundStart: backgroundStart ?? this.backgroundStart,
      backgroundEnd: backgroundEnd ?? this.backgroundEnd,
      pageSurface: pageSurface ?? this.pageSurface,
      pageBorder: pageBorder ?? this.pageBorder,
      sidebar: sidebar ?? this.sidebar,
      sidebarAccent: sidebarAccent ?? this.sidebarAccent,
      panel: panel ?? this.panel,
      panelAlt: panelAlt ?? this.panelAlt,
      panelBorder: panelBorder ?? this.panelBorder,
      textStrong: textStrong ?? this.textStrong,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accentAlt: accentAlt ?? this.accentAlt,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      cut: cut ?? this.cut,
    );
  }

  @override
  TodoVisuals lerp(ThemeExtension<TodoVisuals>? other, double t) {
    if (other is! TodoVisuals) {
      return this;
    }
    return TodoVisuals(
      backgroundStart: Color.lerp(backgroundStart, other.backgroundStart, t)!,
      backgroundEnd: Color.lerp(backgroundEnd, other.backgroundEnd, t)!,
      pageSurface: Color.lerp(pageSurface, other.pageSurface, t)!,
      pageBorder: Color.lerp(pageBorder, other.pageBorder, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      sidebarAccent: Color.lerp(sidebarAccent, other.sidebarAccent, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panelAlt: Color.lerp(panelAlt, other.panelAlt, t)!,
      panelBorder: Color.lerp(panelBorder, other.panelBorder, t)!,
      textStrong: Color.lerp(textStrong, other.textStrong, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentAlt: Color.lerp(accentAlt, other.accentAlt, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      cut: lerpDouble(cut, other.cut, t)!,
    );
  }
}

ThemeData buildTodoTheme() => _buildClassicTheme();

ThemeData _buildClassicTheme() {
  const bone = Color(0xFFF5EEE3);
  const paper = Color(0xFFFFFCF8);
  const ink = Color(0xFF23201B);
  const moss = Color(0xFF6D815A);
  const clay = Color(0xFFB46E54);
  const line = Color(0xFFE0D3C2);

  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: moss,
      brightness: Brightness.light,
      surface: paper,
    ),
    useMaterial3: true,
  );

  final textTheme =
      GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
    displaySmall: GoogleFonts.cormorantGaramond(
      fontSize: 48,
      fontWeight: FontWeight.w700,
      color: ink,
      height: 0.95,
    ),
    headlineMedium: GoogleFonts.plusJakartaSans(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    titleMedium: GoogleFonts.plusJakartaSans(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    bodyMedium: GoogleFonts.plusJakartaSans(
      fontSize: 15,
      height: 1.5,
      color: ink,
    ),
    bodySmall: GoogleFonts.plusJakartaSans(
      fontSize: 13,
      height: 1.45,
      color: ink.withValues(alpha: 0.66),
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: bone,
    textTheme: textTheme,
    extensions: const <ThemeExtension<dynamic>>[
      TodoVisuals(
        backgroundStart: Color(0xFFF6F1E8),
        backgroundEnd: Color(0xFFECE3D7),
        pageSurface: Color(0xC2FFFFFF),
        pageBorder: line,
        sidebar: Color(0xFF1E241F),
        sidebarAccent: Color(0xFF70835D),
        panel: paper,
        panelAlt: Color(0xFFF0E7DA),
        panelBorder: line,
        textStrong: ink,
        textMuted: Color(0xFF6E6A63),
        accent: moss,
        accentAlt: clay,
        success: Color(0xFF5D8A64),
        danger: Color(0xFF9D4436),
        cut: 18,
      ),
    ],
    cardTheme: const CardThemeData(
      color: paper,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        side: BorderSide(color: line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: paper,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: moss, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: moss,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: clay,
      foregroundColor: Colors.white,
    ),
  );
}
