import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/workspace/workspace_deep_link.dart';
import 'package:pve_companion/app/workspace/workspace_section.dart';

void main() {
  test('maps widget destinations to workspace sections', () {
    expect(
      workspaceSectionFromDeepLink(Uri.parse('pvecompanion://datacenter')),
      WorkspaceSection.overview,
    );
    expect(
      workspaceSectionFromDeepLink(Uri.parse('pvecompanion://guests')),
      WorkspaceSection.guests,
    );
    expect(
      workspaceSectionFromDeepLink(Uri.parse('pvecompanion://nodes')),
      WorkspaceSection.nodes,
    );
    expect(
      workspaceSectionFromDeepLink(Uri.parse('pvecompanion://storage')),
      WorkspaceSection.storage,
    );
    expect(
      workspaceSectionFromDeepLink(Uri.parse('pvecompanion://tasks')),
      WorkspaceSection.tasks,
    );
  });

  test('rejects unrelated and unknown links', () {
    expect(
      workspaceSectionFromDeepLink(Uri.parse('https://example.com/nodes')),
      isNull,
    );
    expect(
      workspaceSectionFromDeepLink(Uri.parse('pvecompanion://settings')),
      isNull,
    );
  });
}
