import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_modal_sheet.dart';
import '../application/datacenter_notifications_controller.dart';
import '../data/local_notification_repository.dart';
import '../domain/datacenter_notification_preferences.dart';

Future<void> showDatacenterNotificationsSheet(
  BuildContext context, {
  required DatacenterNotificationsController controller,
}) {
  return showPveModalSheet<void>(
    context: context,
    scrollableBuilder:
        (BuildContext sheetContext, ScrollController scrollController) =>
            _DatacenterNotificationsSheet(
              controller: controller,
              scrollController: scrollController,
            ),
  );
}

class _DatacenterNotificationsSheet extends StatelessWidget {
  const _DatacenterNotificationsSheet({
    required this.controller,
    required this.scrollController,
  });

  final DatacenterNotificationsController controller;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: PveAppleColors.page(context),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Notifications'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, Widget? child) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _NotificationContent(
                  controller: controller,
                  scrollController: scrollController,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationContent extends StatelessWidget {
  const _NotificationContent({
    required this.controller,
    required this.scrollController,
  });

  final DatacenterNotificationsController controller;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading) {
      return const PveLoadingState(label: 'Loading notification settings');
    }
    final LocalNotificationAuthorization authorization =
        controller.authorization;
    final bool supported =
        authorization != LocalNotificationAuthorization.unsupported;
    final bool authorized =
        authorization == LocalNotificationAuthorization.authorized;
    final DatacenterNotificationSettings settings = controller.settings;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 32),
      children: <Widget>[
        Text('Datacenter alerts', style: PveAppleText.title2(context)),
        const SizedBox(height: 6),
        Text(
          'Alerts are evaluated after PVE Companion refreshes a signed-in datacenter. They are not a replacement for a background monitoring service or Proxmox’s own alerting.',
          style: PveAppleText.secondary(context),
        ),
        const SizedBox(height: 18),
        _NotificationPermissionCard(
          authorization: authorization,
          requesting: controller.isRequestingAuthorization,
          onRequest: controller.requestAuthorization,
        ),
        if (controller.errorMessage != null) ...<Widget>[
          const SizedBox(height: 10),
          PveInsetGroup(
            color: PveAppleColors.destructive(context).withValues(alpha: 0.08),
            padding: const EdgeInsets.all(12),
            child: Text(
              controller.errorMessage!,
              style: PveAppleText.secondary(
                context,
              ).copyWith(color: PveAppleColors.destructive(context)),
            ),
          ),
        ],
        const SizedBox(height: 24),
        CupertinoFormSection.insetGrouped(
          margin: EdgeInsets.zero,
          header: const Text('WHEN TO ALERT'),
          footer: Text(
            supported
                ? authorized
                      ? 'New matching incidents create a local alert once per active incident.'
                      : 'Choose alert types now, then allow notifications to receive them.'
                : 'Notifications are available on iPhone, iPad, and Mac builds of PVE Companion.',
          ),
          children: <Widget>[
            CupertinoFormRow(
              prefix: const Text('Critical incidents'),
              helper: const Text(
                'Offline nodes, critical capacity pressure, and unavailable storage.',
              ),
              child: CupertinoSwitch(
                value: settings.criticalIncidentsEnabled,
                onChanged: supported
                    ? (bool value) => controller.updateSettings(
                        settings.copyWith(criticalIncidentsEnabled: value),
                      )
                    : null,
              ),
            ),
            CupertinoFormRow(
              prefix: const Text('Attention alerts'),
              helper: const Text(
                'Warning-level capacity pressure and failed recent tasks.',
              ),
              child: CupertinoSwitch(
                value: settings.attentionIncidentsEnabled,
                onChanged: supported
                    ? (bool value) => controller.updateSettings(
                        settings.copyWith(attentionIncidentsEnabled: value),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NotificationPermissionCard extends StatelessWidget {
  const _NotificationPermissionCard({
    required this.authorization,
    required this.requesting,
    required this.onRequest,
  });

  final LocalNotificationAuthorization authorization;
  final bool requesting;
  final Future<void> Function() onRequest;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (authorization) {
      LocalNotificationAuthorization.authorized => PveAppleColors.success(
        context,
      ),
      LocalNotificationAuthorization.denied => PveAppleColors.warning(context),
      LocalNotificationAuthorization.undetermined => PveAppleColors.primary(
        context,
      ),
      LocalNotificationAuthorization.unsupported =>
        PveAppleColors.secondaryLabel(context),
    };
    return PveInsetGroup(
      color: color.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Icon(_authorizationIcon(authorization), size: 22, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _authorizationTitle(authorization),
                  style: PveAppleText.title3(context),
                ),
                const SizedBox(height: 2),
                Text(
                  _authorizationDetail(authorization),
                  style: PveAppleText.secondary(context),
                ),
              ],
            ),
          ),
          if (authorization == LocalNotificationAuthorization.undetermined)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(44, 36),
              onPressed: requesting ? null : onRequest,
              child: requesting
                  ? const CupertinoActivityIndicator(radius: 8)
                  : const Text('Allow'),
            ),
        ],
      ),
    );
  }
}

IconData _authorizationIcon(LocalNotificationAuthorization authorization) =>
    switch (authorization) {
      LocalNotificationAuthorization.authorized =>
        CupertinoIcons.check_mark_circled_solid,
      LocalNotificationAuthorization.denied => CupertinoIcons.bell_slash_fill,
      LocalNotificationAuthorization.undetermined => CupertinoIcons.bell_fill,
      LocalNotificationAuthorization.unsupported => CupertinoIcons.info_circle,
    };

String _authorizationTitle(LocalNotificationAuthorization authorization) =>
    switch (authorization) {
      LocalNotificationAuthorization.authorized => 'Notifications allowed',
      LocalNotificationAuthorization.denied => 'Notifications are off',
      LocalNotificationAuthorization.undetermined => 'Allow notifications',
      LocalNotificationAuthorization.unsupported => 'Notifications unavailable',
    };

String _authorizationDetail(
  LocalNotificationAuthorization authorization,
) => switch (authorization) {
  LocalNotificationAuthorization.authorized =>
    'PVE Companion can alert you to new matching incidents during refreshes.',
  LocalNotificationAuthorization.denied =>
    'Enable notifications for PVE Companion in your device Settings to receive alerts.',
  LocalNotificationAuthorization.undetermined =>
    'Allow alerts to receive new incidents while you use PVE Companion.',
  LocalNotificationAuthorization.unsupported =>
    'This runtime does not support Apple local notifications.',
};
