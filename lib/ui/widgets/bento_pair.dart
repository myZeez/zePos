import 'package:flutter/material.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class BentoPair extends StatelessWidget {
  const BentoPair({
    super.key,
    required this.primary,
    required this.secondary,
    this.primaryFlex = 1,
    this.secondaryFlex = 1,
  });

  final Widget primary;
  final Widget secondary;
  final int primaryFlex;
  final int secondaryFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 920) {
          return Column(
            children: [
              primary,
              const SizedBox(height: ZeSpace.md),
              secondary,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: primaryFlex, child: primary),
            const SizedBox(width: ZeSpace.md),
            Expanded(flex: secondaryFlex, child: secondary),
          ],
        );
      },
    );
  }
}
