import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../application/cluster_overview_controller.dart';

class ClusterLoadStateView extends StatelessWidget {
  const ClusterLoadStateView({
    super.key,
    required this.controller,
    required this.loadingLabel,
    required this.onRetry,
  });

  final ClusterOverviewController controller;
  final String loadingLabel;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (controller.state != ClusterOverviewLoadState.failed) {
      return PveLoadingState(label: loadingLabel);
    }
    return PveEmptyState(
      icon: CupertinoIcons.exclamationmark_triangle,
      title: 'Datacenter unavailable',
      message: controller.errorMessage ?? 'Cluster data could not be loaded.',
      actionLabel: 'Try Again',
      onAction: onRetry,
      destructive: true,
    );
  }
}

class ClusterRefreshFailureBanner extends StatelessWidget {
  const ClusterRefreshFailureBanner({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final warning = PveAppleColors.warning(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Refresh failed. $message',
      child: PveInsetGroup(
        color: warning.withValues(alpha: 0.08),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                size: 19,
                color: warning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PveAppleText.secondary(context),
              ),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: const Size(44, 40),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
