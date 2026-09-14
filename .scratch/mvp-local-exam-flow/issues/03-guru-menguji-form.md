# 03: Guru menguji Form sebelum membagikan QR

**Yang dibangun:** Guru menjalankan satu percobaan lengkap pada Form pilot melalui WebView terbatas, memeriksa pembatasan dan respons di Google Forms sebelum membagikan QR.

**Diblokir oleh:** 01: Guru membuat dan membuka ulang sesi

**Status:** implementasi-selesai-menunggu-uji-pilot-dan-commit

**Batas bersama:** Selesaikan dan gunakan kembali implementasi yang ada. Pertahankan desain Swiss Typographic Minimalism dan teks antarmuka, kecuali perubahan status nyata atau penjelasan yang diwajibkan spesifikasi. Android saja, tanpa backend, akun, roster, dashboard, remote unlock, timer khusus, atau penyimpanan jawaban. Gunakan dependency yang sudah terpasang dan jangan membuat alur produksi tiruan. Setiap transisi harus menjaga otorisasi dan penyimpanan; klaim proteksi mengikuti bukti pengujian.

**Kriteria penerimaan:**

- [x] HTTPS, host, jalur Form, dan tujuan redirect diperiksa; URL peniru dan redirect keluar ditolak pada pengujian kebijakan navigasi.
- [ ] Navigasi halaman utama dibedakan dari aset yang diperlukan Form; Form yang sama dapat dikerjakan sampai submit.
- [ ] Tautan luar, Form lain, jendela baru, intent, unduhan tidak didukung, dan pembukaan browser luar tidak memberi jalur keluar otomatis.
- [ ] Form yang memerlukan login, upload, atau layanan luar ditandai tidak sesuai pilot; alur edit respons dan kirim respons lain tidak dapat diakses siswa.
- [x] Guru mendapat alur pemeriksaan lengkap sebelum distribusi QR, termasuk larangan mengubah Form selama ujian; URL valid saja tidak dinyatakan siap.
- [ ] Uji dengan Form pilot mencatat keberhasilan submit yang diperiksa guru dan kasus navigasi ditolak; aplikasi tidak menyimpulkan submit dari status lokal.

**Implementasi 14 September 2026:** WebView terbatas dipakai bersama oleh uji guru dan ujian siswa. Konfirmasi manual tersimpan per sesi dan URL; uji ulang membatalkannya. Navigasi yang diblokir dicatat sebagai jumlah, tanpa isi jawaban. PIN diperlukan untuk menutup uji; akses PIN melalui autentikasi perangkat tersedia sebelum uji. Kegagalan konfigurasi WebView, inspeksi, dan penyimpanan menahan kelanjutan.

**Validasi:** Seluruh 82 tes Flutter lulus; analyzer bersih. Skrip pembatas dokumen lulus pemeriksaan Node dengan DOM pengganti. Tinjauan standar dan spesifikasi: 0 temuan kode tersisa setelah perbaikan retry konfigurasi dan Back selama penyimpanan.

**Batas bukti:** Kriteria yang masih kosong sudah memiliki implementasi pembatasan, tetapi membutuhkan uji Google Form sesungguhnya pada Android. `adb devices -l` tidak menemukan perangkat. URL Form khusus uji dan pemeriksaan respons oleh guru belum tersedia; belum ada bukti submit pilot. Hasil inspeksi dokumen maupun konfirmasi lokal tidak dinyatakan sebagai bukti pengiriman otomatis.

**Commit:** Belum dibuat. Perubahan tiket ini bergantung pada perubahan fondasi dan tiket sebelumnya yang belum di-commit; keputusan pemisahannya masih terbuka.

**Laporan:** [Validasi tiket 03](../../ticket03-validation/LAPORAN.md).
