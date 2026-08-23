# ZePOS

ZePOS adalah aplikasi POS lokal/offline yang dirancang agar kasir dapat bekerja cepat tanpa dibebani terlalu banyak menu.

## Dokumentasi

- [Product Context](PRODUCT.md)
- [Project Scope](PROJECT_SCOPE.md)
- [Design System](DESIGN.md)
- [Technical Architecture](ARCHITECTURE.md)
- [Product Roadmap](ROADMAP.md)
- [Google Stitch UI Prompt](UI_PROMPTS.md)

## Status

Tahap saat ini: fondasi aplikasi Flutter Windows/Android, Kasir, dan database SQLite lokal.

Target MVP: transaksi lokal, produk, stok, laporan, backup/restore, serta integrasi printer, barcode scanner, dan cash drawer.

## Implementasi Saat Ini

- Katalog produk awal tersimpan dalam SQLite lokal.
- Produk dapat ditambah, diubah, diaktifkan/nonaktifkan, dan dihapus bila belum memiliki riwayat stok atau transaksi.
- Transaksi membuat catatan penjualan, pembayaran, detail item, dan mutasi stok.
- Stok berkurang hanya setelah seluruh transaksi berhasil disimpan.
- Transaksi dengan stok kurang ditolak tanpa mengubah data.

## Copyright

Copyright © 2026 zeez3.o by Budi Aulyansyah Ahmad Trisna.
