# Prompt implementasi MVP ExamSeal setelah desain Stitch

Salin seluruh isi bagian **Prompt untuk Codex** di bawah ke Codex pada folder `E:\flutter\examseal`.

## Prompt untuk Codex

```text
Lanjutkan implementasi ExamSeal Android MVP di repository ini. Jangan membuat atau mengubah desain Stitch: pertahankan UI Swiss Typographic Minimalism dan semua copy yang sudah ada, kecuali copy status memang harus berubah dari “Belum tersedia” menjadi status nyata.

Tujuan tugas ini: ubah rangkaian screen yang sudah ada menjadi satu alur ujian lokal yang benar-benar berfungsi dan tahan terhadap aplikasi ditutup, tanpa backend dan tanpa menambah scope produk.

Kondisi repository saat ini
- Semua dependency berikut sudah terpasang: `cryptography`, `flutter_secure_storage`, `image_picker`, `local_auth`, `mobile_scanner`, `path`, `qr_flutter`, `sqflite`, dan `webview_flutter`. Jangan menambah state-management, router, HTTP client, permission helper, atau package splash.
- Banyak UI screen dan widget test sudah tersedia. Pertahankan struktur dan callback publiknya bila memungkinkan.
- `lib/services/session_store.dart`, `pin_service.dart`, `exam_session_controller.dart`, dan `exam_protection.dart` masih kosong.
- `android/app/src/main/kotlin/com/example/examseal/MainActivity.kt` masih `FlutterActivity` kosong.
- `PreExamScreen` selalu menampilkan tiga kesiapan sebagai belum tersedia dan tombol mulai nonaktif.
- `ExamScreen` dan overlay peringatan sudah ada, tetapi belum menerima state nyata dari controller. `LockedScreen` dan `ProcessRecoveryScreen` juga sudah ada.
- QR saat ini memakai schema 1 dan belum membawa bahan verifikasi PIN. Ubah format secara eksplisit; QR lama boleh ditolak.

Baca `ExamSeal_PRD_MVP.md`, file yang disebut di atas, serta test yang berhubungan sebelum mengubah kode. Kerjakan dengan perubahan sekecil mungkin, tetapi hasilnya harus nyata, bukan dummy atau TODO.

Implementasi yang diminta

1. Bentuk model dan state machine lokal
   - Lengkapi model agar dapat menyimpan sesi guru, sesi hasil scan siswa, attempt ujian, event keamanan, dan status proteksi.
   - Gunakan state eksplisit minimal: `preExam`, `active`, `locked`, `recoveryPending`, dan `ended`.
   - Terapkan transisi yang aman: attempt aktif tidak dapat diam-diam ditimpa scan baru; pelanggaran ketiga mengunci; setelah pengawas melanjutkan sesi terkunci, counter dan riwayat tetap ada dan pelanggaran berikutnya langsung mengunci; attempt berakhir dapat diulang hanya setelah PIN pengawas benar.
   - Restart aplikasi saat state aktif harus mengarah ke `ProcessRecoveryScreen`, bukan langsung membuka Google Forms. Recovery tidak menambah pelanggaran.

2. Implementasikan penyimpanan lokal
   - Gunakan `sqflite` dan `path` di `session_store.dart` untuk menyimpan data sesi, attempt, event, status PIN attempts, dan status proteksi yang memang diperlukan untuk pemulihan.
   - Simpan sesi/attempt sebelum transisi UI penting. Bila penyimpanan gagal, jangan lanjut ke state yang bergantung pada data tersebut; tampilkan error yang dapat ditindaklanjuti.
   - Terapkan pembersihan hanya untuk attempt yang sudah berakhir dan berumur lebih dari tujuh hari. Jangan hapus sesi aktif atau terkunci.
   - Gunakan `flutter_secure_storage` hanya untuk rahasia pada HP guru. Jangan menyimpan PIN mentah di SQLite, payload QR, atau HP siswa.

3. Implementasikan PIN dan QR versi baru
   - Gunakan `Random.secure()` untuk PIN pengawas lima digit dan identifier/kode sesi baru.
   - Gunakan `cryptography` untuk membuat salt dan verifier PBKDF2/HMAC bagi PIN. QR versi baru harus memuat versi format, sessionId, sessionCode, examName, formUrl, policy/version yang diperlukan, serta bahan verifier. PIN mentah tidak boleh masuk QR.
   - Catat dengan jelas di kode dan UI yang relevan bahwa verifier QR pada sistem offline lima digit adalah kontrol operasional, bukan bukti autentikasi guru atau perlindungan terhadap reverse engineering pada perangkat siswa.
   - Verifikasi PIN pada aksi pengawas: akses mode guru saat student attempt aktif, lanjutkan attempt terkunci, akhiri attempt, dan ulang attempt berakhir.
   - Simpan lima kegagalan PIN berturut-turut dan cooldown 30 detik secara persisten. Otorisasi berlaku hanya untuk satu aksi, tidak permanen dan tidak dipulihkan setelah proses mati.
   - Saat guru ingin melihat lagi PIN sesi pada HP pembuat, gunakan `local_auth` dahulu lalu baca rahasia dari secure storage.

4. Implementasikan bridge proteksi Android pada Kotlin
   - Buat satu `MethodChannel` yang dibungkus rapi oleh `exam_protection.dart`; Flutter screen tidak boleh memanggil native channel secara langsung.
   - Pada Android API 24+, sediakan method minimal untuk: memeriksa dukungan/kesiapan, mengaktifkan `FLAG_SECURE`, melepas dan memulihkan proteksi saat attempt diakhiri, memeriksa akses Notification Policy, membuka halaman pengaturan akses tersebut atas aksi eksplisit pengguna, dan membaca ulang status saat aplikasi resumed.
   - Tambahkan manifest permission yang memang dibutuhkan untuk Notification Policy dan pertahankan permission Internet/Camera yang ada.
   - Jangan meminta atau mengubah akses DND otomatis saat aplikasi dibuka. Jika akses DND tidak ada atau kontrol notifikasi tidak dapat dibuktikan efektif pada perangkat, readiness harus gagal dan tombol mulai tetap nonaktif dengan arahan ujian alternatif.
   - Simpan pengaturan yang aplikasi ubah dan pulihkan saat attempt berakhir. Jika pemulihan gagal, tampilkan kegagalan dan sediakan retry; jangan mengaku sudah dipulihkan.
   - Jangan mengklaim panel notifikasi pasti tidak dapat dibuka, screenshot/recording pasti terblokir di semua HP, atau Google Forms pasti sudah submit. Catat kemampuan yang benar-benar tersedia pada perangkat.

5. Hubungkan controller ke alur UI yang ada
   - Buat composition root sederhana di `main.dart` atau satu widget aplikasi tingkat atas. Hindari provider/riverpod/bloc.
   - `BootScreen` harus memeriksa attempt tersimpan dan membuka mode yang benar: home, recovery, atau locked.
   - Teacher Mode harus benar-benar membuat sesi, menyimpan PIN terlindungi, memuat daftar sesi, dan menampilkan QR sesi yang sama tanpa membuat sesi baru.
   - Student Mode harus memvalidasi dan menyimpan payload QR versi baru, menolak QR lama/URL biasa/payload yang mencoba mengganti data sesi aktif, lalu membuka `PreExamScreen` dengan data nyata.
   - `PreExamScreen` harus menampilkan hasil readiness asli untuk QR, URL, proteksi layar, notifikasi, dan penyimpanan. Tombol “Mulai Ujian” hanya aktif bila semua yang wajib benar-benar lolos. Saat ditekan: aktifkan proteksi, simpan attempt `active`, lalu buka `ExamScreen`.
   - Sambungkan `ExamScreen`, `LockedScreen`, `ProcessRecoveryScreen`, `EndedScreen`, dan screen PIN yang sudah ada ke controller. End exam harus persist dulu, memulihkan proteksi, kemudian menunjukkan hasil pemulihan yang sebenarnya.

6. Pelanggaran dan gangguan
   - Tambahkan controller event yang menyimpan setiap kejadian beserta apakah kejadian itu dihitung sebagai pelanggaran.
   - Gunakan `WidgetsBindingObserver` untuk mencatat lifecycle/focus dan status jaringan/WebView untuk catatan operasional.
   - Panggilan masuk, jaringan putus, dialog OS, kehilangan fokus saja, dan crash/reboot adalah event ambigu: simpan sebagai event, tetapi jangan tambah counter secara otomatis.
   - Jangan menciptakan pemicu “pelanggaran” palsu hanya agar overlay dapat muncul. Hanya event yang benar-benar dapat dibuktikan pada perangkat uji dan dimasukkan ke matriks pemicu yang boleh menambah counter. Buat satu tempat terpusat untuk matriks tersebut.
   - Bila event terhitung menambah counter menjadi 1 atau 2, tampilkan overlay S05 yang sudah ada. Bila menjadi 3, persist state lalu pindah ke `LockedScreen`. Peringatan visual wajib; alarm/getaran boleh dibuat native jika dapat diuji dan berhenti maksimal dua detik.

7. Validasi dan kualitas
   - Perbarui/tambah test bermakna untuk: QR versi baru dan penolakan QR lama, PIN verifier dan cooldown persisten, transisi state machine, retensi yang tidak menghapus attempt aktif/locked, readiness yang menahan tombol mulai, serta recovery/third-violation lock.
   - Jangan membuat test yang hanya memeriksa implementasi privat atau menyalin logika produksi.
   - Jalankan `flutter analyze` dan seluruh `flutter test`. Laporkan hasilnya. Jika tool Android tersedia, buat debug APK atau jalankan minimal satu integration test pada emulator/perangkat; bedakan hasil yang benar-benar diuji dari perilaku yang masih memerlukan HP fisik.

Batas produk yang tidak boleh dilanggar
- Android saja, tanpa backend, akun, roster, sinkronisasi, dashboard pengawas, remote unlock, timer ujian khusus, atau penyimpanan jawaban Form.
- Google Forms tetap pemilik jawaban dan status submit. ExamSeal tidak boleh menyatakan jawaban tersimpan atau terkirim hanya karena attempt diakhiri.
- Jangan menghapus atau merombak desain Stitch, membuat mock session/PIN untuk production flow, atau mengaktifkan “Mulai Ujian” dengan status proteksi palsu.
- Jangan menambah violation karena event ambigu.
- Jangan menambah abstraction/framework besar. Pakai Dart/Flutter bawaan dan dependency yang sudah terpasang.

Di akhir, beri ringkasan: file yang diubah, alur yang sekarang berfungsi, hasil perintah validasi, serta perilaku native yang tetap harus dibuktikan di HP Android fisik sebelum pilot.
```

## Definition of done

- Guru dapat membuat sesi yang persist, memperoleh PIN lima digit, dan menampilkan ulang QR yang sama.
- Siswa dapat memindai QR baru, melihat readiness nyata, dan hanya memulai bila kondisi wajib lolos.
- State attempt serta cooldown PIN bertahan setelah aplikasi dibuka ulang.
- Attempt aktif yang dipulihkan memerlukan pemeriksaan dan PIN pengawas; attempt terkunci tidak dapat dilompati.
- Semua test dan analyzer lulus; klaim proteksi dibatasi pada hasil yang benar-benar dapat dibuktikan pada perangkat.
