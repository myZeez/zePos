enum PrintPurpose { receipt, label, report }

enum PrintDispatchMode { direct, systemDialog, askEachTime }

enum PrintJobState {
  created,
  rendering,
  ready,
  dispatching,
  acceptedToSpooler,
  completed,
  failedBeforeSpool,
  attentionRequired,
  cancelled,
}

class PrinterProfile {
  const PrinterProfile({
    required this.id,
    required this.displayName,
    required this.kind,
    required this.maxWidthMm,
    required this.dpi,
    required this.defaultDispatchMode,
    required this.defaultMedia,
    this.vendor = 'Generic',
    this.model = '',
    this.supportsPdf = true,
    this.supportsRaw = false,
    this.rawLanguage = 'none',
    this.supportsCashDrawer = false,
    this.preferredQueueName,
  });

  final String id;
  final String displayName;
  final String vendor;
  final String model;
  final PrintPurpose kind;
  final double maxWidthMm;
  final int dpi;
  final bool supportsPdf;
  final bool supportsRaw;
  final String rawLanguage;
  final bool supportsCashDrawer;
  final String? preferredQueueName;
  final PrintDispatchMode defaultDispatchMode;
  final MediaPreset defaultMedia;
}

class MediaPreset {
  const MediaPreset({
    required this.id,
    required this.purpose,
    required this.name,
    required this.widthMm,
    this.heightMm,
    this.gapMm = 0,
    this.columns = 1,
    this.rotation = 0,
    this.safeMarginMm = 0,
    this.offsetXmm = 0,
    this.offsetYmm = 0,
    this.sensorMode = 'continuous',
  });

  final String id;
  final PrintPurpose purpose;
  final String name;
  final double widthMm;
  final double? heightMm;
  final double gapMm;
  final int columns;
  final int rotation;
  final double safeMarginMm;
  final double offsetXmm;
  final double offsetYmm;
  final String sensorMode;

  double? get pitchHeightMm => heightMm == null ? null : heightMm! + gapMm;

  factory MediaPreset.fromDatabase(Map<String, Object?> values) => MediaPreset(
    id: values['id']! as String,
    purpose: PrintPurpose.values.byName(values['purpose']! as String),
    name: values['name']! as String,
    widthMm: (values['width_mm']! as num).toDouble(),
    heightMm: (values['height_mm'] as num?)?.toDouble(),
    gapMm: (values['gap_mm']! as num).toDouble(),
    columns: values['columns_count']! as int,
    rotation: values['rotation']! as int,
    safeMarginMm: (values['safe_margin_mm']! as num).toDouble(),
    offsetXmm: (values['offset_x_mm']! as num).toDouble(),
    offsetYmm: (values['offset_y_mm']! as num).toDouble(),
    sensorMode: values['sensor_mode']! as String,
  );

  Map<String, Object?> toDatabase() => {
    'id': id,
    'purpose': purpose.name,
    'name': name,
    'width_mm': widthMm,
    'height_mm': heightMm,
    'gap_mm': gapMm,
    'columns_count': columns,
    'rotation': rotation,
    'safe_margin_mm': safeMarginMm,
    'offset_x_mm': offsetXmm,
    'offset_y_mm': offsetYmm,
    'sensor_mode': sensorMode,
  };
}

class PrinterBinding {
  const PrinterBinding({
    required this.id,
    required this.purpose,
    required this.profileId,
    required this.printerUrl,
    required this.printerName,
    required this.updatedAt,
    this.printerModel,
    this.isEnabled = true,
  });

  final String id;
  final PrintPurpose purpose;
  final String profileId;
  final String printerUrl;
  final String printerName;
  final String? printerModel;
  final bool isEnabled;
  final DateTime updatedAt;

  factory PrinterBinding.fromDatabase(Map<String, Object?> values) =>
      PrinterBinding(
        id: values['id']! as String,
        purpose: PrintPurpose.values.byName(values['purpose']! as String),
        profileId: values['profile_id']! as String,
        printerUrl: values['printer_url']! as String,
        printerName: values['printer_name']! as String,
        printerModel: values['printer_model'] as String?,
        isEnabled: values['is_enabled']! as int == 1,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          values['updated_at']! as int,
        ),
      );

  Map<String, Object?> toDatabase() => {
    'id': id,
    'purpose': purpose.name,
    'profile_id': profileId,
    'printer_url': printerUrl,
    'printer_name': printerName,
    'printer_model': printerModel,
    'is_enabled': isEnabled ? 1 : 0,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };
}

class PrintPolicy {
  const PrintPolicy({
    required this.purpose,
    this.dispatchMode = PrintDispatchMode.systemDialog,
    this.copies = 1,
    this.fallbackToDialog = true,
    this.usePrinterSettings = false,
    this.openCashDrawer = false,
    this.cashDrawerPin = 2,
  });

  final PrintPurpose purpose;
  final PrintDispatchMode dispatchMode;
  final int copies;
  final bool fallbackToDialog;
  final bool usePrinterSettings;
  final bool openCashDrawer;

  /// Connector pin the drawer solenoid is wired to. Pin 2 covers most
  /// drawers; a few two-drawer tills put the second one on pin 5.
  final int cashDrawerPin;

  factory PrintPolicy.fromDatabase(Map<String, Object?> values) => PrintPolicy(
    purpose: PrintPurpose.values.byName(values['purpose']! as String),
    dispatchMode: PrintDispatchMode.values.byName(
      values['dispatch_mode']! as String,
    ),
    copies: values['copies']! as int,
    fallbackToDialog: values['fallback_to_dialog']! as int == 1,
    usePrinterSettings: values['use_printer_settings']! as int == 1,
    openCashDrawer: values['open_cash_drawer']! as int == 1,
    cashDrawerPin: values['cash_drawer_pin'] as int? ?? 2,
  );

  Map<String, Object?> toDatabase() => {
    'purpose': purpose.name,
    'dispatch_mode': dispatchMode.name,
    'copies': copies,
    'fallback_to_dialog': fallbackToDialog ? 1 : 0,
    'use_printer_settings': usePrinterSettings ? 1 : 0,
    'open_cash_drawer': openCashDrawer ? 1 : 0,
    'cash_drawer_pin': cashDrawerPin,
  };
}

class PrintJobResult {
  const PrintJobResult({
    required this.jobId,
    required this.state,
    required this.userMessage,
    this.errorCode,
    this.retrySafe = false,
    this.artifactPath,
    this.correlationId,
  });

  final String jobId;
  final PrintJobState state;
  final String userMessage;
  final String? errorCode;
  final bool retrySafe;
  final String? artifactPath;
  final String? correlationId;

  bool get accepted => state == PrintJobState.acceptedToSpooler;

  bool get mayHavePrinted =>
      state == PrintJobState.acceptedToSpooler ||
      state == PrintJobState.completed ||
      state == PrintJobState.attentionRequired;
}

class PrintPurposeConfiguration {
  const PrintPurposeConfiguration({
    required this.profile,
    required this.media,
    required this.policy,
    this.binding,
  });

  final PrinterProfile profile;
  final MediaPreset media;
  final PrintPolicy policy;
  final PrinterBinding? binding;
}

abstract final class BuiltInPrinterProfiles {
  static const genericReceipt = PrinterProfile(
    id: 'generic-thermal-receipt-windows',
    displayName: 'Thermal Nota Universal 58/80 mm',
    kind: PrintPurpose.receipt,
    maxWidthMm: 80,
    dpi: 203,
    supportsRaw: true,
    rawLanguage: 'escpos',
    supportsCashDrawer: true,
    defaultDispatchMode: PrintDispatchMode.systemDialog,
    defaultMedia: receipt80,
  );

  static const genericLabel = PrinterProfile(
    id: 'generic-label-windows',
    displayName: 'Printer Label Universal 203 dpi',
    kind: PrintPurpose.label,
    maxWidthMm: 110,
    dpi: 203,
    supportsRaw: true,
    rawLanguage: 'tspl',
    defaultDispatchMode: PrintDispatchMode.systemDialog,
    defaultMedia: label40x20,
  );

  static const blueprintEco80bt = PrinterProfile(
    id: 'blueprint-eco80bt-windows',
    displayName: 'Blueprint ECO80BT',
    vendor: 'Blueprint',
    model: 'ECO80BT',
    kind: PrintPurpose.label,
    maxWidthMm: 110,
    dpi: 203,
    preferredQueueName: '80Label Printer',
    supportsRaw: true,
    rawLanguage: 'tspl',
    defaultDispatchMode: PrintDispatchMode.systemDialog,
    defaultMedia: label40x20,
  );

  static const genericDocument = PrinterProfile(
    id: 'generic-document-windows',
    displayName: 'Printer Dokumen Universal',
    kind: PrintPurpose.report,
    maxWidthMm: 216,
    dpi: 300,
    defaultDispatchMode: PrintDispatchMode.systemDialog,
    defaultMedia: reportA4,
  );

  static const receipt58 = MediaPreset(
    id: 'receipt-58',
    purpose: PrintPurpose.receipt,
    name: 'Thermal 58 mm',
    widthMm: 58,
    safeMarginMm: 2.5,
  );

  static const receipt80 = MediaPreset(
    id: 'receipt-80',
    purpose: PrintPurpose.receipt,
    name: 'Thermal 80 mm',
    widthMm: 80,
    safeMarginMm: 3,
  );

  static const label40x20 = MediaPreset(
    id: 'label-40x20-gap2',
    purpose: PrintPurpose.label,
    name: 'Label 40 × 20 mm · GAP 2 mm',
    widthMm: 40,
    heightMm: 20,
    gapMm: 2,
    safeMarginMm: 1.5,
    sensorMode: 'gap',
  );

  static const label62x38 = MediaPreset(
    id: 'label-62x38',
    purpose: PrintPurpose.label,
    name: 'Label 62 × 38 mm',
    widthMm: 62,
    heightMm: 38,
    safeMarginMm: 3,
    sensorMode: 'gap',
  );

  static const reportA4 = MediaPreset(
    id: 'report-a4',
    purpose: PrintPurpose.report,
    name: 'Dokumen A4',
    widthMm: 210,
    heightMm: 297,
    safeMarginMm: 12,
  );

  static const profiles = [
    genericReceipt,
    genericLabel,
    blueprintEco80bt,
    genericDocument,
  ];

  static const mediaPresets = [
    receipt58,
    receipt80,
    label40x20,
    label62x38,
    reportA4,
  ];

  static List<PrinterProfile> forPurpose(PrintPurpose purpose) =>
      profiles.where((profile) => profile.kind == purpose).toList();

  static PrinterProfile byId(String id) => profiles.firstWhere(
    (profile) => profile.id == id,
    orElse: () => genericReceipt,
  );
}
