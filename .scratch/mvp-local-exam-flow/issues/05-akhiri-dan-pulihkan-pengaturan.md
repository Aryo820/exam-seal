# 05: Pengawas mengakhiri ujian dan memulihkan pengaturan

**Yang dibangun:** Pengawas memeriksa pengiriman jawaban, memasukkan PIN untuk satu pengakhiran, dan melihat hasil pemulihan pengaturan perangkat yang sebenarnya.

**Diblokir oleh:** 04: Siswa mulai hanya setelah proteksi terbukti siap

**Status:** ready-for-agent

**Batas bersama:** Selesaikan dan gunakan kembali implementasi yang ada. Pertahankan desain Swiss Typographic Minimalism dan teks antarmuka, kecuali perubahan status nyata atau penjelasan yang diwajibkan spesifikasi. Android saja, tanpa backend, akun, roster, dashboard, remote unlock, timer khusus, atau penyimpanan jawaban. Gunakan dependency yang sudah terpasang dan jangan membuat alur produksi tiruan. Setiap transisi harus menjaga otorisasi dan penyimpanan; klaim proteksi mengikuti bukti pengujian.

**Kriteria penerimaan:**

- [ ] Permintaan selesai mempertahankan sesi dan proteksi sampai PIN benar serta tindakan dikonfirmasi; salah, batal, atau Back mengikuti state keamanan terbaru.
- [ ] PIN diverifikasi terhadap sesi/percobaan dan tindakan yang diminta. Lima kesalahan berturut-turut memicu jeda 30 detik yang bertahan setelah aplikasi dibuka ulang.
- [ ] Otorisasi hanya dapat dipakai sekali dan tidak dipulihkan setelah proses mati; tidak ada jalur pengakhiran tanpa otorisasi.
- [ ] State berakhir, alasan, dan tindakan pengawas disimpan secara konsisten sebelum proteksi dilepas; kegagalan simpan mempertahankan pengamanan.
- [ ] Hanya perubahan OS milik ExamSeal yang dipulihkan, tanpa mematikan aturan pengguna/aplikasi lain atau menimpa perubahan baru pengguna sembarangan.
- [ ] Kegagalan pemulihan tetap menyimpan data dan penanda tertunda, menampilkan sebab, dan menyediakan percobaan ulang; keberhasilan baru dinyatakan setelah terverifikasi.
- [ ] Layar berakhir membedakan akhir Exam Mode dari bukti submit Google Forms.
- [ ] Pengujian mencakup PIN salah/batal, jeda lintas restart, penggunaan ulang otorisasi, kegagalan simpan, serta pemulihan gagal lalu berhasil.

