import 'dart:math' as math;

import 'package:barcode/barcode.dart' as barcode;
import 'package:image/image.dart' as img;

/// Fallback head resolution used when a printer profile does not report one.
/// 203 dpi is the common thermal head pitch (almost exactly 8 dots per mm).
const int defaultPrintHeadDpi = 203;

/// A barcode drawn so that one bitmap pixel is one printer dot.
class RasterizedBarcode {
  const RasterizedBarcode({
    required this.image,
    required this.widthMm,
    required this.heightMm,
    required this.dotsPerModule,
    required this.moduleWidthMm,
    required this.quietZoneModules,
  });

  final img.Image image;

  /// The physical size the caller **must** draw [image] at. Drawing it at any
  /// other size hands the printer back the job of resizing the bars, which is
  /// the whole failure this class exists to avoid.
  final double widthMm;
  final double heightMm;

  /// Printer dots allotted to one barcode module. Identical for every module
  /// in the symbol -- that uniformity is the property scanners depend on.
  final int dotsPerModule;

  /// Width of one module in mm, i.e. the symbol's X-dimension. EAN-13 is
  /// specified at 0.33 mm; scanners tolerate down to roughly 0.26 mm.
  final double moduleWidthMm;

  /// Blank modules kept on each side of the symbol. A scanner that cannot see
  /// clear space fails to find the symbol at all, however clean the bars are.
  final int quietZoneModules;

  /// Whether the symbol still carries enough quiet zone and module width to be
  /// worth sending to a laser scanner.
  bool get isScannable => dotsPerModule >= 2 && quietZoneModules >= 6;
}

/// One stretch of consecutive same-colour modules in a 1-D symbol.
class _ModuleRun {
  const _ModuleRun(this.modules, this.black);
  final int modules;
  final bool black;
}

/// Recovers the symbol's module pattern as whole numbers.
///
/// `Barcode.make` reports bars as floating-point widths scaled to whatever
/// canvas size it is handed, so measuring against the narrowest bar recovers
/// the integer module counts the encoder actually produced.
List<_ModuleRun> _moduleRuns(barcode.Barcode symbology, String value) {
  // Probe on a deliberately huge canvas: the wider it is, the further float
  // error stays below the half-module mark that would misround a run.
  const probeWidth = 100000.0;
  final bars = symbology
      .make(value, width: probeWidth, height: 10, drawText: false)
      .whereType<barcode.BarcodeBar>()
      .toList(growable: false);
  if (bars.isEmpty) return const [];
  final unit = bars.map((bar) => bar.width).reduce(math.min);
  if (unit <= 0) return const [];
  return bars
      .map((bar) => _ModuleRun((bar.width / unit).round(), bar.black))
      .toList(growable: false);
}

/// Dots per mm actually available across a page of [mediaWidthMm].
///
/// The print path renders a whole page into a whole number of device dots and
/// truncates the fractional remainder. Taking the pitch from that truncated
/// count rather than from the nominal dpi keeps the bitmap at a true 1:1 scale
/// end to end.
double _effectiveDotsPerMm(double mediaWidthMm, int dpi) {
  final nominal = dpi / 25.4;
  if (mediaWidthMm <= 0) return nominal;
  final pageDots = (mediaWidthMm * nominal).floor();
  if (pageDots <= 0) return nominal;
  return pageDots / mediaWidthMm;
}

/// Renders [value] as a bitmap sized in whole printer dots.
///
/// Why this is not simply `pw.BarcodeWidget`: that draws the bars as PDF
/// vector rectangles at whatever width the layout gives them, and the printer
/// then rescales them by a fractional factor. A module that should be 2.9 dots
/// wide cannot exist, so the driver rounds each one independently and the
/// symbol comes out with modules of 2 dots here and 3 dots there. It still
/// looks like a barcode, and a phone camera still reads it -- camera decoders
/// find edges at sub-pixel accuracy across a large image. A laser scanner
/// decodes by timing the gaps between edges as the beam sweeps, so those
/// uneven modules read as a corrupt symbol and it refuses the scan.
///
/// So the module width is chosen here, in whole dots, and [RasterizedBarcode]
/// reports the exact physical size the result has to be drawn at.
RasterizedBarcode rasterizeBarcode(
  barcode.Barcode symbology,
  String value, {
  required double availableWidthMm,
  required double heightMm,
  required double mediaWidthMm,
  int dpi = defaultPrintHeadDpi,
  int quietZoneModules = 10,
}) {
  final runs = _moduleRuns(symbology, value);
  final symbolModules = runs.fold<int>(0, (sum, run) => sum + run.modules);
  final dotsPerMm = _effectiveDotsPerMm(mediaWidthMm, dpi);
  final availableDots = math.max(1, (availableWidthMm * dotsPerMm).floor());

  // Widest module the label can hold while still leaving real quiet zones.
  var dotsPerModule = symbolModules > 0
      ? availableDots ~/ (symbolModules + 2 * quietZoneModules)
      : 1;
  if (dotsPerModule < 1) {
    // The symbol is too long for this label even with no quiet zone. One dot
    // per module at least keeps the bars crisp; squeezing it further would
    // only reintroduce the resampling this whole approach avoids.
    dotsPerModule = 1;
  }

  final symbolDots = symbolModules * dotsPerModule;
  final quietDots = math.max(0, ((availableDots - symbolDots) / 2).floor());
  final totalDots = math.max(1, symbolDots + 2 * quietDots);
  final heightDots = math.max(1, (heightMm * dotsPerMm).round());

  final bitmap = img.Image(width: totalDots, height: heightDots);
  bitmap.clear(img.ColorUint8.rgb(255, 255, 255));
  final black = img.ColorUint8.rgb(0, 0, 0);

  var x = quietDots;
  for (final run in runs) {
    final runDots = run.modules * dotsPerModule;
    if (run.black && runDots > 0) {
      img.fillRect(
        bitmap,
        x1: x,
        y1: 0,
        x2: x + runDots - 1,
        y2: heightDots - 1,
        color: black,
      );
    }
    x += runDots;
  }

  return RasterizedBarcode(
    image: bitmap,
    widthMm: totalDots / dotsPerMm,
    heightMm: heightDots / dotsPerMm,
    dotsPerModule: dotsPerModule,
    moduleWidthMm: dotsPerModule / dotsPerMm,
    quietZoneModules: dotsPerModule > 0 ? quietDots ~/ dotsPerModule : 0,
  );
}
