# 10: Riwayat kedaluwarsa dibersihkan dengan aman

**Yang dibangun:** Pembersihan otomatis membatasi riwayat percobaan berakhir hingga tujuh hari tanpa merusak sesi yang masih digunakan atau pemulihan pengaturan perangkat.

**Diblokir oleh:** 08: Buka ulang aplikasi memulihkan pengamanan

**Status:** ready-for-agent

**Batas bersama:** Selesaikan dan gunakan kembali implementasi yang ada. Pertahankan desain Swiss Typographic Minimalism dan teks antarmuka, kecuali perubahan status nyata atau penjelasan yang diwajibkan spesifikasi. Android saja, tanpa backend, akun, roster, dashboard, remote unlock, timer khusus, atau penyimpanan jawaban. Gunakan dependency yang sudah terpasang dan jangan membuat alur produksi tiruan. Setiap transisi harus menjaga otorisasi dan penyimpanan; klaim proteksi mengikuti bukti pengujian.

**Kriteria penerimaan:**

- [ ] Hanya percobaan berakhir lebih dari tujuh hari sejak waktu berakhir yang dipilih untuk dibersihkan; batas waktu diuji.
- [ ] Percobaan aktif, terkunci, menunggu pemulihan, serta data sesi/verifier yang masih dibutuhkan percobaan lain tetap tersedia.
- [ ] Data untuk pemulihan OS tertunda tidak dihapus sebelum pemulihan selesai; sesi guru yang belum pernah dipakai tidak hilang hanya karena tidak memiliki percobaan siswa.
- [ ] Pembersihan relasi aman saat gagal atau proses mati; pembukaan ulang tidak menemukan data parsial yang dianggap sebagai sesi baru sah.
- [ ] Pembersihan WebView terpisah dari retensi pengamanan dan hanya dilakukan setelah pengiriman jawaban diperiksa.
- [ ] Perilaku backup Android dan pembersihan penyimpanan ditetapkan serta diuji; batas hapus data/instal ulang/pindah perangkat dan pengulangan setelah retensi dijelaskan tanpa jaminan lintas instalasi.
- [ ] Uji batas tujuh hari, sesi bersama beberapa percobaan, sesi guru tanpa percobaan, pemulihan tertunda, dan kegagalan pembersihan.

