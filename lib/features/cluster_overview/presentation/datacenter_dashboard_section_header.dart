import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';

class DatacenterDashboardSectionHeader extends StatelessWidget {
  const DatacenterDashboardSectionHeader({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.actionSemanticsLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final String actionSemanticsLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return PveSectionHeader(
      title: title,
      actionLabel: actionLabel,
      actionSemanticsLabel: actionSemanticsLabel,
      onAction: onAction,
    );
  }
}
