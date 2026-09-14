# 04: Siswa mulai hanya setelah proteksi terbukti siap

**Yang dibangun:** Siswa hanya dapat membuka soal setelah seluruh kesiapan wajib lolos, proteksi diaktifkan, dan percobaan aktif berhasil disimpan.

**Diblokir oleh:** 02: Siswa masuk melalui kamera atau galeri; 03: Guru menguji Form sebelum membagikan QR

**Status:** ready-for-agent

**Batas bersama:** Selesaikan dan gunakan kembali implementasi yang ada. Pertahankan desain Swiss Typographic Minimalism dan teks antarmuka, kecuali perubahan status nyata atau penjelasan yang diwajibkan spesifikasi. Android saja, tanpa backend, akun, roster, dashboard, remote unlock, timer khusus, atau penyimpanan jawaban. Gunakan dependency yang sudah terpasang dan jangan membuat alur produksi tiruan. Setiap transisi harus menjaga otorisasi dan penyimpanan; klaim proteksi mengikuti bukti pengujian.

**Kriteria penerimaan:**

- [ ] Kesiapan mencakup QR, URL, penyimpanan, proteksi layar, serta notifikasi. Izin DND atau filter aktif saja tidak menjadi bukti efektivitas; cakupan dukungan merujuk hasil pengujian perangkat.
- [ ] Pengaturan akses notifikasi dibuka hanya atas tindakan eksplisit; aplikasi tidak meminta atau mengubah DND otomatis ketika dibuka.
- [ ] Proteksi native diakses melalui satu pembungkus layanan. FLAG_SECURE aktif sebelum soal terlihat; status notifikasi diperiksa berdasarkan kemampuan sebenarnya.
- [ ] Data pemulihan perubahan OS milik aplikasi tersimpan sebelum perubahan yang memerlukannya; kegagalan aktivasi atau simpan tidak membuka soal dan ditangani secara terlihat.
- [ ] State aktif tersimpan sebelum navigasi ke ujian. Mulai pertama tidak meminta PIN; ketukan berulang tidak membuat percobaan ganda.
- [ ] Status dibaca ulang saat kembali ke aplikasi. Izin dicabut atau proteksi gagal terlihat, mempertahankan state, dan meminta penanganan pengawas.
- [ ] Perangkat tidak didukung tetap tidak dapat mulai dan mendapat arahan ujian alternatif; tidak ada klaim panel sistem pasti tertutup.
- [ ] Uji gerbang mulai mencakup penolakan izin, kemampuan belum terbukti, kegagalan native/penyimpanan, serta tidak adanya frame soal tanpa proteksi pada cakupan perangkat yang diuji.

