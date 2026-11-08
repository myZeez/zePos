// Alat penjual untuk membuat kunci aktivasi ZePOS. BUKAN bagian dari aplikasi.
//
//   dart run tool/license_tool.dart init
//   dart run tool/license_tool.dart issue KODE-PERANGKAT "Nama pembeli"
//   dart run tool/license_tool.dart list
//
// Kunci privat dan buku catatan disimpan di luar folder proyek (lihat
// _defaultDirectory). Kunci privat adalah satu-satunya hal yang dapat membuat
// kunci aktivasi: jangan dibagikan, jangan di-commit, dan simpan salinannya.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:zepos/core/licensing/license_codec.dart';

const _defaultDirectory = r'D:\PROJECT';
const _privateKeyName = 'zepos-license-private.key';
const _ledgerName = 'zepos-license-ledger.csv';

String get _directory =>
    Platform.environment['ZEPOS_LICENSE_DIR'] ?? _defaultDirectory;
File get _privateKeyFile =>
    File('$_directory${Platform.pathSeparator}$_privateKeyName');
File get _publicKeyFile => File('${_privateKeyFile.path}.pub');
File get _ledgerFile =>
    File('$_directory${Platform.pathSeparator}$_ledgerName');

void main(List<String> args) {
  if (args.isEmpty) return _usage();
  switch (args.first) {
    case 'init':
      _init();
    case 'issue':
      if (args.length < 2) return _usage();
      _issue(args[1], args.skip(2).join(' ').trim());
    case 'list':
      _list();
    default:
      _usage();
  }
}

void _usage() {
  stdout.writeln('''
Pemakaian:
  dart run tool/license_tool.dart init
      Membuat pasangan kunci. Cukup SEKALI seumur produk.
  dart run tool/license_tool.dart issue KODE-PERANGKAT "Nama pembeli"
      Membuat kunci aktivasi untuk satu perangkat.
  dart run tool/license_tool.dart list
      Menampilkan buku catatan kunci yang sudah dibuat.

Folder kunci: $_directory (ubah dengan variabel ZEPOS_LICENSE_DIR)''');
  exitCode = 64;
}

void _init() {
  if (_privateKeyFile.existsSync()) {
    stderr.writeln(
      'Kunci privat sudah ada di ${_privateKeyFile.path}. Tidak ditimpa: '
      'menimpanya membuat semua kunci yang pernah dijual tidak berlaku lagi.',
    );
    exitCode = 1;
    return;
  }
  final pair = ed.generateKey();
  _privateKeyFile.parent.createSync(recursive: true);
  _privateKeyFile.writeAsStringSync(base64.encode(pair.privateKey.bytes));
  _publicKeyFile.writeAsStringSync(base64.encode(pair.publicKey.bytes));
  stdout.writeln('Kunci privat dibuat: ${_privateKeyFile.path}');
  stdout.writeln('Kunci publik        : ${_publicKeyFile.path}');
  stdout.writeln('');
  stdout.writeln(
    'SIMPAN SALINAN kunci privat di tempat aman di luar komputer ini.',
  );
  stdout.writeln(
    'Bila hilang, kunci untuk pembeli baru tidak bisa dibuat lagi.',
  );
}

Uint8List _readPrivateKey() {
  if (!_privateKeyFile.existsSync()) {
    stderr.writeln(
      'Kunci privat belum ada. Jalankan: dart run tool/license_tool.dart init',
    );
    exit(1);
  }
  return Uint8List.fromList(
    base64.decode(_privateKeyFile.readAsStringSync().trim()),
  );
}

void _issue(String code, String buyer) {
  if (!LicenseCodec.isDeviceCode(code)) {
    stderr.writeln(
      'Kode perangkat tidak valid: "$code". Harus 16 huruf/angka, '
      'contoh ABCD-EFGH-IJKL-MNOP, persis seperti tampil di layar aplikasi.',
    );
    exitCode = 1;
    return;
  }
  final normalized = LicenseCodec.normalizeCode(code);
  final key = LicenseCodec.issueKey(
    privateKey: _readPrivateKey(),
    deviceCode: normalized,
  );

  final previous = _ledgerRows().where((row) => row[1] == normalized).toList();
  if (previous.isNotEmpty) {
    stdout.writeln(
      'Perhatian: kode ini sudah pernah dibuatkan kunci pada ${previous.first[0]} '
      '(${previous.first[2]}). Kuncinya sama persis, jadi aman diberikan ulang '
      'bila pembeli memasang ulang di perangkat yang sama.',
    );
  } else {
    _ledgerFile.writeAsStringSync(
      '${DateTime.now().toIso8601String().substring(0, 10)},$normalized,'
      '${buyer.replaceAll(',', ' ')}\n',
      mode: FileMode.append,
    );
  }
  stdout.writeln('');
  stdout.writeln(
    'Kunci aktivasi untuk ${LicenseCodec.formatCode(normalized)}:',
  );
  stdout.writeln('');
  stdout.writeln(key);
}

List<List<String>> _ledgerRows() {
  if (!_ledgerFile.existsSync()) return const [];
  return [
    for (final line in _ledgerFile.readAsLinesSync())
      if (line.trim().isNotEmpty) line.split(','),
  ];
}

void _list() {
  final rows = _ledgerRows();
  if (rows.isEmpty) {
    stdout.writeln('Belum ada kunci yang dibuat.');
    return;
  }
  for (final row in rows) {
    stdout.writeln('${row[0]}  ${row[1]}  ${row.length > 2 ? row[2] : ''}');
  }
  stdout.writeln('\nTotal: ${rows.length}');
}
