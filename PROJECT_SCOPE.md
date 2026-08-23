# ZePOS Project Scope

## Ringkasan

ZePOS adalah aplikasi POS lokal untuk transaksi retail, manajemen produk, stok, laporan, dan integrasi perangkat kasir. Target platform adalah desktop Windows dan Android tablet/phone.

## In Scope — MVP

### Transaksi

- Scan barcode dan pencarian produk.
- Keranjang belanja.
- Ubah jumlah, hapus item, dan diskon sederhana.
- Pembayaran tunai, QRIS, dan transfer sebagai pencatatan manual.
- Perhitungan kembalian.
- Nomor transaksi otomatis.
- Simpan, batalkan, retur sederhana, dan cetak ulang transaksi.

### Produk

- Nama produk, SKU, barcode, kategori, satuan.
- Harga beli dan harga jual.
- Stok minimum.
- Status aktif/nonaktif.
- Import produk melalui CSV.

### Stok

- Pengurangan stok otomatis setelah transaksi berhasil.
- Penambahan stok.
- Penyesuaian stok.
- Stok opname sederhana.
- Peringatan stok menipis dan stok habis.
- Riwayat perubahan stok.

### Laporan

- Penjualan hari ini.
- Penjualan berdasarkan periode.
- Total transaksi.
- Breakdown metode pembayaran.
- Produk paling laku.
- Omzet dan estimasi laba kotor.
- Ekspor CSV/PDF.

### Perangkat

- Barcode scanner USB HID.
- Printer thermal ESC/POS.
- Printer USB/Bluetooth.
- Cash drawer melalui printer RJ11/RJ12.
- Tes cetak dan tes buka laci.

### Data dan keamanan

- Database lokal.
- Backup manual.
- Restore database.
- Backup otomatis opsional.
- PIN admin opsional.
- Log pembatalan transaksi dan penyesuaian stok.

## Out of Scope — MVP

- Sinkronisasi antarperangkat.
- Multi-cabang.
- Cloud dashboard.
- Login online.
- Payment gateway.
- Verifikasi QRIS otomatis.
- Integrasi transfer otomatis.
- Integrasi kartu dan mesin EDC/mini ATM.
- Akuntansi penuh.
- Payroll dan CRM.

## Platform Behavior

### Desktop Windows

- Sidebar penuh.
- Keyboard shortcut untuk pencarian, pembayaran, dan transaksi baru.
- Prioritas koneksi printer USB dan barcode scanner USB.

### Android tablet

- Dua kolom pada landscape.
- Sidebar dapat diperkecil.
- Dukungan Bluetooth/USB OTG sesuai perangkat.

### Android phone

- Bottom navigation.
- Keranjang dan pembayaran menggunakan bottom sheet.
- Scan kamera sebagai alternatif scanner.

## Acceptance Criteria MVP

- Pengguna baru dapat membuat transaksi tanpa tutorial panjang.
- Transaksi umum dapat selesai dalam waktu kurang dari 30 detik.
- Produk dapat ditemukan melalui barcode atau pencarian nama.
- Stok berkurang hanya setelah transaksi berhasil disimpan.
- Cash drawer tidak terbuka sebelum pembayaran tunai berhasil.
- Transaksi tetap dapat dilakukan tanpa internet.
- Pengguna dapat membuat backup dan melakukan restore secara lokal.
- Printer dan cash drawer memiliki tombol tes koneksi.
- Laporan omzet harian dapat dipahami tanpa membaca dokumentasi teknis.

## Risks

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Data lokal rusak atau hilang | Tinggi | Backup otomatis, restore, validasi database |
| Kompatibilitas printer berbeda-beda | Tinggi | Adapter ESC/POS, daftar perangkat teruji, tes perangkat |
| Neumorphism mengurangi kontras | Sedang | Warna teks gelap, status memakai label + ikon, tabel dibuat flat |
| Android memiliki keterbatasan USB/Bluetooth | Sedang | Mulai dari scanner HID dan printer Bluetooth yang teruji |
| Scope pembayaran terlalu cepat melebar | Tinggi | Pembayaran awal hanya pencatatan manual |
