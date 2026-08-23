# ZePOS Product Context

## Register

product

## Users

ZePOS digunakan oleh pemilik toko, kasir, dan pengelola stok dari berbagai jenis usaha retail, warung, kafe kecil, serta UMKM.

Pengguna dapat memiliki tingkat pengalaman teknologi yang berbeda. Karena itu, alur utama harus dapat dipahami tanpa pelatihan panjang dan tetap cepat digunakan oleh kasir berpengalaman.

## Product Purpose

ZePOS adalah aplikasi kasir lokal/offline untuk mengelola transaksi, produk, stok, pembayaran, laporan, dan perangkat kasir dalam satu tempat.

Versi awal berjalan secara mandiri pada satu perangkat desktop Windows atau Android tablet/phone. Data disimpan di perangkat dan tidak disinkronkan melalui internet. Pembayaran tunai, QRIS, dan transfer dicatat secara manual; integrasi payment gateway, kartu, dan mesin EDC menjadi tahap lanjutan.

Kesuksesan produk berarti pengguna dapat melakukan transaksi dengan cepat, memahami kondisi toko dalam satu layar, dan tetap aman dari kehilangan data melalui backup lokal.

## Brand Personality

- Sederhana: istilah dan alur kerja mudah dipahami.
- Ramah: tidak membuat pengguna merasa sedang mengoperasikan sistem yang rumit.
- Sigap: respons cepat dan mendukung ritme transaksi toko.
- Modern: tampilan bersih, rounded, dan soft-neumorphic tanpa dekorasi berlebihan.

## Anti-references

ZePOS tidak boleh terlihat seperti:

- Dashboard enterprise yang penuh menu dan tabel tanpa prioritas.
- POS yang mengandalkan ikon tanpa label.
- Aplikasi dengan istilah teknis seperti master data, reconciliation, atau configuration module pada alur utama.
- Antarmuka dengan terlalu banyak warna, gradient, animasi dekoratif, atau panel bertingkat.
- Sistem online yang tidak dapat digunakan ketika internet mati.
- Neumorphism dengan kontras rendah sehingga teks dan status sulit dibaca.

## Design Principles

1. Kasir dulu: halaman Kasir adalah pusat aktivitas dan harus dapat dibuka dengan satu langkah.
2. Progressive disclosure: fitur lanjutan tersedia, tetapi tidak mengganggu pengguna pemula.
3. Status selalu jelas: stok, pembayaran, perangkat, dan mode offline memiliki indikator yang mudah dipahami.
4. Local-first: transaksi dan stok harus tetap bekerja tanpa koneksi internet.
5. Recovery by design: pembatalan, retur, backup, restore, dan error perangkat memiliki alur pemulihan yang jelas.

## Accessibility & Inclusion

- Gunakan Bahasa Indonesia sederhana.
- Pertahankan kontras teks tinggi di atas permukaan neumorphic.
- Target sentuh minimal 44×44 px.
- Jangan gunakan warna sebagai satu-satunya penanda status; sertakan label dan ikon.
- Sediakan fokus keyboard pada desktop.
- Gunakan ukuran teks minimal 14 px untuk UI utama.
- Hormati prefers-reduced-motion.
- Sediakan empty, loading, error, disabled, dan success states.

## Open Decisions

- Nama dan logo final ZePOS.
- Framework aplikasi dan strategi distribusi installer.
- Dukungan database terenkripsi.
- Format backup dan kebijakan retensi.
- Daftar printer thermal yang akan diuji secara resmi.
- Hak akses jika satu perangkat digunakan oleh lebih dari satu kasir.
