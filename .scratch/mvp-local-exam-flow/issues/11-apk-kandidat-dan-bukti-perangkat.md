# 11: APK kandidat dibuktikan layak untuk simulasi

**Yang dibangun:** Build kandidat dan laporan pengujian membuktikan alur MVP pada cakupan perangkat yang dinyatakan didukung sebelum simulasi.

**Diblokir oleh:** 09: Gangguan jaringan ditangani tanpa membuang isian; 10: Riwayat kedaluwarsa dibersihkan dengan aman

**Status:** ready-for-agent

**Batas bersama:** Selesaikan dan gunakan kembali implementasi yang ada. Pertahankan desain Swiss Typographic Minimalism dan teks antarmuka, kecuali perubahan status nyata atau penjelasan yang diwajibkan spesifikasi. Android saja, tanpa backend, akun, roster, dashboard, remote unlock, timer khusus, atau penyimpanan jawaban. Gunakan dependency yang sudah terpasang dan jangan membuat alur produksi tiruan. Setiap transisi harus menjaga otorisasi dan penyimpanan; klaim proteksi mengikuti bukti pengujian.

**Kriteria penerimaan:**

- [ ] Flutter analyze dan seluruh flutter test dijalankan dengan hasil dicatat; semua pemeriksaan wajib lulus untuk kelulusan kandidat.
- [ ] Debug APK dibangun bila tool Android tersedia; build atau pengujian integrasi emulator/perangkat dilaporkan berdasarkan yang benar-benar dijalankan. Ketiadaan alat/bukti bukan kelulusan.
- [ ] Matriks perangkat pengembang menguji seluruh alur guru/siswa, kamera/galeri, PIN, pelanggaran, pemulihan, retensi, serta Form sampai submit tanpa inventaris manual HP peserta.
- [ ] Uji native mencakup screenshot, recent apps, recording/casting yang tersedia, suara/getaran/banner/isi notifikasi, ketukan notifikasi, panggilan, pemberian/penolakan/pencabutan akses, dan pemulihan pengaturan lintas crash.
- [ ] Minimum OS dan versi stack ditetapkan dari hasil pengujian; API 24 tetap kandidat sampai terbukti. Perangkat gagal tidak dilaporkan didukung.
- [ ] Tidak ada bug terbuka yang melewati PIN, mereset kunci secara tidak sah, atau mengklaim proteksi berhasil ketika gagal; kegagalan wajib menahan kelulusan simulasi.
- [ ] Laporan membedakan tes otomatis, emulator, HP fisik, dan hal belum terbukti; mencantumkan alur berfungsi serta batas Google Forms. Target APK kandidat 28 September 2026.

