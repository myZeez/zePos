# Asumsi dan Keputusan Sementara

Dokumen ini mencatat keputusan yang diperlukan agar fondasi dapat dibangun tanpa memperluas scope MVP.

| Item | Keputusan sementara | Dampak / tindak lanjut |
|---|---|---|
| Strategi HPP | HPP disimpan per batch dan stok dialokasikan FIFO. | `stock_batches` dan `sale_item_batches` menyimpan jejak biaya historis. Konfirmasi kembali sebelum alur barang masuk difinalkan. |
| Identitas toko | Nama, alamat, dan telepon diambil dari profil Google Maps yang diberikan client pada 29 Juli 2026. | Data awal dapat diubah melalui Pengaturan ketika modul tersebut dibuat. |
| Logo | Belum ada aset logo resmi. | UI memakai monogram `B` sementara. Ganti setelah file logo diterima. |
| Printer nota | Merek/tipe belum dikonfirmasi; default schema 58 mm. | Implementasi driver dan hasil cetak menunggu perangkat target. |
| Printer label | Merek/tipe serta ukuran label belum dikonfirmasi. | Belum ada keputusan driver atau ukuran default. |
| Ekspor laporan | Excel/PDF ditunda. | Tetap di luar pekerjaan awal sampai disetujui sebagai bagian MVP. |
| Folder backup | Belum dikonfirmasi. | Pengguna akan memilih folder saat fitur backup dibuat. |
| Satuan awal | `pcs`, `pack`, `dus`, `roll`, dan `meter` disediakan sebagai seed. | Satuan custom tetap dapat ditambahkan pada modul master data. |
| Pengguna | Satu profil kasir lokal bernama `Kasir`; tanpa login kompleks. | Sesuai batas single-PC dan out-of-scope multi-user kompleks. |

Perubahan pada keputusan yang memengaruhi schema, transaksi, laporan, atau printer harus dicatat sebagai change request sesuai `PROJECT_SCOPE.md`.
