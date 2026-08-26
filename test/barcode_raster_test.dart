import 'package:barcode/barcode.dart' as barcode;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zepos/core/printing/barcode_raster.dart';

/// Widths of consecutive same-colour vertical runs across the middle row.
/// A symbol a laser scanner can decode has every run an exact multiple of one
/// module, so these widths must all share a single common divisor.
List<int> _runWidths(img.Image bitmap) {
  final y = bitmap.height ~/ 2;
  final runs = <int>[];
  var current = 1;
  var previousDark = bitmap.getPixel(0, y).r < 128;
  for (var x = 1; x < bitmap.width; x++) {
    final dark = bitmap.getPixel(x, y).r < 128;
    if (dark == previousDark) {
      current++;
    } else {
      runs.add(current);
      current = 1;
      previousDark = dark;
    }
  }
  runs.add(current);
  return runs;
}

void main() {
  test('setiap modul barcode dicetak dengan lebar dot yang sama', () {
    final result = rasterizeBarcode(
      barcode.Barcode.code128(),
      '8991234567890',
      availableWidthMm: 37,
      heightMm: 8,
      mediaWidthMm: 40,
    );

    // Every run must be a whole number of modules. Uneven modules are exactly
    // what makes a laser scanner reject an otherwise good-looking label.
    final widths = _runWidths(result.image);
    final interior = widths.sublist(1, widths.length - 1);
    for (final width in interior) {
      expect(
        width % result.dotsPerModule,
        0,
        reason:
            'run selebar $width dot bukan kelipatan '
            '${result.dotsPerModule} dot per modul',
      );
    }
  });

  test('ukuran yang dilaporkan cocok dengan jumlah dot sebenarnya', () {
    const mediaWidthMm = 40.0;
    const dpi = 203;
    final result = rasterizeBarcode(
      barcode.Barcode.code128(),
      '8991234567890',
      availableWidthMm: 37,
      heightMm: 8,
      mediaWidthMm: mediaWidthMm,
      dpi: dpi,
    );

    // The caller draws the bitmap at exactly widthMm x heightMm; if that does
    // not correspond 1:1 to the dot grid, the printer resamples it again.
    final dotsPerMm = (mediaWidthMm * dpi / 25.4).floor() / mediaWidthMm;
    expect(result.widthMm, closeTo(result.image.width / dotsPerMm, 0.001));
    expect(result.heightMm, closeTo(result.image.height / dotsPerMm, 0.001));
    expect(
      result.moduleWidthMm,
      closeTo(result.dotsPerModule / dotsPerMm, 0.001),
    );
  });

  test('barcode tetap muat dan menyisakan quiet zone pada label sempit', () {
    final narrow = rasterizeBarcode(
      barcode.Barcode.code128(),
      '8991234567890',
      availableWidthMm: 22,
      heightMm: 6,
      mediaWidthMm: 25,
    );

    expect(narrow.dotsPerModule, greaterThanOrEqualTo(1));
    expect(narrow.image.width, lessThanOrEqualTo((22 * 203 / 25.4).ceil()));
    // Both edges stay blank so a scanner can find where the symbol begins.
    final y = narrow.image.height ~/ 2;
    expect(narrow.image.getPixel(0, y).r, greaterThan(128));
    expect(
      narrow.image.getPixel(narrow.image.width - 1, y).r,
      greaterThan(128),
    );
  });

  test('label lebih lebar memberi modul lebih tebal', () {
    final small = rasterizeBarcode(
      barcode.Barcode.code128(),
      '8991234567890',
      availableWidthMm: 30,
      heightMm: 8,
      mediaWidthMm: 33,
    );
    final large = rasterizeBarcode(
      barcode.Barcode.code128(),
      '8991234567890',
      availableWidthMm: 70,
      heightMm: 8,
      mediaWidthMm: 76,
    );

    expect(large.dotsPerModule, greaterThan(small.dotsPerModule));
    expect(large.moduleWidthMm, greaterThan(small.moduleWidthMm));
  });

  test('hasil raster hanya hitam dan putih murni', () {
    final result = rasterizeBarcode(
      barcode.Barcode.code128(),
      '8991234567890',
      availableWidthMm: 37,
      heightMm: 8,
      mediaWidthMm: 40,
    );

    // A grey pixel means the bars were resampled somewhere. The thermal head
    // can only burn a dot or leave it blank, so grey turns into dithering.
    for (var x = 0; x < result.image.width; x += 7) {
      final pixel = result.image.getPixel(x, result.image.height ~/ 2);
      expect(pixel.r == 0 || pixel.r == 255, isTrue);
    }
  });
}
