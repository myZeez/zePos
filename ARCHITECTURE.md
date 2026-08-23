# ZePOS Technical Architecture

## Architecture Goals

- Local-first.
- Offline-capable.
- Satu basis kode untuk desktop Windows dan Android.
- Hardware integration dapat diganti tanpa mengubah logika transaksi.
- Data transaksi konsisten dan dapat dipulihkan.

## Recommended Stack

- Flutter untuk Windows desktop dan Android.
- SQLite untuk database lokal.
- Repository pattern untuk akses data.
- Service layer untuk transaksi, stok, laporan, dan backup.
- ESC/POS adapter untuk printer thermal.
- HID keyboard input untuk barcode scanner USB.
- Bluetooth/USB adapter sesuai dukungan platform.

## Struktur Modul

```text
lib/
  main.dart                       entry point, hanya runApp
  app/
    zepos_app.dart                root widget, gerbang onboarding/login
    routing/
      zepos_shell.dart            shell utama dan state navigasi
      widgets/                    sidebar, top bar, notifikasi stok
    widgets/                      halaman loading dan error database
  features/
    auth/                         onboarding, login, kredensial lokal
    dashboard/
    checkout/                     kasir, keranjang, pembayaran
    inventory/                    stok, mutasi, penyesuaian
    products/                     katalog, editor produk, cetak label
    transactions/                 riwayat dan detail transaksi
    reports/                      laporan dan closing harian
    settings/                     profil toko, kredensial, printer
  core/
    formatting/                   formatter rupiah, tanggal, label status
    printing/                     adapter dan model printer
  data/                           schema dan akses SQLite
  domain/                         entitas Product dan StoreProfile
  services/                       export dokumen PDF/Excel
  ui/
    zepos_tokens.dart             design token
    widgets/                      widget yang dipakai lebih dari satu fitur
```

Setiap fitur berisi satu file halaman ditambah folder `widgets/` untuk bagian
penyusunnya. Widget yang dipakai lebih dari satu fitur tidak boleh disalin;
pindahkan ke `lib/ui/widgets/` agar hanya ada satu sumber kebenaran.

Belum dibuat: `app/theme/`, `app/localization/`, `features/backup/`,
`core/hardware/`, `core/security/`, dan `core/errors/`. Sementara ini tema
berada di `ui/zepos_tokens.dart`, export di `services/`, dan akses perangkat di
`core/printing/`.

## Services

- TransactionService: membuat, menyimpan, membatalkan, dan meretur transaksi.
- InventoryService: menghitung stok dan mencatat inventory movement.
- ReportService: agregasi omzet, laba, dan metode pembayaran.
- HardwareService: printer, scanner, dan cash drawer.
- BackupService: backup, restore, validasi, dan migrasi database.

## Core Entities

- Product
- Category
- Sale
- SaleItem
- Payment
- InventoryMovement
- StoreSetting
- HardwareSetting
- UserProfile
- AuditLog

## Data Rules

- Stok hanya berkurang setelah transaksi tersimpan sukses.
- SaleItem menyimpan snapshot nama dan harga produk saat transaksi.
- Pembatalan transaksi membuat log pembalikan stok.
- Penyesuaian stok wajib memiliki alasan.
- Backup harus divalidasi sebelum dianggap berhasil.
- Nomor transaksi harus unik di dalam perangkat.

## Hardware Abstraction

```text
PrinterAdapter
  connect()
  testPrint()
  printReceipt()

BarcodeAdapter
  listen()
  parseInput()

CashDrawerAdapter
  testOpen()
  openAfterSuccessfulCashSale()
```

## Local-only Constraint

Versi awal tidak melakukan sinkronisasi jaringan atau cloud. Koneksi lokal hanya digunakan untuk perangkat kasir seperti USB, Bluetooth, atau printer jaringan lokal jika kelak dibutuhkan.
