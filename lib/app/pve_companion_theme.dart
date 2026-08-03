import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/presentation/pve_apple_ui.dart';

abstract final class PveCompanionTheme {
  static ThemeData light() => _materialTheme(Brightness.light);

  static ThemeData dark() => _materialTheme(Brightness.dark);

  static CupertinoThemeData cupertino(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final primary = dark ? PveAppleColors.accentDark : PveAppleColors.accent;
    final defaults = CupertinoTextThemeData(primaryColor: primary);
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: primary,
      primaryContrastingColor: CupertinoColors.white,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF000000)
          : const Color(0xFFF2F2F7),
      barBackgroundColor: dark
          ? const Color(0xE61C1C1E)
          : const Color(0xE6F9F9FB),
      textTheme: defaults.copyWith(
        textStyle: defaults.textStyle.copyWith(
          fontFamily: '.SF Pro Text',
          fontSize: 15,
          letterSpacing: -0.08,
        ),
        actionTextStyle: defaults.actionTextStyle.copyWith(
          fontFamily: '.SF Pro Text',
          fontSize: 17,
          letterSpacing: -0.3,
        ),
        navTitleTextStyle: defaults.navTitleTextStyle.copyWith(
          fontFamily: '.SF Pro Text',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        navLargeTitleTextStyle: defaults.navLargeTitleTextStyle.copyWith(
          fontFamily: '.SF Pro Display',
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.7,
        ),
      ),
    );
  }

  static ThemeData _materialTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final primary = dark ? PveAppleColors.accentDark : PveAppleColors.accent;
    final surface = dark ? const Color(0xFF1C1C1E) : Colors.white;
    final background = dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
    final separator = dark ? const Color(0xFF38383A) : const Color(0xFFC6C6C8);
    final colors = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      surface: surface,
      error: dark ? const Color(0xFFFF6961) : const Color(0xFFD70015),
    );
    final textTheme =
        ThemeData(
          brightness: brightness,
          fontFamily: '.SF Pro Text',
        ).textTheme.copyWith(
          headlineSmall: TextStyle(
            fontFamily: '.SF Pro Display',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
            letterSpacing: -0.4,
          ),
          titleLarge: TextStyle(
            fontFamily: '.SF Pro Display',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
            letterSpacing: -0.2,
          ),
          titleMedium: TextStyle(
            fontFamily: '.SF Pro Text',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
          titleSmall: TextStyle(
            fontFamily: '.SF Pro Text',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
          bodyLarge: TextStyle(
            fontFamily: '.SF Pro Text',
            fontSize: 17,
            color: colors.onSurface,
          ),
          bodyMedium: TextStyle(
            fontFamily: '.SF Pro Text',
            fontSize: 15,
            color: colors.onSurface,
            height: 1.35,
          ),
          bodySmall: TextStyle(
            fontFamily: '.SF Pro Text',
            fontSize: 13,
            color: colors.onSurfaceVariant,
            height: 1.3,
          ),
          labelLarge: TextStyle(
            fontFamily: '.SF Pro Text',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: primary,
          ),
          labelMedium: TextStyle(
            fontFamily: '.SF Pro Text',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.onSurfaceVariant,
          ),
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      fontFamily: '.SF Pro Text',
      textTheme: textTheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      cupertinoOverrideTheme: cupertino(brightness),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: separator.withValues(alpha: 0.35),
            width: 0.5,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerColor: separator.withValues(alpha: 0.5),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: separator),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: separator.withValues(alpha: 0.75)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 13,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: dark ? CupertinoColors.black : CupertinoColors.white,
          disabledBackgroundColor: separator.withValues(alpha: 0.5),
          minimumSize: const Size(0, 44),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            color: dark ? CupertinoColors.black : CupertinoColors.white,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(0, 44),
          side: BorderSide(color: separator),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        showDragHandle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark
            ? const Color(0xFF2C2C2E)
            : const Color(0xFFF9F9FB),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
