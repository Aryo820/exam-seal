# 09: Gangguan jaringan ditangani tanpa membuang isian

**Yang dibangun:** Siswa melihat gangguan koneksi atau halaman tanpa kehilangan pengamanan; halaman yang masih tersedia dipertahankan dan pemulihan berisiko dilakukan dengan pengawas.

**Diblokir oleh:** 04: Siswa mulai hanya setelah proteksi terbukti siap

**Status:** ready-for-agent

**Batas bersama:** Selesaikan dan gunakan kembali implementasi yang ada. Pertahankan desain Swiss Typographic Minimalism dan teks antarmuka, kecuali perubahan status nyata atau penjelasan yang diwajibkan spesifikasi. Android saja, tanpa backend, akun, roster, dashboard, remote unlock, timer khusus, atau penyimpanan jawaban. Gunakan dependency yang sudah terpasang dan jangan membuat alur produksi tiruan. Setiap transisi harus menjaga otorisasi dan penyimpanan; klaim proteksi mengikuti bukti pengujian.

**Kriteria penerimaan:**

- [ ] Putus-sambung jaringan dan kegagalan WebView tercatat sebagai gangguan operasional tanpa mengakhiri sesi atau menambah pelanggaran.
- [ ] Tidak ada pemuatan ulang otomatis ketika jaringan kembali; WebView dan isian yang masih tersedia dipertahankan.
- [ ] Gagal memuat menyediakan percobaan ulang yang jelas; tindakan berisiko membuang isian menjelaskan konsekuensi dan meminta pemeriksaan pengawas.
- [ ] Form ditutup, dihapus, atau meminta login mendapat penanganan gangguan tanpa membuka browser luar maupun melepas proteksi.
- [ ] Jaringan kembali dan status lokal tidak dinyatakan sebagai bukti jawaban terkirim; tidak ditambahkan cadangan atau antrean jawaban offline.
- [ ] Pengujian mencakup putus koneksi saat mengerjakan/submit, kembali terhubung, halaman gagal, dan pemulihan berisiko dengan state serta penghitung tetap.

