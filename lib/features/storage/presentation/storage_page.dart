import 'package:flutter/material.dart';

import '../../cluster_overview/application/cluster_overview_controller.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';

class StoragePage extends StatelessWidget {
  const StoragePage({super.key, required this.controller});

  final ClusterOverviewController controller;

  @override
  Widget build(BuildContext context) {
    final ClusterOverviewSnapshot? snapshot = controller.snapshot;
    if (snapshot == null) {
      return const Center(
        child: Text('Storage data will appear after the overview loads.'),
      );
    }
    if (snapshot.storages.isEmpty) {
      return const Center(
        child: Text('No configured storage was reported by this server.'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: snapshot.storages.length + 1,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Storage',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Read-only configuration inventory in this milestone.',
                ),
              ],
            ),
          );
        }
        final ClusterStorage storage = snapshot.storages[index - 1];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: const Icon(Icons.storage_outlined),
            title: Text(storage.name),
            subtitle: Text('${storage.type} · ${storage.content}'),
            trailing: Text(storage.shared ? 'Shared' : 'Local'),
          ),
        );
      },
    );
  }
}
