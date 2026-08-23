import 'package:flutter/material.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final heading = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 20, height: 2, color: ZeColors.primary),
                const SizedBox(width: ZeSpace.xs),
                Expanded(child: Text(title, style: ZeText.pageTitle)),
              ],
            ),
            const SizedBox(height: ZeSpace.xxs),
            Text(
              subtitle,
              maxLines: compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: ZeText.meta,
            ),
          ],
        );
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                compact ? ZeSpace.md : ZeSpace.lg,
                compact ? ZeSpace.sm : ZeSpace.md,
                compact ? ZeSpace.md : ZeSpace.lg,
                compact ? ZeSpace.sm : ZeSpace.md,
              ),
              color: ZeColors.background,
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        heading,
                        if (trailing case final Widget currentTrailing) ...[
                          const SizedBox(height: ZeSpace.sm),
                          currentTrailing,
                        ],
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: heading),
                        if (trailing case final Widget currentTrailing)
                          currentTrailing,
                      ],
                    ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
