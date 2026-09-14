# 07: Pengawas melanjutkan sesi terkunci atau mengizinkan pengulangan

**Yang dibangun:** Pengawas memilih satu tindakan dengan PIN untuk melanjutkan, mengakhiri, mengulang, atau mengakses mode guru tanpa melewati pengamanan percobaan siswa.

**Diblokir oleh:** 05: Pengawas mengakhiri ujian dan memulihkan pengaturan; 06: Pelanggaran terverifikasi memperingatkan dan mengunci

**Status:** ready-for-agent

**Batas bersama:** Selesaikan dan gunakan kembali implementasi yang ada. Pertahankan desain Swiss Typographic Minimalism dan teks antarmuka, kecuali perubahan status nyata atau penjelasan yang diwajibkan spesifikasi. Android saja, tanpa backend, akun, roster, dashboard, remote unlock, timer khusus, atau penyimpanan jawaban. Gunakan dependency yang sudah terpasang dan jangan membuat alur produksi tiruan. Setiap transisi harus menjaga otorisasi dan penyimpanan; klaim proteksi mengikuti bukti pengujian.

**Kriteria penerimaan:**

- [ ] PIN benar mengizinkan tepat satu tindakan pada sesi/percobaan terkait; semua jalur memakai pembatasan kesalahan dan jeda persisten yang sama dalam lingkup sesi.
- [ ] Melanjutkan sesi terkunci mempertahankan percobaan, penghitung, riwayat, dan WebView selama proses masih hidup; proteksi diperiksa sebelum soal ditampilkan.
- [ ] Pelanggaran berikutnya setelah melanjutkan dari ambang ketiga langsung mengunci; tidak diberikan tiga kesempatan baru.
- [ ] Pengakhiran dari terkunci mengikuti prosedur simpan dan pemulihan yang sama dengan pengakhiran normal.
- [ ] Selama retensi, scan sesi berakhir meminta PIN sebelum percobaan baru dibuat; percobaan baru berpenghitung nol, riwayat lama tetap, dan kesiapan/proteksi wajib diperiksa kembali.
- [ ] Akses mode guru ketika percobaan siswa aktif/terkunci memerlukan PIN dan tidak menghapus, mengganti, atau membatalkan percobaan.
- [ ] PIN sesi lain, pembatalan, Back, otorisasi bekas, dan perubahan state saat dialog terbuka tidak memberi akses.
- [ ] Pengujian mencakup lanjut-kunci kembali, ulang tanpa PIN, riwayat lama, kesiapan gagal pada pengulangan, dan seluruh jalur otorisasi.

