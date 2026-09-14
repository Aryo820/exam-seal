# 08: Buka ulang aplikasi memulihkan pengamanan

**Yang dibangun:** Aplikasi membaca pengamanan tersimpan sebelum membuka layar umum atau soal, lalu meminta keputusan pengawas untuk pemulihan setelah proses mati.

**Diblokir oleh:** 07: Pengawas melanjutkan sesi terkunci atau mengizinkan pengulangan

**Status:** ready-for-agent

**Batas bersama:** Selesaikan dan gunakan kembali implementasi yang ada. Pertahankan desain Swiss Typographic Minimalism dan teks antarmuka, kecuali perubahan status nyata atau penjelasan yang diwajibkan spesifikasi. Android saja, tanpa backend, akun, roster, dashboard, remote unlock, timer khusus, atau penyimpanan jawaban. Gunakan dependency yang sudah terpasang dan jangan membuat alur produksi tiruan. Setiap transisi harus menjaga otorisasi dan penyimpanan; klaim proteksi mengikuti bukti pengujian.

**Kriteria penerimaan:**

- [ ] Boot membaca percobaan terlebih dahulu: aktif menjadi menunggu pemulihan, terkunci tetap terkunci, dan tanpa percobaan tertahan boleh membuka beranda.
- [ ] Pemulihan menahan soal sampai pemeriksaan dan PIN pengawas; penghitung/riwayat tetap, tanpa pelanggaran otomatis atau otorisasi lama.
- [ ] Melanjutkan memeriksa dan mengaktifkan proteksi kembali sebelum membuka soal; mengakhiri mengikuti prosedur pengakhiran sah.
- [ ] Pemulihan perubahan OS tertunda setelah status berakhir tetap dijalankan lintas proses mati; gagal tetap terlihat dan dapat dicoba ulang.
- [ ] Data rusak, state tidak dikenal, dan kegagalan membuka/menulis penyimpanan tidak diam-diam menjadi sesi baru berpenghitung nol; UI menyediakan penanganan pengawas.
- [ ] Keluar darurat bukan pengakhiran sah otomatis; saat kembali, pemeriksaan dan PIN diperlukan sesuai prosedur.
- [ ] Uji proses mati sebelum/sesudah transisi penting, termasuk setelah berakhir tersimpan sebelum pemulihan OS, serta kehilangan proses WebView. Hasil pemulihan state dipisahkan dari pemulihan isian.

