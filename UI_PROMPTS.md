# ZePOS Google Stitch Prompt

Gunakan prompt berikut untuk membuat prototype multi-screen di Google Stitch. Prompt ini menggabungkan design system, responsive layout, navigasi, dan seluruh halaman utama ZePOS.

## Master Prompt

```text
Buat desain lengkap multi-screen untuk aplikasi POS bernama “ZePOS”.

ZePOS adalah aplikasi kasir lokal/offline untuk toko retail, warung, kafe kecil, dan UMKM. Aplikasi berjalan pada Windows desktop, Android tablet, dan Android phone. Semua data disimpan secara lokal di perangkat. Tidak ada cloud sync pada versi awal.

Gunakan Bahasa Indonesia untuk seluruh teks UI.

Gunakan gaya modern soft-neumorphism: rounded, lembut, nyaman, profesional, tetapi tetap mudah dibaca. Gunakan background #EEF2F7, text #172033, muted text #5D6B82, primary blue #3B82F6, success #22C55E, warning #F59E0B, danger #EF4444. Gunakan Inter atau system sans-serif.

Gunakan raised shadow lembut pada panel dan tombol serta inset shadow pada state pressed dan selected. Jangan gunakan gradient, glassmorphism, dekorasi berlebihan, atau radius lebih dari 24 px. Gunakan flat surfaces untuk tabel padat. Pastikan kontras teks tinggi dan touch target minimal 44×44 px.

Desktop: sidebar 240 px, top bar 64 px, content padding 32 px.
Tablet: sidebar dapat collapse menjadi 80 px, content padding 24 px.
Phone: bottom navigation, content padding 16 px, bottom sheet untuk keranjang dan pembayaran.

Navigasi desktop: Beranda, Kasir, Produk, Stok, Laporan, Transaksi, Pengaturan.
Navigasi phone: Kasir, Produk, Laporan, Lainnya.

Buat halaman berikut:

1. Onboarding:
Profil toko, jenis usaha, koneksi printer/barcode scanner/cash drawer, dan halaman selesai.

2. Beranda:
Metrik penjualan hari ini, jumlah transaksi, produk terjual, stok menipis, grafik omzet 7 hari, aksi cepat, produk paling laku, dan stok menipis.

3. Kasir:
Search atau scan barcode, kategori produk, product grid, keranjang, jumlah item, diskon, subtotal, total, dan tombol Bayar.

4. Pembayaran:
Metode Tunai, QRIS, dan Transfer. Tunai harus menghitung kembalian. QRIS dan transfer hanya dicatat manual dengan checkbox pembayaran diterima.

5. Transaksi berhasil:
Ringkasan pembayaran, kembalian, preview struk, Cetak Struk, Simpan PDF, dan Transaksi Baru.

6. Transaksi:
Riwayat transaksi dengan pencarian, filter tanggal, metode pembayaran, status, detail, cetak ulang, batal, dan retur.

7. Produk:
Daftar produk, SKU, barcode, kategori, harga jual, stok, status, tambah, edit, duplikat, nonaktifkan, hapus, dan import CSV.

8. Tambah/Edit Produk:
Nama, SKU, barcode, kategori, satuan, foto, harga beli, harga jual, margin, stok awal, stok minimum, dan status aktif.

9. Stok:
Ringkasan stok aman, stok menipis, stok habis, daftar produk, filter, tambah stok, sesuaikan stok, dan riwayat perubahan.

10. Penyesuaian Stok:
Pilih produk, stok sebelum, jenis perubahan, jumlah, stok sesudah, alasan, catatan, dan konfirmasi.

11. Laporan:
Omzet, laba kotor, jumlah transaksi, rata-rata transaksi, grafik omzet, metode pembayaran, produk terlaris, dan insight sederhana.

12. Pengaturan:
Profil toko, struk, perangkat, pembayaran, PIN, backup/restore, tampilan, dan tentang ZePOS.

13. Perangkat:
Printer thermal ESC/POS, barcode scanner USB/Bluetooth, dan cash drawer melalui printer RJ11/RJ12. Sertakan tombol Tes Cetak, Tes Scan, dan Tes Buka Laci.

14. Backup dan Restore:
Backup sekarang, restore dari file, backup otomatis, lokasi penyimpanan, histori backup, dan dialog konfirmasi.

Setiap halaman harus memiliki normal state, empty state, loading state, error state, disabled state, success state, dan offline state. Gunakan Bahasa Indonesia yang sederhana. Buat desain terlihat konsisten, modern, rounded, cepat, ramah pemula, dan cocok digunakan setiap hari oleh kasir.
```
