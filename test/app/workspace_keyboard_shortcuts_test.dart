import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/workspace/workspace_command_palette.dart';
import 'package:pve_companion/app/workspace/workspace_keyboard_shortcuts.dart';
import 'package:pve_companion/app/workspace/workspace_section.dart';

void main() {
  testWidgets('uses macOS shortcuts only for refresh and section navigation', (
    WidgetTester tester,
  ) async {
    var refreshes = 0;
    var selectedSection = WorkspaceSection.overview;

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
    var refreshes = 0;
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

  testWidgets('opens the command palette from Command-K', (
    WidgetTester tester,
  ) async {
    var paletteRequests = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: WorkspaceKeyboardShortcuts(
          enabled: true,
          onRefresh: () async {},
          onSectionSelected: (_) {},
          onOpenCommandPalette: () => paletteRequests += 1,
          child: const SizedBox.expand(),
        ),
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);

    expect(paletteRequests, 1);
  });

  testWidgets('Escape dismisses the open command palette', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: WorkspaceKeyboardShortcuts(
          enabled: true,
          onRefresh: () async {},
          onSectionSelected: (_) {},
          child: Builder(
            builder: (BuildContext context) => CupertinoButton(
              onPressed: () => showWorkspaceCommandPalette(
                context,
                onRefresh: () async {},
                onSectionSelected: (_) {},
                onManageServers: () {},
                onManageNotifications: () {},
                onViewPortfolio: () {},
              ),
              child: const Text('Open command palette'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open command palette'));
    await tester.pumpAndSettle();
    expect(find.text('Command Palette'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Command Palette'), findsNothing);
  });
}
