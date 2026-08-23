# Mulai Uji Coba Kasir Toko Plastik Berkah

## 1. Menjalankan aplikasi

1. Ekstrak seluruh isi ZIP ke satu folder.
2. Jangan memindahkan `kasir_plx.exe` sendirian karena folder `data` dan file DLL diperlukan.
3. Jalankan `kasir_plx.exe`.
4. Jika Windows SmartScreen muncul, pilih **More info** lalu **Run anyway**. Aplikasi belum ditandatangani sertifikat distribusi.

## 2. Memuat data demo

Data demo bersifat opsional dan tidak menyentuh database lain sebelum pengguna mengonfirmasi restore.

1. Buka menu **Pengaturan**.
2. Pada bagian **Backup dan pemulihan**, pilih **Restore dari file**.
3. Pilih `data-demo\kasir_berkah_demo.sqlite`.
4. Konfirmasi **Validasi dan restore**.
5. Kembali ke Dashboard. Data demo berisi 5 produk, 2 penerimaan stok, 2 penjualan, beberapa satuan, barcode, dan dua batch HPP.

Saat restore, aplikasi membuat salinan database sebelumnya dengan suffix `.before_restore`.

## 3. Skenario uji utama

### Produk dan kemasan

1. Buka **Produk** lalu tekan **Tambah produk**.
2. Pastikan **Stok dihitung dalam** otomatis memilih `pcs`.
3. Isi harga jual per pcs, lalu tekan **Tambah Pack**.
4. Pastikan isi Pack memiliki pilihan cepat 50/100 pcs dan harga Pack dihitung otomatis.
5. Tekan **Tambah Dus**. Jika Pack berisi 100 pcs, nilai awal Dus harus menjadi 10 Pack atau 1.000 pcs.
6. Ubah harga otomatis bila toko memakai harga grosir, lalu simpan produk.
7. Barcode Pack/Dus hanya perlu diisi melalui bagian barcode opsional jika kemasan tersebut memiliki barcode sendiri.

### Barang masuk

1. Buka **Barang masuk**.
2. Cari `Kantong Kresek Hitam 28`.
3. Pilih satuan `pack`, masukkan jumlah, HPP, serta harga jual.
4. Simpan dan pastikan stok bertambah.

### Penjualan

1. Buka **Penjualan**.
2. Cari produk atau scan barcode pada `DATA_DEMO.md`.
3. Tambahkan beberapa barang dan ubah jumlah.
4. Bayar menggunakan Tunai, Transfer, dan QRIS pada transaksi terpisah.
5. Untuk Tunai, periksa perhitungan kembalian.
6. Cetak nota atau batalkan dialog cetak jika printer belum tersedia.

### Stok dan laporan

1. Buka **Stok** dan periksa stok serta pergerakan terbaru.
2. Buka **Laporan**, pilih periode yang mencakup hari ini.
3. Cocokkan pendapatan, HPP FIFO, laba, margin, dan metode pembayaran.
4. Coba tombol **Cetak laporan**.

### Label

1. Buka **Produk**, lalu detail produk.
2. Pada bagian satuan dan konversi, tekan ikon printer pada satuan yang mempunyai barcode.
3. Pilih printer Windows atau batalkan jika belum ada perangkat.

### Backup

1. Di **Pengaturan**, pilih folder backup.
2. Tekan **Buat backup sekarang**.
3. Pastikan file `kasir_berkah_backup_*.sqlite` muncul di folder tersebut.

## 4. Reset data uji

Restore kembali file `data-demo\kasir_berkah_demo.sqlite` untuk mengembalikan data ke kondisi demo awal.

Database aplikasi tersimpan di:

```text
%APPDATA%\Toko Plastik Berkah\Kasir Toko Plastik Berkah\data\kasir_berkah.sqlite
```

Jangan menghapus database produksi tanpa backup.
