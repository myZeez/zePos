import 'package:zepos/core/printing/printing_models.dart';

class PrintValidationException implements Exception {
  const PrintValidationException(this.messages);

  final List<String> messages;

  String get userMessage => messages.join('\n');

  @override
  String toString() => userMessage;
}

abstract final class LabelPrintValidator {
  static List<String> validate({
    required MediaPreset media,
    required PrinterProfile profile,
    required PrintPolicy policy,
    required String barcode,
    required int copies,
    PrinterBinding? binding,
  }) {
    final errors = <String>[];
    final height = media.heightMm ?? 0;
    final pageWidth = media.widthMm * media.columns;

    if (barcode.trim().isEmpty) {
      errors.add('Barcode produk belum tersedia.');
    }
    if (media.purpose != PrintPurpose.label) {
      errors.add('Preset media bukan untuk label.');
    }
    if (media.widthMm < 10 || media.widthMm > profile.maxWidthMm) {
      errors.add(
        'Lebar label harus 10-${profile.maxWidthMm.toStringAsFixed(0)} mm.',
      );
    }
    if (height < 10 || height > 200) {
      errors.add('Tinggi label harus 10-200 mm.');
    }
    if (media.gapMm < 0 || media.gapMm > 10) {
      errors.add('GAP label harus 0-10 mm.');
    }
    if (copies < 1 || copies > 500) {
      errors.add('Jumlah label harus 1-500.');
    }
    if (media.columns < 1 || media.columns > 3) {
      errors.add('Jumlah kolom harus 1-3.');
    }
    if (pageWidth > profile.maxWidthMm) {
      errors.add(
        'Lebar halaman ${pageWidth.toStringAsFixed(1)} mm melebihi kemampuan printer.',
      );
    }
    if (media.offsetXmm < -10 || media.offsetXmm > 10) {
      errors.add('Offset X harus antara -10 dan 10 mm.');
    }
    if (media.offsetYmm < -10 || media.offsetYmm > 10) {
      errors.add('Offset Y harus antara -10 dan 10 mm.');
    }
    if (media.safeMarginMm < 0 ||
        media.safeMarginMm * 2 >= media.widthMm ||
        media.safeMarginMm * 2 >= height) {
      errors.add('Margin aman terlalu besar untuk ukuran label.');
    }
    if (!const {0, 90, 180, 270}.contains(media.rotation)) {
      errors.add('Rotasi label harus 0, 90, 180, atau 270 derajat.');
    }
    if (policy.dispatchMode == PrintDispatchMode.direct &&
        (binding == null || !binding.isEnabled) &&
        !policy.fallbackToDialog) {
      errors.add('Hubungkan printer atau aktifkan fallback dialog Windows.');
    }
    return errors;
  }

  static void ensureValid({
    required MediaPreset media,
    required PrinterProfile profile,
    required PrintPolicy policy,
    required String barcode,
    required int copies,
    PrinterBinding? binding,
  }) {
    final errors = validate(
      media: media,
      profile: profile,
      policy: policy,
      barcode: barcode,
      copies: copies,
      binding: binding,
    );
    if (errors.isNotEmpty) throw PrintValidationException(errors);
  }
}
