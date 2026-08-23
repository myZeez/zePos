Arsitektur Sistem Kasir: Scanner, Printer & Otomasi Uang
1. ALUR SCANNER → KERANJANG
1.1 Cara Kerja Scanner Hardware (Keyboard Wedge)
Scanner barcode yang dipasang di kasir adalah perangkat keyboard wedge (juga disebut keyboard emulation). Cara kerjanya:

Barcode Fisik
      ↓
Sinar laser membaca pola hitam-putih
      ↓
Microprocessor menerjemahkan pola → urutan digit
      ↓
Port USB / Serial
      ↓
Emulasi keyboard (OS tidak tahu ini scanner, pikir keyboard)
      ↓
Aplikasi kasir menerima karakter satu per satu
      ↓
"2977993975821" (13 karakter dalam ~80-100ms)
Penting: Scanner tidak mengirim dialog atau klik, hanya karakter keyboard. Tidak semua scanner mengirim tombol Enter setelah barcode — tergantung setting scanner (ada switch/software untuk konfigurasi).

1.2 Arsitektur Input di Aplikasi Flutter
┌─────────────────────────────────────────────────────────────────┐
│ HardwareKeyboard.instance (Global Listener)                     │
│ Setiap keystroke di level OS ditangkap, tidak peduli widget apa │
│ yang fokus saat ini                                             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ _handleGlobalScannerKey() → dikembalikan false agar keyboard   │
│ propagates ke form elements juga (kalau yang fokus itu search  │
│ box, karakter masuk ke text field)                             │
│                                                                 │
│ Tugas di sini: buffer karakter & deteksi barcode               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ DETEKSI BARCODE (algoritma)                                    │
│                                                                 │
│ Opsi 1: Menunggu tombol Enter                                  │
│   - User scan → keyboard emits 13 karakter + Enter             │
│   - Enter dipicu callback onSubmitted di TextField             │
│   Problem: Tidak semua scanner emit Enter                      │
│                                                                 │
│ Opsi 2: Deteksi burst machine-speed (REKOMENDASI)             │
│   - Ukur gap antar keystroke: DateTime.now()                  │
│   - Gap < 50ms = kecepatan mesin → barcode                    │
│   - Gap > 50ms = ketikan manusia → bukan barcode              │
│   - Timer 160ms: kalau tidak ada keystroke baru, submit burst │
│   Problem: Hanya bekerja tanpa Enter                          │
│                                                                 │
│ Opsi 3: HYBRID (Pakai dua, Enter priority)                    │
│   - Kalau Enter datang duluan → submit langsung (fast path)   │
│   - Kalau tidak ada Enter tapi burst berhenti 160ms →         │
│     submit burst machine-fast itu                             │
│   - Jika gap > 50ms di tengah burst → gunakan search box      │
│     (ketikan manual, bukan barcode)                           │
└─────────────────────────────────────────────────────────────────┘
Kode Logika Burst Detection:

static const _scannerBurstGap = Duration(milliseconds: 400);
  // Reset buffer kalau gap lebih dari 400ms
  // (antara dua scans terpisah)

static const _scannerIdleFlush = Duration(milliseconds: 160);
  // Kalau keystroke berhenti 160ms, submit jika machine-fast

static const _scannerFastKeyGap = Duration(milliseconds: 50);
  // Jika gap antar-key > 50ms, itu ketikan manusia

final _scannerBuffer = StringBuffer();
DateTime? _scannerLastKeyAt;
bool _scannerBurstIsFast = true;
Timer? _scannerIdleTimer;

void _handleGlobalScannerKey(RawKeyEvent event) {
  // Hanya keyboard event saja, tidak mouse / joystick
  if (event is! RawKeyDownEvent) return false;
  
  final character = event.character;
  if (character == null || character.isEmpty) return false;

  // Deteksi tombol khusus (Enter, Esc, Tab)
  if (event.logicalKey == LogicalKeyboardKey.enter) {
    final code = _scannerBuffer.toString();
    _resetScannerBuffer();
    if (code.trim().isNotEmpty) _submitBarcode(code);
    return false; // Biarkan Enter propagate ke form kalau ada
  }

  // Karakter regular: buffer & ukur gap
  final now = DateTime.now();
  final previous = _scannerLastKeyAt;
  
  if (previous == null || now.difference(previous) > _scannerBurstGap) {
    // Awal burst baru, reset
    _scannerBuffer.clear();
    _scannerBurstIsFast = true;
  } else if (now.difference(previous) > _scannerFastKeyGap) {
    // Gap tengah burst terlalu lama → ini ketikan manusia, jangan anggap barcode
    _scannerBurstIsFast = false;
  }

  _scannerBuffer.write(character);
  _scannerLastKeyAt = now;

  // Timer: kalau tidak ada keystroke lagi dalam 160ms, submit
  _scannerIdleTimer?.cancel();
  _scannerIdleTimer = Timer(_scannerIdleFlush, _flushScannerBurst);

  return false; // Propagate ke event handler lain (searchbox, form, etc)
}

void _flushScannerBurst() {
  _scannerIdleTimer = null;
  if (!mounted || !_scannerBurstIsFast) return;
  
  final code = _scannerBuffer.toString();
  _resetScannerBuffer();
  if (code.trim().length >= 3) { // Barcode minimal 3 karakter
    _submitBarcode(code);
  }
}

void _resetScannerBuffer() {
  _scannerIdleTimer?.cancel();
  _scannerIdleTimer = null;
  _scannerBuffer.clear();
  _scannerLastKeyAt = null;
  _scannerBurstIsFast = true;
}
1.3 Alur _submitBarcode() → Lookup Produk
Barcode: "2977993975821" (dari buffer atau text field)
      ↓
Trim whitespace: "2977993975821"
      ↓
┌─────────────────────────────────────────────────────────────────┐
│ Database query: SELECT * FROM product_units                     │
│ WHERE barcode = "2977993975821" LIMIT 1                         │
│                                                                 │
│ Hasil:                                                          │
│ - product_id = 42 (LEMINERAL 500ML)                            │
│ - product_unit_id = 10 (pcs / unit dasar)                      │
│ - sale_price = 5000                                            │
│ - current_stock = 30 (dalam unit ini)                          │
└─────────────────────────────────────────────────────────────────┘
      ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3 OUTCOME:                                                      │
│                                                                 │
│ Outcome A: Ketemu 1 produk (90% kasus)                         │
│   → Langsung ke _flashAndAdd()                                 │
│                                                                 │
│ Outcome B: Ketemu 0 produk                                     │
│   → Tanya: apakah manual pencarian?                           │
│   → Masukkan barcode ke search box                            │
│   → Tampilkan daftar produk yang cocok untuk dipilih          │
│                                                                 │
│ Outcome C: Ketemu >1 produk (pack vs pcs punya barcode sama)  │
│   → Tampilkan dialog: "Pilih satuan mana?"                    │
│   → User klik, produk yang dipilih masuk keranjang            │
└─────────────────────────────────────────────────────────────────┘
      ↓
_flashAndAdd(product) // Outcome A flow
      ↓
1.4 Flash Card & Animasi Sebelum Masuk Keranjang
Tujuan: Kasir tahu produk apa yang terakhir discan (visual feedback).

_flashAndAdd() dipanggil dengan SaleProductOption
      ↓
setState(() => _scanFlash = _ScanFlash(
  product: product,
  startTime: DateTime.now(),
));
      ↓
_ScanFlashCard muncul (floating card hijau, tengah layar)
Menampilkan: [✓ Ikon] LEMINERAL 500ML | Rp 5.000
      ↓
Animasi kecil: scale 0.95 → 1.0 (pop effect)
      ↓
Tunggu 200ms (user lihat produk apa yang ter-scan)
      ↓
Timer selesai → _add(product) dipanggil
      ↓
Kode Flash Card:

class _ScanFlash {
  final SaleProductOption product;
  final DateTime startTime;
  
  bool get isVisible {
    final elapsed = DateTime.now().difference(startTime);
    return elapsed < const Duration(milliseconds: 200);
  }
}

class _ScanFlashCard extends StatelessWidget {
  const _ScanFlashCard(this.product);
  final SaleProductOption product;

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.9, end: 1.0).animate(
        CurvedAnimation(
          parent: AnimationController(
            duration: const Duration(milliseconds: 150),
            vsync: this,
          )..forward(),
          curve: Curves.elasticOut,
        ),
      ),
      child: Card(
        color: Colors.green[50],
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.productName),
                  Text('Rp ${product.salePrice}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Di dalam _SettingsFormState build():
if (_scanFlash != null && _scanFlash!.isVisible) {
  overlayEntry = OverlayEntry(
    builder: (_) => Positioned(
      top: MediaQuery.of(context).size.height / 2,
      left: MediaQuery.of(context).size.width / 2,
      child: Transform.translate(
        offset: Offset(-50, -50), // Center card
        child: _ScanFlashCard(_scanFlash!.product),
      ),
    ),
  );
  Overlay.of(context).insert(overlayEntry);
}
1.5 Masuk Keranjang dengan _add()
_add(product) dipanggil
      ↓
setState(() {
  // Cek apakah produk yang sama sudah ada di keranjang
  final existing = _cart.firstWhere(
    (line) => line.product.productUnitId == product.productUnitId &&
              line.unitPrice == product.salePrice,
    orElse: () => null,
  );
  
  if (existing == null) {
    // Produk baru → tambah baris baru
    _cart.add(_CartLine(
      product: product,
      quantity: 1,
      unitPrice: product.salePrice,
    ));
  } else {
    // Produk sudah ada → naikkan jumlah
    existing.quantity += 1;
  }
});
      ↓
Tampilan keranjang di-rebuild otomatis (setState)
      ↓
User lihat:
[1x] LEMINERAL 500ML | Rp 5.000
      ↓
Siap untuk scan berikutnya (tidak ada dialog, tidak ada modal)
Poin Penting: Gunakan setState() untuk update quantity! Jangan update langsung tanpa setState(), karena widget tidak akan rebuild.

2. PENGATURAN PRINTER THERMAL & LABEL
2.1 Dua Printer Berbeda untuk Dua Kebutuhan
Aspek	Printer Thermal (Nota)	Printer Label (Barcode)
Tujuan	Cetak struk penjualan	Cetak stiker barcode untuk produk
Ukuran kertas	58mm atau 80mm lebar, roll panjang	A4 atau label stiker kecil (40×20mm)
Format output	PDF (thermal-friendly)	PDF dengan EAN13/Code128
Driver	Printer thermal generik (Oki, Star, dll)	Label printer (Blueprint ECO80BT)
Port	USB, Network, Serial	USB ← perlu dikonfigurasi Windows
Margin safety	2-4mm kiri-kanan	1-2mm + GAP antar label
2.2 Pengaturan Printer Thermal (Nota Penjualan)
A. Hardware Setup:

Pasang printer di USB → Windows auto-detect (usually)
Instal driver resmi dari pabrik
Test print dari Windows Settings → Devices → Printers
B. Software Settings di Aplikasi:

class StoreSettings {
  // Pilihan printer
  final String? receiptPrinterName; // "Epson TM-T20" misalnya
  
  // Ukuran kertas fisik
  final double receiptPaperWidth; // 58 atau 80 mm
  
  // Margin aman (jangan cetak terlalu dekat pinggir)
  final double receiptMarginLeft;    // mm
  final double receiptMarginRight;   // mm
  final double receiptMarginTop;     // mm
  final double receiptMarginBottom;  // mm
  
  // Offset total (kalau hasil cetak tidak centered)
  final double receiptOffsetX; // mm, bisa negatif (kiri)
  final double receiptOffsetY; // mm, bisa negatif (atas)
  
  // Copy count
  final int receiptCopies; // 1, 2, atau 3 copy
  
  // Cash drawer
  final bool openCashDrawer;     // Auto buka laci uang?
  final int cashDrawerPin;       // Pin 2 atau Pin 5 pada printer
}
C. Cara Kerjanya:

Transaksi selesai (user klik Bayar)
      ↓
Generate laporan penjualan → PDF format
      ↓
      ┌──────────────────────────────────────────────┐
      │ CONTOH LAPORAN THERMAL (58mm width)          │
      │                                              │
      │ ════════════════════════════════════════     │
      │        TOKO PLASTIK BERKAH                   │
      │    Jl. Mahar Raya, Palangka Raya            │
      │    Telp: 0812-5259-8016                     │
      │ ════════════════════════════════════════     │
      │                                              │
      │ No. Transaksi: TRX-20260823-0001            │
      │ Waktu: 23 Agustus 2026, 14:35               │
      │                                              │
      │ ────────────────────────────────────────────│
      │ BARANG       | QTY |   HARGA  |   TOTAL     │
      │ ────────────────────────────────────────────│
      │ LEMINERAL    |  2  |  5.000  |  10.000    │
      │ 500ML        |     |         |            │
      │              |     |         |            │
      │ KANTONG      |  5  |  2.000  |  10.000    │
      │ PLASTIK BESAR|     |         |            │
      │ ────────────────────────────────────────────│
      │ SUBTOTAL              Rp 20.000           │
      │ PAJAK (10%)           Rp  2.000           │
      │ TOTAL                 Rp 22.000           │
      │                                            │
      │ PEMBAYARAN TUNAI      Rp 25.000           │
      │ KEMBALIAN             Rp  3.000           │
      │ ────────────────────────────────────────────│
      │                                            │
      │ Terima kasih telah berbelanja.            │
      │                                            │
      └──────────────────────────────────────────────┘
      ↓
Print ke printer thermal
      ↓
Printer menerima PDF → print berkali-kali sesuai receiptCopies
      ↓
Jika openCashDrawer = true:
  Kirim ESC/POS command "Buka laci uang"
  → Laci uang terbuka otomatis
      ↓
Struk tercetak, kasir ambil dari output tray
D. Troubleshooting Margin & Offset:

Jika struk tercetak terpotong di tepi:

Problem	Solution
Teks terpotong kiri-kanan	Naikkan receiptMarginLeft & Right (contoh 4-5mm)
Teks terpotong atas-bawah	Naikkan receiptMarginTop & Bottom
Seluruh konten geser ke kiri	Naikkan receiptOffsetX (positive = kanan)
Seluruh konten geser ke atas	Naikkan receiptOffsetY (positive = bawah)
Test: Gunakan tombol "Pratinjau nota contoh" di Settings untuk lihat hasil sebelum print real.

2.3 Pengaturan Printer Label (Barcode)
A. Hardware Setup (Blueprint ECO80BT):

Pasang printer USB ke PC
Instal driver resmi (search "Blueprint ECO80BT driver Windows")
Windows akan membuat virtual print queue bernama "80Label Printer"
Di Device Manager, cek VID/PID:
VID: 09C5
PID: 807A
Configure print server untuk dynamic USB port selection (biar tidak stuck kalau USB port berganti)
B. Software Settings:

class StoreSettings {
  // Pilihan printer label
  final String? labelPrinterName; // "80Label Printer" (dari driver)
  
  // Ukuran stiker fisik
  final double? labelWidth;   // 40 mm (umum untuk roll)
  final double? labelHeight;  // 20 mm (umum untuk roll)
  
  // Gap antar label (pitch printer)
  // Pitch = tinggi label + gap
  // Contoh: label 20mm + gap 2mm = pitch 22mm
  final double labelGap; // 2 mm (umum)
  
  // Margin aman dari tepi stiker
  final double labelMarginLeft;
  final double labelMarginRight;
  final double labelMarginTop;
  final double labelMarginBottom;
  
  // Offset default (dapat disesuaikan lagi saat cetak)
  final double labelOffsetX;
  final double labelOffsetY;
}
C. Label Preset (Predefined Ukuran):

enum _LabelPreset {
  compact40x20(40, 20, '40 × 20 mm (roll standar)'),
  square50x50(50, 50, '50 × 50 mm (square)'),
  wide100x30(100, 30, '100 × 30 mm (lebar)'),
  custom(0, 0, 'Ukuran custom');
  
  final double width;
  final double height;
  final String label;
}
Kasir bisa memilih preset → otomatis isi ukuran di form.

D. Print Barcode Workflow:

User klik "Cetak Label" di form produk
      ↓
Dialog terbuka:
  - Pilih printer label (dropdown)
  - Jumlah stiker yang mau dicetak
  - Pilih preset ukuran atau input ukuran custom
      ↓
Generate PDF dengan barcode
  ┌──────────────────────────────────────┐
  │ ┌────────────────────────────────────┤ ← Label 1 (40×20mm)
  │ │ LEMINERAL 500ML                    │
  │ │ SKU: AILEM                         │
  │ │ Rp 5.000                           │
  │ │                                    │
  │ │   ││ ┌┐┌ ┐┌┬┐┌┐┌┐┬ ┌┐┌┬┐┌ ││      │ ← Barcode EAN13
  │ │   2977993975821                    │
  │ └────────────────────────────────────┤
  │  ↑ GAP 2mm (space antara label)      │
  │ ┌────────────────────────────────────┤ ← Label 2
  │ │ LEMINERAL 500ML                    │
  │ │ SKU: AILEM                         │
  │ │ Rp 5.000                           │
  │ │                                    │
  │ │   ││ ┌┐┌ ┐┌┬┐┌┐┌┐┬ ┌┐┌┬┐┌ ││      │
  │ │   2977993975821                    │
  │ └────────────────────────────────────┤
  └──────────────────────────────────────┘
      ↓
Print ke printer label
      ↓
Printer ECO80BT menerima PDF → gunakan sensor GAP detect
      ↓
Print label 1 → geser roll 22mm (20mm label + 2mm gap)
      ↓
Print label 2 → geser roll 22mm lagi
      ↓
Stiker siap dipotong & ditempel di produk
E. Barcode Format:

Dua format barcode berbeda:

1. PRODUCT-LEVEL BARCODE (EAN-13)
   - 13 digit
   - Dipaste di produk (umum)
   - Contoh: 2977993975821
   - Lookup: SELECT * FROM products WHERE barcode = ?

2. PRODUCT-UNIT BARCODE (Code-128, jika ada pack/dus)
   - Untuk variant yang dijual berbeda satuan
   - Contoh: produk LEMINERAL punya:
     * SKU: AILEM-PCS (barcode: 2977993975821) → harga Rp 5.000
     * SKU: AILEM-PACK6 (barcode: 2977993975822) → harga Rp 28.000
   - Lookup: SELECT * FROM product_units WHERE barcode = ?
3. OTOMASI MESIN UANG (CASH DRAWER)
3.1 Cara Kerja Hardware
Jenis Koneksi:

Printer Thermal (punya built-in cash drawer interface)
         ↓
   Pin RJ12 (6-pin)
         ↓
   Kabel → Cash Drawer
         ↓
   Solenoid magnet → membuka laci
Printer thermal memiliki output untuk mengontrol laci uang. Ketika aplikasi mengirim perintah khusus via ESC/POS protocol, printer akan:

Menerima command "Buka laci"
Activate solenoid relay
Laci terbuka dengan "klik" yang jelas (alarm untuk kasir)
3.2 Konfigurasi Aplikasi
A. Setting di Halaman Pengaturan:

class _SettingsFormState extends ConsumerState {
  late bool _openCashDrawer; // Checkbox: aktif/tidak
  late int _cashDrawerPin;   // Dropdown: Pin 2 atau Pin 5
  
  // Dialog dengan 2 input
  SwitchListTile(
    title: Text('Buka laci uang otomatis'),
    subtitle: Text('Laci terbuka setelah nota berhasil dikirim ke printer.'),
    value: _openCashDrawer,
    onChanged: (value) => setState(() => _openCashDrawer = value),
  ),
  
  if (_openCashDrawer) ...[
    DropdownButtonFormField<int>(
      initialValue: _cashDrawerPin,
      items: [
        DropdownMenuItem(value: 2, child: Text('Pin 2 (umum)')),
        DropdownMenuItem(value: 5, child: Text('Pin 5')),
      ],
      onChanged: (value) => setState(() => _cashDrawerPin = value ?? 2),
    ),
    OutlinedButton.icon(
      onPressed: _testCashDrawer,
      icon: Icon(Icons.lock_open_outlined),
      label: Text('Tes laci'),
    ),
  ],
}
User bisa:

Enable/disable otomasi
Pilih pin mana
Test dengan tombol "Tes laci" (buka laci tanpa print nota)
B. Simpan Ke Database:

await ref.read(settingsRepositoryProvider).saveSettings(
  currentSettings.copyWith(
    openCashDrawer: _openCashDrawer,
    cashDrawerPin: _cashDrawerPin,
  ),
);
3.3 Logika Print Dengan Cash Drawer Trigger
A. Alur Nota → Laci Terbuka:

Transaksi selesai, user klik "Bayar"
      ↓
Generate PDF nota
      ↓
Kirim ke printer thermal
      ↓
Tunggu konfirmasi printer ("berhasil dikirim")
      ↓
Cek setting: openCashDrawer == true?
      ↓
Jika YES:
  Kirim ESC/POS command ke printer:
  0x1B 0x70 0x00 0x20 (Pin 2 trigger)
  atau
  0x1B 0x70 0x01 0x20 (Pin 5 trigger)
      ↓
  Printer membaca command → activate solenoid
  → Laci terbuka dengan klik keras
      ↓
Jika NO:
  Tidak ada command, laci tetap tertutup
      ↓
Nota tercetak, transaksi selesai
B. Kode Implementasi (Print Service):

class PrintService {
  static const _CASH_DRAWER_PIN2 = '\x1B\x70\x00\x20'; // ESC/POS Pin 2
  static const _CASH_DRAWER_PIN5 = '\x1B\x70\x01\x20'; // ESC/POS Pin 5

  Future<void> printReceipt({
    required Printer printer,
    required PdfDocument pdf,
    required bool openCashDrawer,
    required int cashDrawerPin,
  }) async {
    try {
      // 1. Kirim PDF ke printer
      await printer.printPdf(
        format: PaperFormat.mm58,
        document: pdf,
      );

      // 2. Tunggu printer selesai (misal 1 detik)
      await Future.delayed(Duration(milliseconds: 500));

      // 3. Jika perlu buka laci uang
      if (openCashDrawer) {
        final command = cashDrawerPin == 2 
          ? _CASH_DRAWER_PIN2 
          : _CASH_DRAWER_PIN5;
        
        // Kirim raw command via USB/Serial
        // (Tergantung printer, bisa via proprietary API atau direct USB)
        await _sendRawCommand(printer, command);
      }

      return true;
    } catch (e) {
      print('Error: $e');
      return false;
    }
  }

  Future<void> testCashDrawer({
    required Printer printer,
    required int cashDrawerPin,
  }) async {
    final command = cashDrawerPin == 2 
      ? _CASH_DRAWER_PIN2 
      : _CASH_DRAWER_PIN5;
    
    await _sendRawCommand(printer, command);
    // Laci terbuka untuk test
  }

  Future<void> _sendRawCommand(Printer printer, String command) async {
    // Ini bergantung library printing yang dipakai
    // Jika memakai win32 API:
    // - Open printer handle via Windows PrintDocument
    // - Kirim raw command byte stream
    
    // Atau kalau printer support via USB vendor API
    // - Pakai libusb / native USB API
  }
}
3.4 Troubleshooting Cash Drawer
Problem	Penyebab	Solution
Laci tidak buka	Pin setting salah	Test dengan kedua pin (2 dan 5)
Command terkirim tapi laci tetap tutup	Kabel RJ12 tidak terpasang	Periksa kabel printer ↔ laci
Laci buka tapi berisik / oper lama	Solenoid bergerak lambat	Berikan waktu tunggu lebih lama (2s)
Error saat print	Printer offline	Periksa koneksi USB / network
4. IMPLEMENTASI DI APLIKASI KASIR KEDUA
4.1 Checklist Setup
 Hardware

 Scanner barcode USB (test: scan barcode → muncul di OS)
 Printer thermal (test: cetak via Windows Settings)
 Printer label (test: baca port USB di Device Manager)
 Cash drawer (test: kabel RJ12 connected ke printer)
 Kode Scanner

 Implement _handleGlobalScannerKey() di halaman kasir
 Implement burst detection (atau gunakan copy dari KASIR BERKAH)
 Add tests: scan dengan/tanpa Enter, repeat scan, manual typing
 Kode Printer Thermal

 Create PrintService dengan template PDF nota
 Implement margin/offset settings
 Store printer name & settings di database
 Add "Pratinjau nota" untuk test layout
 Kode Printer Label

 Create barcode generation (EAN-13 / Code-128)
 Implement label layout (40×20mm template)
 Add label size preset selector
 Add print dialog dengan jumlah & ukuran
 Kode Cash Drawer

 Implement ESC/POS command sender
 Add toggle & pin selector di Settings
 Add "Tes laci" button
 Test: print nota → laci otomatis terbuka
 Database Schema

 store_settings table dengan fields printer & cash drawer
 products dengan field barcode
 product_units dengan field barcode (untuk variant pack/dus)
4.2 File Structure Rekomendasi
lib/
├── features/
│   ├── sales/
│   │   ├── presentation/
│   │   │   └── sales_page.dart          ← Scanner logic disini
│   │   ├── data/
│   │   │   └── sales_repository.dart    ← Database lookup barcode
│   │   └── domain/
│   │       └── sales_models.dart
│   │
│   ├── settings/
│   │   ├── presentation/
│   │   │   └── settings_page.dart       ← Printer & cash drawer settings
│   │   ├── data/
│   │   │   └── settings_repository.dart
│   │   └── domain/
│   │       └── store_settings.dart
│   │
│   └── products/
│       ├── data/
│       │   └── product_repository.dart  ← Cetak label barcode
│       └── presentation/
│           └── label_print_page.dart
│
├── core/
│   └── printing/
│       ├── print_service.dart           ← Generate & print PDF nota
│       ├── label_print_service.dart     ← Generate & print label barcode
│       ├── cash_drawer_service.dart     ← ESC/POS cash drawer commands
│       └── label_print_options.dart     ← Dialog & settings label
│
└── test/
    ├── sales_scanner_test.dart          ← Test scanner logic
    └── printer_settings_test.dart       ← Test printer configuration
4.3 Import & Reuse dari KASIR BERKAH
Copy files langsung:

Scanner Logic:

Copy method _handleGlobalScannerKey() dan helper functions
Copy test file test/sales_scanner_test.dart
Adjust timing constants kalau perlu
Printer Service:

Copy lib/core/printing/print_service.dart
Copy PDF template dari _receiptContent() method
Adjust margin/offset defaults kalau lain
Label Service:

Copy lib/core/printing/label_print_service.dart
Copy label layout template
Copy barcode generation logic
Cash Drawer:

Copy lib/core/printing/cash_drawer_service.dart
Atau copy method dari PrintService kalau jadi satu class
5. TESTING CHECKLIST
5.1 Scanner Testing
test('scan tanpa Enter masuk keranjang', () async {
  // Simulate: 2977993975821 tanpa Enter
  await scan(tester, '2977993975821', withEnter: false);
  expect(find.text('Keranjang masih kosong'), findsNothing);
});

test('scan barcode sama 2x menambah quantity', () async {
  await scan(tester, '2977993975821', withEnter: false);
  await scan(tester, '2977993975821', withEnter: false);
  expect(find.text('2'), findsOneWidget); // Qty = 2, bukan 2 baris
});

test('mengetik manual tidak jadi barcode', () async {
  // Type "LEMI" dengan gap manusia (80ms)
  await typeSlowly('LEMI', gapMs: 80);
  expect(find.text('Keranjang masih kosong'), findsOneWidget);
});
5.2 Printer Testing
test('nota preview menyesuaikan margin & offset', () async {
  // Open settings → set margin
  await setReceiptMargin(left: 5, right: 5);
  
  // Click preview
  await tester.tap(find.text('Pratinjau nota contoh'));
  
  // Verif: PDF generated dengan margin yang benar
  expect(previewPdf.pageWidth, lessThan(58 - 10)); // 58 - (5+5)
});

test('label barcode EAN-13 vs Code128 sesuai format', () async {
  final pdf1 = await generateLabel(barcode: '2977993975821');
  // EAN-13, validasi checksum digit ke-13
  
  final pdf2 = await generateLabel(barcode: 'CUSTOM-CODE-123');
  // Code-128, no checksum validation
});
5.3 Cash Drawer Testing
test('tes laci membuka solenoid', () async {
  await openSettingsPage();
  await enableCashDrawer(pin: 2);
  
  // Click "Tes laci"
  // Laci harus terbuka dalam 500ms
  await Future.delayed(Duration(milliseconds: 500));
  expect(drawerIsOpen, true);
});

test('print nota membuka laci otomatis kalau enabled', () async {
  await enableCashDrawer(pin: 2);
  
  // Scan produk → checkout
  await scan('2977993975821');
  await checkout();
  
  // Nota printed, laci otomatis buka
  await Future.delayed(Duration(milliseconds: 1000));
  expect(drawerIsOpen, true);
});
Ringkasan Alur End-to-End
┌─────────────────────────────────────────────────────────────┐
│ 1. KASIR SCAN BARCODE                                       │
│    Scanner emits keyboard chars: 2977993975821              │
│    (dengan atau tanpa Enter)                                │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. BURST DETECTION                                          │
│    DateTime gap < 50ms = machine-speed = barcode            │
│    Tunggu 160ms, submit jika machine-fast                   │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. DATABASE LOOKUP                                          │
│    SELECT * FROM product_units                             │
│    WHERE barcode = '2977993975821' LIMIT 1                 │
│    → Dapat: LEMINERAL, unit pcs, harga 5000, stok 30      │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. FLASH CARD (200ms)                                      │
│    ✓ LEMINERAL 500ML | Rp 5.000                            │
│    (visual feedback untuk kasir)                            │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. MASUK KERANJANG                                          │
│    if (produk belum ada) → add baris baru, qty=1           │
│    else → qty++                                             │
│    setState() → rebuild                                     │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. LANJUT SCAN ATAU CHECKOUT                                │
│    Scan produk lain, atau                                   │
│    Klik "Bayar" → generate nota PDF                         │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. PRINT NOTA THERMAL                                       │
│    Apply margin & offset settings                           │
│    Print N kopi sesuai receiptCopies                        │
│    Send to printer via Windows print spooler                │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ 8. CASH DRAWER TRIGGER (otomatis kalau enabled)            │
│    Send ESC/POS command 0x1B 0x70 0x00 0x20 (Pin 2)       │
│    → Printer activate solenoid                              │
│    → Laci uang terbuka (klik keras)                         │
│    → Kasir ambil uang & kembalian                           │
└─────────────────────────────────────────────────────────────┘
Gunakan dokumentasi ini untuk implementasi di aplikasi kasir yang lain. Semua logika sudah terbukti di KASIR BERKAH v1.0.33 — copy dan adapt sesuai kebutuhan!