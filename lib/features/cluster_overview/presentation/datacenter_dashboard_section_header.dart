import 'package:flutter/material.dart';

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
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        Semantics(
          button: true,
          label: actionSemanticsLabel,
          child: TextButton(onPressed: onAction, child: Text(actionLabel)),
        ),
      ],
    );
  }
}
