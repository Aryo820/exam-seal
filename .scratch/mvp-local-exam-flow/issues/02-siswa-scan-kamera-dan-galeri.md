# 02: Siswa masuk melalui kamera atau galeri

**Yang dibangun:** Siswa memindai QR guru melalui kamera atau gambar galeri dan melihat identitas sesi serta kesiapan pra-ujian berdasarkan data yang tersimpan.

**Diblokir oleh:** 01: Guru membuat dan membuka ulang sesi

**Status:** menunggu-commit

**Batas bersama:** Selesaikan dan gunakan kembali implementasi yang ada. Pertahankan desain Swiss Typographic Minimalism dan teks antarmuka, kecuali perubahan status nyata atau penjelasan yang diwajibkan spesifikasi. Android saja, tanpa backend, akun, roster, dashboard, remote unlock, timer khusus, atau penyimpanan jawaban. Gunakan dependency yang sudah terpasang dan jangan membuat alur produksi tiruan. Setiap transisi harus menjaga otorisasi dan penyimpanan; klaim proteksi mengikuti bukti pengujian.

**Kriteria penerimaan:**

- [x] Kamera dan galeri menerima QR versi baru yang sah; izin kamera ditolak tetap menyisakan jalur galeri. Pembatalan tidak menjadi pelanggaran.
- [x] QR lama, URL biasa, payload tidak lengkap, versi atau parameter verifier yang tidak didukung, gambar tanpa QR, dan kandidat QR ambigu ditolak dengan sebab yang jelas.
- [x] Validasi membatasi ukuran dan parameter payload sebelum pemrosesan verifier; data QR tidak dapat mengubah kebijakan keamanan inti.
- [x] Sesi disimpan sebelum pra-ujian dibuka; scan ganda tidak membuat sesi atau percobaan ganda.
- [x] ID sesi sama dengan URL atau verifier berbeda ditolak. Scan tidak mengganti percobaan aktif, terkunci, atau menunggu pemulihan; sesi dikenal diarahkan ke status tersimpan.
- [x] Pra-ujian menampilkan nama/kode sesi, aturan, serta hasil pemeriksaan QR, URL, dan penyimpanan; kesiapan proteksi belum terbukti tetap menahan tombol mulai.
- [x] Pengujian mencakup kedua jalur scan, pembatalan, payload tidak sah, scan ganda, konflik identitas, dan kegagalan simpan.

**Validasi 14 September 2026:** Seluruh 72 tes lulus; analyzer bersih. Tinjauan standar: 0 temuan tersisa. Tinjauan spesifikasi: 0 temuan tersisa setelah perbaikan status percobaan bersamaan dan Back selama penyimpanan.

**Batas bukti:** Kamera dan galeri diuji melalui pengganti antarmuka plugin pada tes widget; penyimpanan diuji dengan SQLite nyata, termasuk baca-saja dan buka ulang database. Pemindaian gambar/kamera, izin, dan perilaku native pada HP Android fisik belum diuji dalam tiket ini dan tetap memerlukan bukti perangkat sebelum pilot.

**Commit:** Menunggu keputusan pemisahan perubahan fondasi yang sudah ada sebelum tiket 02 dari perubahan tiket ini. Implementasi tiket 01 tersedia di workspace, tetapi status administratif tiket 01 belum ditutup.
