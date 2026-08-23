import 'package:flutter/material.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class ZeFilterChip extends StatelessWidget {
  const ZeFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: ZeColors.surfaceSelected,
      labelStyle: TextStyle(
        color: selected ? ZeColors.primaryStrong : ZeColors.navigationInk,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: ZeColors.border),
      ),
    );
  }
}
