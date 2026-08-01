import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/pve_companion_theme.dart';
import 'package:pve_companion/core/presentation/pve_apple_ui.dart';

void main() {
  test('Cupertino typography preserves complete native text defaults', () {
    for (final Brightness brightness in Brightness.values) {
      final CupertinoTextThemeData textTheme = PveCompanionTheme.cupertino(
        brightness,
      ).textTheme;
      final Color expectedPrimary = brightness == Brightness.dark
          ? PveAppleColors.accentDark
          : PveAppleColors.accent;

      expect(textTheme.textStyle.color, CupertinoColors.label);
      expect(textTheme.textStyle.decoration, TextDecoration.none);
      expect(textTheme.actionTextStyle.color, expectedPrimary);
      expect(textTheme.actionTextStyle.decoration, TextDecoration.none);
      expect(textTheme.navTitleTextStyle.color, CupertinoColors.label);
      expect(textTheme.navLargeTitleTextStyle.color, CupertinoColors.label);
    }
  });
}
