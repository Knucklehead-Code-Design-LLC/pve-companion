import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../../cluster_overview/application/cluster_overview_controller.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';

class StoragePage extends StatelessWidget {
  const StoragePage({super.key, required this.controller});

  final ClusterOverviewController controller;

  @override
  Widget build(BuildContext context) {
    final ClusterOverviewSnapshot? snapshot = controller.snapshot;
    if (snapshot == null) {
      return const PveLoadingState(label: 'Loading storage');
    }
    if (snapshot.storages.isEmpty) {
      return const PveEmptyState(
        icon: CupertinoIcons.tray,
        title: 'No storage reported',
        message: 'This server did not report configured storage.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        const PvePageHeader(
          title: 'Storage',
          subtitle: 'Configured storage visible to this Proxmox connection.',
        ),
        const SizedBox(height: 20),
        PveInsetGroup(
          child: Column(
            children: <Widget>[
              for (
                int index = 0;
                index < snapshot.storages.length;
                index++
              ) ...<Widget>[
                _StorageRow(storage: snapshot.storages[index]),
                if (index < snapshot.storages.length - 1)
                  const PveRowSeparator(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Capacity and utilization depend on the permissions and API data '
            'reported by the connected server.',
            style: PveAppleText.caption(context),
          ),
        ),
      ],
    );
  }
}

class _StorageRow extends StatelessWidget {
  const _StorageRow({required this.storage});

  final ClusterStorage storage;

  @override
  Widget build(BuildContext context) {
    return PveListRow(
      leading: const Icon(CupertinoIcons.tray_full_fill),
      title: Text(storage.name),
      subtitle: Text('${storage.type} · ${storage.content}'),
      trailing: PveStatusPill(
        label: storage.shared ? 'Shared' : 'Local',
        color: PveAppleColors.primary(context),
      ),
    );
  }
}
