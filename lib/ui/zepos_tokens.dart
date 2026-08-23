import 'package:flutter/material.dart';

abstract final class ZeColors {
  // Architectural schematic palette: paper, graphite, and drafting blue.
  static const background = Color(0xFFF9F9F9);
  static const surface = Color(0xFFFCFCFC);
  static const surfaceSubtle = Color(0xFFF1F4F6);
  static const surfaceSelected = Color(0xFFE3F0FC);
  static const border = Color(0xFFB9C6D0);
  static const borderSoft = Color(0xFFD9E0E5);

  static const ink = Color(0xFF222222);
  static const body = Color(0xFF39444D);
  static const muted = Color(0xFF5C6872);
  static const subtle = Color(0xFF687681);

  static const primary = Color(0xFF4A90E2);
  static const primaryStrong = Color(0xFF2D74BB);
  static const primaryDark = Color(0xFF205788);
  static const primarySoft = Color(0xFFE7F1FB);
  static const success = Color(0xFF237A50);
  static const successDark = Color(0xFF16583A);
  static const successSoft = Color(0xFFE8F4ED);
  static const warning = Color(0xFF9A6516);
  static const warningDark = Color(0xFF70480C);
  static const warningSoft = Color(0xFFFCF3DD);
  static const danger = Color(0xFFAD3632);
  static const dangerSoft = Color(0xFFFAEBEA);
  static const dangerBorder = Color(0xFFE3B8B5);

  static const navigationInk = Color(0xFF44515A);
  static const secondaryText = Color(0xFF49555E);
  static const mutedAlt = Color(0xFF62707A);
  static const successBanner = Color(0xFFE1F2E8);
}

abstract final class ZeSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  static const page = EdgeInsets.fromLTRB(lg, xxs, lg, lg);
  static const bentoGap = sm;
}

abstract final class ZeRadius {
  static const control = BorderRadius.all(Radius.circular(6));
  static const panel = BorderRadius.all(Radius.circular(8));
  static const nav = BorderRadius.all(Radius.circular(8));
  static const pill = BorderRadius.all(Radius.circular(999));
}

abstract final class ZeText {
  static const pageTitle = TextStyle(
    color: ZeColors.ink,
    fontSize: 26,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );
  static const sectionTitle = TextStyle(
    color: ZeColors.ink,
    fontSize: 18,
    height: 1.25,
    fontWeight: FontWeight.w600,
  );
  static const cardTitle = TextStyle(
    color: ZeColors.ink,
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w600,
  );
  static const body = TextStyle(
    color: ZeColors.body,
    fontSize: 14,
    height: 1.45,
  );
  static const meta = TextStyle(
    color: ZeColors.subtle,
    fontSize: 13,
    height: 1.35,
    fontFamily: 'Consolas',
  );
  static const label = TextStyle(
    color: ZeColors.body,
    fontSize: 13,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.25,
  );
}

BoxDecoration zePanelDecoration({Color color = ZeColors.surface}) {
  return BoxDecoration(
    color: color,
    borderRadius: ZeRadius.panel,
    border: Border.all(color: ZeColors.border, width: 1),
  );
}
