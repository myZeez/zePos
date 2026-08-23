import 'package:flutter/material.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
    this.actionBelowHeading = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;
  final bool actionBelowHeading;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: ZeText.cardTitle),
        const SizedBox(height: ZeSpace.xxs),
        Text(subtitle, style: ZeText.meta),
      ],
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZeSpace.md),
      decoration: zePanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (actionBelowHeading) ...[
            heading,
            if (action case final Widget currentAction) ...[
              const SizedBox(height: ZeSpace.sm),
              currentAction,
            ],
          ] else
            LayoutBuilder(
              builder: (context, constraints) {
                final stackAction =
                    constraints.maxWidth < 460 && action != null;
                if (stackAction) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      heading,
                      const SizedBox(height: ZeSpace.sm),
                      action!,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: heading),
                    if (action case final Widget currentAction) ...[
                      const SizedBox(width: ZeSpace.md),
                      currentAction,
                    ],
                  ],
                );
              },
            ),
          const SizedBox(height: ZeSpace.md),
          child,
        ],
      ),
    );
  }
}
