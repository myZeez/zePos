import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Sends an unmodified byte stream to a Windows printer queue.
///
/// The queue is used only as a USB transport. The printer firmware interprets
/// the bytes directly, so the Windows driver's paper size and alignment rules
/// are bypassed. This is what makes a control code such as the cash-drawer
/// kick pulse reach the hardware instead of being rendered as a page.
abstract final class RawPrinterService {
  static bool get isSupported => Platform.isWindows;

  static bool send({
    required String printerName,
    required String documentName,
    required Uint8List bytes,
  }) {
    if (!isSupported || printerName.trim().isEmpty || bytes.isEmpty) {
      return false;
    }

    final library = ffi.DynamicLibrary.open('winspool.drv');
    final openPrinter = library
        .lookupFunction<
          ffi.Int32 Function(
            ffi.Pointer<Utf16>,
            ffi.Pointer<ffi.Pointer<ffi.Void>>,
            ffi.Pointer<ffi.Void>,
          ),
          int Function(
            ffi.Pointer<Utf16>,
            ffi.Pointer<ffi.Pointer<ffi.Void>>,
            ffi.Pointer<ffi.Void>,
          )
        >('OpenPrinterW');
    final startDoc = library
        .lookupFunction<
          ffi.Uint32 Function(
            ffi.Pointer<ffi.Void>,
            ffi.Uint32,
            ffi.Pointer<_DocInfo1>,
          ),
          int Function(ffi.Pointer<ffi.Void>, int, ffi.Pointer<_DocInfo1>)
        >('StartDocPrinterW');
    final startPage = library
        .lookupFunction<
          ffi.Int32 Function(ffi.Pointer<ffi.Void>),
          int Function(ffi.Pointer<ffi.Void>)
        >('StartPagePrinter');
    final writePrinter = library
        .lookupFunction<
          ffi.Int32 Function(
            ffi.Pointer<ffi.Void>,
            ffi.Pointer<ffi.Uint8>,
            ffi.Uint32,
            ffi.Pointer<ffi.Uint32>,
          ),
          int Function(
            ffi.Pointer<ffi.Void>,
            ffi.Pointer<ffi.Uint8>,
            int,
            ffi.Pointer<ffi.Uint32>,
          )
        >('WritePrinter');
    final endPage = library
        .lookupFunction<
          ffi.Int32 Function(ffi.Pointer<ffi.Void>),
          int Function(ffi.Pointer<ffi.Void>)
        >('EndPagePrinter');
    final endDoc = library
        .lookupFunction<
          ffi.Int32 Function(ffi.Pointer<ffi.Void>),
          int Function(ffi.Pointer<ffi.Void>)
        >('EndDocPrinter');
    final closePrinter = library
        .lookupFunction<
          ffi.Int32 Function(ffi.Pointer<ffi.Void>),
          int Function(ffi.Pointer<ffi.Void>)
        >('ClosePrinter');

    final name = printerName.trim().toNativeUtf16();
    final handle = calloc<ffi.Pointer<ffi.Void>>();
    final doc = calloc<_DocInfo1>();
    final docName = documentName.toNativeUtf16();
    final dataType = 'RAW'.toNativeUtf16();
    final data = calloc<ffi.Uint8>(bytes.length);
    final written = calloc<ffi.Uint32>();
    var opened = false;
    var documentStarted = false;
    var pageStarted = false;
    try {
      if (openPrinter(name, handle, ffi.nullptr) == 0) return false;
      opened = true;
      doc.ref
        ..pDocName = docName
        ..pOutputFile = ffi.nullptr
        ..pDatatype = dataType;
      if (startDoc(handle.value, 1, doc) == 0) return false;
      documentStarted = true;
      if (startPage(handle.value) == 0) return false;
      pageStarted = true;
      data.asTypedList(bytes.length).setAll(0, bytes);
      return writePrinter(handle.value, data, bytes.length, written) != 0 &&
          written.value == bytes.length;
    } finally {
      // Every handle and buffer is released even when a step above returned
      // early; a leaked printer handle keeps the USB queue busy.
      if (pageStarted) endPage(handle.value);
      if (documentStarted) endDoc(handle.value);
      if (opened) closePrinter(handle.value);
      calloc.free(written);
      calloc.free(data);
      calloc.free(dataType);
      calloc.free(docName);
      calloc.free(doc);
      calloc.free(handle);
      calloc.free(name);
    }
  }
}

final class _DocInfo1 extends ffi.Struct {
  external ffi.Pointer<Utf16> pDocName;
  external ffi.Pointer<Utf16> pOutputFile;
  external ffi.Pointer<Utf16> pDatatype;
}
