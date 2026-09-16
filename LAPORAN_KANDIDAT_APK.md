# Laporan kandidat APK — Ticket 11

Tanggal bukti: 16 September 2026
Target kandidat: 28 September 2026

## Keputusan

**Belum lulus untuk simulasi kelas.** APK debug dapat dibangun dan satu
pengujian native pada HP fisik lulus, tetapi matriks perangkat dan seluruh
alur guru/siswa belum selesai. Ketiadaan bukti tidak dihitung sebagai lulus.

## Artefak dan stack

- Artefak: `build/app/outputs/flutter-apk/app-debug.apk`
- SHA-256: `ED1AE60F53B58BA6BE64DE2C4B9BD15E7168DBBCCB4E089A843A7122D2114764`
- Flutter 3.47.4 stable; Dart 3.13.3; Gradle 8.14; Android Gradle Plugin
  8.11.1; Kotlin 2.2.20.
- Dependency utama: `mobile_scanner` 7.4.1, `image_picker` 1.2.3,
  `local_auth` 3.0.2, `sqflite` 2.4.2+1, dan `webview_flutter` 4.14.1.
- Build lulus, tetapi Flutter memberi peringatan dukungan versi mendatang
  untuk Gradle, Android Gradle Plugin, dan Kotlin. Pembaruan stack perlu
  ditinjau sebelum distribusi produksi.
- Minimum Android **belum ditetapkan**. API 24 hanya kandidat dari bridge
  native; bukti fisik saat ini hanya ada pada API 29.

## Pemeriksaan yang dijalankan

| Cakupan | Hasil | Bukti |
| --- | --- | --- |
| Analisis statis | Lulus | `flutter analyze`: tidak ada isu. |
| Unit dan widget | Lulus | `flutter test --no-pub`: 124 test lulus. |
| Build Android | Lulus | Debug APK berhasil dibuat. |
| HP fisik | Lulus terbatas | M2006C3MG, Android 10/API 29. Uji integrasi memasang APK, memanggil bridge native, lalu runner menghapus aplikasi setelah selesai. |
| Bridge saat akses DND ditolak | Lulus | API didukung; `isReady` dan `activate` menolak mulai, `FLAG_SECURE` tetap nonaktif, dan `restore` berhasil. |
| Emulator Android | Tidak dijalankan | Tidak ada emulator Android terdeteksi. |

Uji fisik berada di `integration_test/native_protection_device_test.dart`.
Pengujian Flutter tidak dapat berinteraksi dengan UI sistem Android seperti
panel notifikasi atau dialog izin; tidak ada dependency tambahan yang dipakai
untuk menyimulasikannya.

## Matriks wajib sebelum kelulusan simulasi

| Alur atau kemampuan | Bukti saat ini | Status |
| --- | --- | --- |
| Guru membuat sesi, PIN, QR, dan preflight Form | Test otomatis saja | Belum diuji fisik |
| Siswa memindai kamera dan galeri | Belum diuji pada HP | Belum lulus |
| PIN, pengulangan, tiga pelanggaran, dan pemulihan | Test otomatis saja | Belum diuji fisik |
| Retensi tujuh hari | Test otomatis saja | Belum diuji fisik |
| Google Forms sampai submit | Tidak dijalankan | Belum lulus |
| Screenshot, recent apps, recording/casting | Tidak dijalankan | Belum lulus |
| Banner, isi/ketukan panel notifikasi, suara, getaran, panggilan | Tidak dijalankan | Belum lulus |
| Pemberian dan pencabutan akses DND | Tidak dijalankan | Belum lulus |
| Crash ketika proteksi aktif lalu pemulihan pengaturan | Tidak dijalankan | Belum lulus |

## Batas yang dicatat

- Status attempt berakhir bukan bukti bahwa Google Forms menerima jawaban.
  Pengawas tetap memeriksa bukti pengiriman sebelum mengakhiri ujian.
- Tidak ada inventaris manual HP peserta. Perangkat yang gagal pada matriks
  di atas tidak boleh dilaporkan didukung.
- Tidak ada kesimpulan bahwa tidak terdapat bug keamanan terbuka sebelum
  seluruh matriks fisik lulus. Temuan gagal harus menahan kelulusan kandidat.
