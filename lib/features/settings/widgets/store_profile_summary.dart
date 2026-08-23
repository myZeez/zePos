import 'package:flutter/material.dart';
import 'package:zepos/domain/store_profile.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class StoreProfileSummary extends StatelessWidget {
  const StoreProfileSummary({super.key, required this.profile});

  final StoreProfile profile;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: ZeSpace.lg,
        runSpacing: ZeSpace.sm,
        children: [
          _SettingsDataPoint(label: 'Usaha', value: profile.storeName),
          _SettingsDataPoint(label: 'Pemilik', value: profile.ownerName),
          _SettingsDataPoint(label: 'Telepon', value: profile.phone),
          SizedBox(
            width: constraints.maxWidth,
            child: _SettingsDataPoint(label: 'Alamat', value: profile.address),
          ),
        ],
      ),
    );
  }
}

class _SettingsDataPoint extends StatelessWidget {
  const _SettingsDataPoint({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ZeText.meta),
        const SizedBox(height: ZeSpace.xxs),
        Text(value, style: ZeText.body),
      ],
    );
  }
}
