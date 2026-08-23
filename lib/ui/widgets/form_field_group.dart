import 'package:flutter/material.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class FormFieldGroup extends StatelessWidget {
  const FormFieldGroup({
    super.key,
    required this.label,
    required this.child,
    this.action,
  });

  final String label;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: ZeText.label),
            if (action case final Widget currentAction) ...[
              const Spacer(),
              currentAction,
            ],
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
