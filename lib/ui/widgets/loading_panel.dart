import 'package:flutter/material.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class LoadingPanel extends StatelessWidget {
  const LoadingPanel({super.key, this.width, required this.height});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: ZeColors.borderSoft,
        borderRadius: ZeRadius.panel,
      ),
    );
  }
}
