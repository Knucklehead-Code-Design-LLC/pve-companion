import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_modal_sheet.dart';
import '../application/system_surfaces_controller.dart';

Future<void> showDatacenterWatchSheet(
  BuildContext context, {
  required SystemSurfacesController controller,
}) {
  return showPveModalSheet<void>(
    context: context,
    scrollableBuilder:
        (BuildContext sheetContext, ScrollController scrollController) {
          return DatacenterWatchSheet(
            controller: controller,
            scrollController: scrollController,
          );
        },
  );
}

class DatacenterWatchSheet extends StatelessWidget {
  const DatacenterWatchSheet({
    super.key,
    required this.controller,
    required this.scrollController,
  });

  final SystemSurfacesController controller;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        return CupertinoPageScaffold(
          backgroundColor: PveAppleColors.page(context),
          navigationBar: CupertinoNavigationBar(
            middle: const Text('Datacenter Watch'),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: controller.isBusy
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: controller.canStartDatacenterWatch
                  ? () => _start(context)
                  : null,
              child: controller.isBusy
                  ? const CupertinoActivityIndicator(radius: 9)
                  : const Text('Start'),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
              children: <Widget>[
                Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: PveAppleColors.primary(
                        context,
                      ).withValues(alpha: 0.13),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      CupertinoIcons.waveform_path_ecg,
                      size: 29,
                      color: PveAppleColors.primary(context),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Follow a maintenance window at a glance',
                  textAlign: TextAlign.center,
                  style: PveAppleText.title2(context),
                ),
                const SizedBox(height: 8),
                Text(
                  'A four-hour Live Activity keeps the latest datacenter '
                  'summary on the Lock Screen and, on supported iPhones, in '
                  'the Dynamic Island.',
                  textAlign: TextAlign.center,
                  style: PveAppleText.secondary(context),
                ),
                const SizedBox(height: 24),
                CupertinoListSection.insetGrouped(
                  margin: EdgeInsets.zero,
                  children: const <Widget>[
                    CupertinoListTile(
                      leading: Icon(CupertinoIcons.heart_fill),
                      title: Text('Health first'),
                      subtitle: Text(
                        'See status, online nodes, running guests, and '
                        'current tasks without opening the app.',
                      ),
                    ),
                    CupertinoListTile(
                      leading: Icon(CupertinoIcons.lock_shield_fill),
                      title: Text('Safe for the Lock Screen'),
                      subtitle: Text(
                        'Only summary counts appear—never hostnames, IP '
                        'addresses, usernames, or credentials.',
                      ),
                    ),
                    CupertinoListTile(
                      leading: Icon(CupertinoIcons.clock_fill),
                      title: Text('Time bounded'),
                      subtitle: Text(
                        'The watch is designed for a maintenance or '
                        'incident window and updates when PVE Companion '
                        'refreshes.',
                      ),
                    ),
                  ],
                ),
                if (controller.errorMessage != null) ...<Widget>[
                  const SizedBox(height: 14),
                  Text(
                    controller.errorMessage!,
                    textAlign: TextAlign.center,
                    style: PveAppleText.secondary(
                      context,
                    ).copyWith(color: PveAppleColors.destructive(context)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _start(BuildContext context) async {
    final bool started = await controller.startDatacenterWatch();
    if (started && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
