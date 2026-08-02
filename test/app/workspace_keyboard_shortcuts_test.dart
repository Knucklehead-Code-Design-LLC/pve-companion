import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/workspace/workspace_keyboard_shortcuts.dart';
import 'package:pve_companion/app/workspace/workspace_section.dart';

void main() {
  testWidgets('uses macOS shortcuts only for refresh and section navigation', (
    WidgetTester tester,
  ) async {
    int refreshes = 0;
    WorkspaceSection selectedSection = WorkspaceSection.overview;

    await tester.pumpWidget(
      CupertinoApp(
        home: WorkspaceKeyboardShortcuts(
          enabled: true,
          onRefresh: () async => refreshes += 1,
          onSectionSelected: (WorkspaceSection section) {
            selectedSection = section;
          },
          child: const SizedBox.expand(),
        ),
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(refreshes, 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    expect(selectedSection, WorkspaceSection.storage);
  });

  testWidgets('does not install shortcuts when disabled', (
    WidgetTester tester,
  ) async {
    int refreshes = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: WorkspaceKeyboardShortcuts(
          enabled: false,
          onRefresh: () async => refreshes += 1,
          onSectionSelected: (_) {},
          child: const SizedBox.expand(),
        ),
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(refreshes, 0);
  });
}
