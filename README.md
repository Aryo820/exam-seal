# examseal

ExamSeal menyimpan sesi, PIN verifier, state pengamanan, dan riwayat attempt
secara lokal di perangkat Android.

## Retensi dan batas data lokal

- Attempt berakhir dihapus otomatis setelah lebih dari tujuh hari sejak waktu
  berakhir. Attempt aktif, terkunci, menunggu pemulihan, dan penanda pemulihan
  proteksi tetap dipertahankan.
- Retensi hanya menghapus data pengamanan ExamSeal. Data WebView tidak dibersihkan
  olehnya dan hanya boleh ditangani setelah pengawas memeriksa pengiriman Google
  Forms; status lokal berakhir bukan bukti pengiriman.
- Backup cloud dan transfer perangkat Android dikecualikan untuk seluruh data
  aplikasi. Hapus data, instal ulang, atau pindah perangkat menghapus batas
  pengulangan lokal; aplikasi tidak menjamin dapat mengenali attempt lama pada
  instalasi atau perangkat lain. Untuk pelaksanaan berikutnya, guru membuat sesi
  baru.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
