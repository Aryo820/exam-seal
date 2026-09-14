# 01: Guru membuat dan membuka ulang sesi

**Yang dibangun:** Guru membuat sesi dari nama ujian dan URL Form, menerima PIN lima digit dan QR versi baru, lalu dapat membuka kembali sesi yang sama setelah aplikasi ditutup.

**Diblokir oleh:** Tidak ada (dapat dimulai segera).

**Status:** in-progress

**Batas bersama:** Selesaikan dan gunakan kembali implementasi yang ada. Pertahankan desain Swiss Typographic Minimalism dan teks antarmuka, kecuali perubahan status nyata atau penjelasan yang diwajibkan spesifikasi. Android saja, tanpa backend, akun, roster, dashboard, remote unlock, timer khusus, atau penyimpanan jawaban. Gunakan dependency yang sudah terpasang dan jangan membuat alur produksi tiruan. Setiap transisi harus menjaga otorisasi dan penyimpanan; klaim proteksi mengikuti bukti pengujian.

**Kriteria penerimaan:**

- [ ] Nama dan URL divalidasi; ID/kode sesi serta PIN lima digit dihasilkan secara acak aman. Sesi dan rahasia tersimpan sebelum keberhasilan ditampilkan; kegagalan simpan ditampilkan dengan tindakan pemulihan.
- [ ] QR versi baru memuat identitas sesi, URL, versi kebijakan, salt dan verifier PBKDF2/HMAC. PIN mentah tidak masuk QR, SQLite, log, atau penyimpanan siswa; rahasia hanya tersimpan terlindungi pada HP pembuat.
- [ ] Daftar sesi guru memuat sesi milik perangkat pembuat; membuka ulang QR mempertahankan identitas, konfigurasi, dan verifier tanpa membuat sesi baru.
- [ ] Melihat ulang PIN memerlukan autentikasi perangkat sebelum membaca rahasia; pembatalan atau kegagalan autentikasi tidak mengungkap PIN.
- [ ] Akses mode guru tidak mengganti atau membatalkan percobaan siswa yang belum diakhiri sah; sampai otorisasi tersedia, akses tersebut tetap ditahan.
- [ ] UI relevan menjelaskan bahwa verifier offline lima digit adalah kontrol operasional, bukan autentikasi identitas guru atau jaminan tahan analisis perangkat siswa.
- [ ] Pengujian mencakup pembuatan, kegagalan simpan, buka ulang, konsistensi QR, dan penolakan akses PIN tanpa autentikasi.
