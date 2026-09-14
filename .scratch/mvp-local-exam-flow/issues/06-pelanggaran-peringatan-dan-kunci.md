# 06: Pelanggaran terverifikasi memperingatkan dan mengunci

**Yang dibangun:** Kejadian yang terbukti sesuai matriks pemicu menghasilkan peringatan pertama/kedua lalu penguncian pada ketiga, sementara gangguan ambigu hanya dicatat.

**Diblokir oleh:** 04: Siswa mulai hanya setelah proteksi terbukti siap

**Status:** ready-for-agent

**Batas bersama:** Selesaikan dan gunakan kembali implementasi yang ada. Pertahankan desain Swiss Typographic Minimalism dan teks antarmuka, kecuali perubahan status nyata atau penjelasan yang diwajibkan spesifikasi. Android saja, tanpa backend, akun, roster, dashboard, remote unlock, timer khusus, atau penyimpanan jawaban. Gunakan dependency yang sudah terpasang dan jangan membuat alur produksi tiruan. Setiap transisi harus menjaga otorisasi dan penyimpanan; klaim proteksi mengikuti bukti pengujian.

**Kriteria penerimaan:**

- [ ] Matriks pemicu terpusat mencatat bukti perangkat, klasifikasi, korelasi dan toleransi/debounce; hanya pemicu yang disepakati dan terbukti dapat menambah penghitung.
- [ ] Panggilan, jaringan putus, dialog OS, kehilangan fokus saja, serta crash/reboot tidak otomatis melanggar. Dialog/peringatan milik aplikasi dikenali dalam klasifikasi.
- [ ] Satu kejadian yang menghasilkan beberapa callback dihitung sekali; event, penghitung, dan perubahan state tersimpan konsisten sebelum UI mengakui transisi.
- [ ] Pelanggaran pertama/kedua menampilkan peringatan; ketiga menyembunyikan dan menonaktifkan soal dengan proteksi tetap aktif, tanpa sengaja memuat ulang WebView.
- [ ] Dialog PIN atau Back tidak dapat mengembalikan state lama maupun membatalkan penguncian. Penghitung yang sudah mencapai ambang membuat pelanggaran berikutnya langsung mengunci.
- [ ] Setiap pelanggaran sah memicu upaya audio/getaran maksimal dua detik tanpa pengulangan terus-menerus; peringatan visual selalu tersedia dan kegagalan audio tidak diklaim berhasil.
- [ ] Log menyimpan jenis, waktu, korelasi, status dihitung, dan penghitung akhir tanpa isi jawaban/notifikasi/kredensial; log bukan bukti pasti kecurangan.
- [ ] Uji urutan peringatan-kunci, duplikasi callback, event ambigu, kegagalan simpan, dan kunci saat dialog terbuka; uji audio dengan DND, senyap, headset/Bluetooth, panggilan, dan perangkat tanpa getaran.

