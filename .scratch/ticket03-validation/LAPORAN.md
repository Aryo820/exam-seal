# Validasi tiket 03 — 14 September 2026

Implementasi alur guru menguji Form sebelum QR tersedia di workspace. Tiket belum ditutup karena bukti Form pilot pada Android dan commit belum selesai.

## Perubahan

- Pembuatan sesi dan pembukaan QR dari daftar guru melewati pemeriksaan kesiapan yang tersimpan. Sesi baru belum siap hanya karena URL sah.
- Guru dapat mengakses PIN melalui autentikasi perangkat sebelum membuka uji. Menutup uji memerlukan PIN pengawas.
- Checklist meminta guru mengerjakan sampai Kirim, memeriksa respons pada Google Forms/spreadsheet, memastikan batas pilot, dan tidak mengubah Form selama ujian.
- SQLite menyimpan waktu mulai, konfirmasi manual, URL sesi, serta jumlah navigasi yang diblokir. Tidak menyimpan soal atau jawaban. Uji ulang menghapus konfirmasi sebelumnya; kegagalan catatan menahan konfirmasi.
- WebView bersama membatasi HTTPS, host, satu identitas Form, endpoint pengerjaan, dan redirect shortlink. Navigasi iframe dibedakan dari halaman utama; pemuatan aset biasa tidak disaring sebagai perpindahan halaman.
- Guard dokumen menahan tautan luar, Form lain, edit respons, jendela baru, unduhan dari tautan, POST luar, serta upload. Halaman respons tanpa formulir menahan navigasi ulang; hal itu tidak dipakai sebagai bukti submit berhasil.
- Konten ditahan sampai inspeksi selesai. Hasil inspeksi lama tidak membuka halaman baru. Retry setelah konfigurasi gagal membangun controller baru dengan seluruh pembatasan.

## Bukti otomatis

| Pemeriksaan | Hasil |
| --- | --- |
| `flutter analyze --no-pub` | Bersih |
| `flutter test --no-pub` | 82 tes lulus |
| `node .scratch/ticket03-validation/check-form-guard.cjs` | Lulus dengan DOM pengganti |
| Pemeriksaan whitespace diff berkas tiket 03 | Lulus |
| `adb devices -l` | Tidak ada perangkat terhubung |

Pengujian baru mencakup URL peniru, redirect, satu identitas Form, endpoint respons multi-halaman, reentry setelah halaman respons, konfirmasi persisten, pembatalan status saat uji ulang, kepemilikan sesi, kegagalan penyimpanan, gate QR pada root aplikasi, PIN keluar, hasil inspeksi terlambat, upload, serta retry setelah setup gagal. Checklist juga diuji terhadap Back selama penyimpanan.

Tes adaptor WebView memasok hasil inspeksi pengganti. Pemeriksaan Node menjalankan skrip produksi dengan objek DOM pengganti. Keduanya belum membuktikan kompatibilitas DOM Google Forms atau perilaku WebView Android sesungguhnya.

## Review

Standar: temuan controller belum selesai dikonfigurasi dipakai saat retry sudah diperbaiki dan diberi tes regresi. Tidak ada temuan kode tersisa.

Spesifikasi: temuan Back selama operasi asinkron sudah diperbaiki dengan penahanan navigasi selama operasi dan pemeriksaan rute asal. Tidak ada temuan kode tersisa. Persyaratan bukti Form pilot masih terbuka.

## Uji yang masih diperlukan

Gunakan perangkat Android terhubung dan URL Form khusus percobaan yang diizinkan guru. Jalankan lewat alur guru ExamSeal, kirim jawaban percobaan, lalu guru memeriksa respons di Google Forms atau spreadsheet. Catat perangkat, versi Android/WebView, Form yang diuji, waktu, dan hasil pemeriksaan guru.

Periksa Form satu halaman dan multi-halaman; URL langsung dan shortlink; tautan luar/Form lain; login wajib; upload; edit respons; kirim respons lain; jendela baru; intent; unduhan; serta gangguan jaringan. Hasil yang belum dijalankan tetap belum terverifikasi.

## Batas commit

Snapshot sebelum tiket ini berada di `.scratch/ticket03-implementation-baseline/`. Workspace masih berisi perubahan fondasi dan tiket 01–02 yang belum masuk commit. Commit tiket 03 belum dibuat karena bergantung pada fondasi tersebut; snapshot dan berkas pemeriksaan sementara tidak boleh ikut tersapu ke commit secara massal.

## Acuan API

Integrasi menggunakan API dependency yang sudah terpasang dan contoh resmi [webview_flutter](https://pub.dev/packages/webview_flutter). Batas callback navigasi native diperiksa terhadap [WebViewClient Android](https://developer.android.com/reference/android/webkit/WebViewClient) dan sumber paket Android terpasang. Tidak ada dependency baru.
