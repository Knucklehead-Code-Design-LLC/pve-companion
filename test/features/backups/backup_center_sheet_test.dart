import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/backups/presentation/backup_center_sheet.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';
import 'package:pve_companion/features/guests/domain/pve_guest.dart';

void main() {
  testWidgets(
    'guides an operator to Proxmox backup setup when no destination is configured',
    (WidgetTester tester) async {
      Object? copiedValue;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            copiedValue = (call.arguments as Map<Object?, Object?>)['text'];
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: Builder(
            builder: (BuildContext context) => CupertinoPageScaffold(
              child: Center(
                child: CupertinoButton(
                  onPressed: () => showBackupCenterSheet(
                    context,
                    session: const _EmptyBackupSession(),
                    overview: _emptyOverview,
                  ),
                  child: const Text('Open Backup Center'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Backup Center'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Refresh backup center'), findsOneWidget);
      expect(find.bySemanticsLabel('Refresh backup center'), findsOneWidget);
      expect(find.text('Set up backup storage'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('backup-readiness-summary')),
        findsOneWidget,
      );
      expect(find.text('No backup destination reported'), findsOneWidget);
      expect(find.text('Open Datacenter → Storage'), findsOneWidget);
      expect(find.text('Open Datacenter → Backup'), findsOneWidget);
      expect(find.text('Copy storage path'), findsOneWidget);

      final copyStoragePath = find.text('Copy storage path');
      await tester.ensureVisible(copyStoragePath);
      await tester.pumpAndSettle();
      await tester.tap(copyStoragePath);
      await tester.pump();

      expect(copiedValue, 'Datacenter → Storage');
      expect(find.text('Storage path copied'), findsOneWidget);
    },
  );
}

const ClusterOverviewSnapshot _emptyOverview = ClusterOverviewSnapshot(
  version: PveVersion(version: '9.0'),
  nodes: <ClusterNode>[ClusterNode(name: 'pve-01', status: 'online')],
  guests: <PveGuest>[],
  storages: <ClusterStorage>[],
  tasks: <ClusterTask>[],
);

class _EmptyBackupSession implements ProxmoxSession {
  const _EmptyBackupSession();

  @override
  void close() {}

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async => const <Object?>[];

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) async => null;
}
