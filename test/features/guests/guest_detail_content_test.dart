import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/core/api/proxmox_task.dart';
import 'package:pve_companion/features/guests/application/guest_detail_controller.dart';
import 'package:pve_companion/features/guests/data/proxmox_guest_repository.dart';
import 'package:pve_companion/features/guests/domain/pve_guest.dart';
import 'package:pve_companion/features/guests/presentation/guest_detail_content.dart';

void main() {
  testWidgets('keeps template power controls and console unavailable', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const PveGuest template = PveGuest(
      vmid: 900,
      node: 'pve-01',
      kind: GuestKind.virtualMachine,
      status: 'stopped',
      name: 'ubuntu-template',
      isTemplate: true,
    );
    final GuestDetailController controller = GuestDetailController(
      repository: _TemplateGuestRepository(),
      session: const _GuestSession(),
      guest: template,
    );
    addTearDown(controller.dispose);
    await controller.load();
    final ScrollController scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: GuestDetailContent(
            controller: controller,
            scrollController: scrollController,
            backupStorageNames: const <String>['backup'],
            onPowerAction: (_) async {},
            onCreateSnapshot: () async {},
            onSnapshotAction: (_, _) async {},
            onRunBackup: () async {},
            onEditConfiguration: () async {},
            onOpenConsole: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Template'), findsOneWidget);
    expect(find.text('Guest power'), findsNothing);
    expect(find.text('Open Guest Console'), findsNothing);
    expect(find.text('Snapshots'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
  });
}

class _TemplateGuestRepository implements PveGuestRepository {
  @override
  Future<PveGuestDetails> loadDetails(
    ProxmoxSession session,
    PveGuest guest,
  ) async => PveGuestDetails(
    guest: guest,
    runtime: PveGuestRuntime.fromGuest(guest),
    configuration: const <String, String>{},
  );

  @override
  Future<ProxmoxTaskReference?> runPowerAction(
    ProxmoxSession session,
    PveGuest guest,
    GuestPowerAction action,
  ) => throw UnimplementedError();

  @override
  Future<ProxmoxTaskReference> createSnapshot(
    ProxmoxSession session,
    PveGuest guest, {
    required String name,
    String? description,
    required bool includeMemoryState,
  }) => throw UnimplementedError();

  @override
  Future<ProxmoxTaskReference> rollbackSnapshot(
    ProxmoxSession session,
    PveGuest guest,
    PveGuestSnapshot snapshot,
  ) => throw UnimplementedError();

  @override
  Future<ProxmoxTaskReference> deleteSnapshot(
    ProxmoxSession session,
    PveGuest guest,
    PveGuestSnapshot snapshot,
  ) => throw UnimplementedError();

  @override
  Future<ProxmoxTaskReference> createBackup(
    ProxmoxSession session,
    PveGuest guest,
    PveGuestBackupRequest request,
  ) => throw UnimplementedError();

  @override
  Future<void> updateConfiguration(
    ProxmoxSession session,
    PveGuest guest,
    PveGuestConfigurationChange change,
  ) => throw UnimplementedError();
}

class _GuestSession implements ProxmoxSession {
  const _GuestSession();

  @override
  void close() {}

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async => null;

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) async => null;
}
