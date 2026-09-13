# ExamSeal: Panduan Desain MVP

Tanggal: 12 September 2026  
Sumber kebutuhan: `ExamSeal_PRD_MVP.md`, 12 September 2026.  
Style pilihan: **Swiss / Typographic Minimalism**, sesuai keputusan pengguna.  
Status: arah desain untuk mockup dan implementasi; belum merupakan hasil uji kegunaan atau validasi proteksi perangkat.

## 1. Tujuan dan batas produk

ExamSeal membantu guru menjalankan ujian Google Forms di HP Android pribadi siswa dengan pengawasan langsung. Pilot mencakup satu kelas SMK, sekitar 30–40 siswa. Desain harus membantu siswa memulai dengan benar, mengerjakan dengan tenang, dan meminta tindakan pengawas tanpa kebingungan.

Guru menyiapkan sesi dan QR. Siswa memindai QR, memeriksa kesiapan, lalu mengerjakan Google Forms. Keluar, melanjutkan sesi terkunci/pemulihan proses, dan mengulang sesi berakhir selama retensi membutuhkan PIN pengawas.

Batas yang wajib dipertahankan:

- Android; target implementasi Flutter dengan kebutuhan proteksi native. Desain tidak menetapkan minimum Android yang dijamin.
- Tidak ada akun, backend ExamSeal, roster, dashboard kelas, sinkronisasi, atau pemantauan jarak jauh.
- Soal, identitas siswa, jawaban, dan submit berada di Google Forms. ExamSeal tidak membuat formulir identitas atau mesin soal sendiri.
- Form pilot tidak membutuhkan login, upload file, layanan luar, edit respons, atau kirim respons lain.
- Tidak ada timer khusus, nilai, leaderboard, langganan, atau tombol keluar tanpa PIN.
- Koneksi internet tetap dibutuhkan Google Forms. Tidak ada cadangan jawaban offline milik ExamSeal.
- Status sesi berakhir bukan bukti jawaban terkirim. Proteksi perangkat dan kejadian aplikasi bukan bukti pasti kecurangan.

Jika panduan ini bertentangan dengan perilaku dalam PRD, PRD menjadi acuan perilaku. Warna, ukuran, dan komposisi di sini adalah keputusan desain.

## 2. Arah visual

Gunakan **Swiss / Typographic Minimalism**: latar putih, tipografi hitam yang tegas, grid presisi, perataan kiri, dan garis pemisah. Kesan utama adalah formal, jelas, dan disiplin. Hierarki dibangun melalui ukuran serta bobot huruf, jarak, dan penempatan informasi.

Pola interaksi Android tetap familier. Komponen Material 3 dapat menjadi fondasi perilaku dan aksesibilitas, tetapi tampilan komponen milik ExamSeal mengikuti token Swiss di dokumen ini. Dialog autentikasi dan keyboard sistem mempertahankan tampilan Android.

- Satu tugas utama per layar, dengan satu tindakan utama yang paling menonjol.
- Blok nama ujian dan kode sesi menjadi elemen pengenal berulang di HP guru maupun siswa: judul tebal rata kiri, kode pada baris tersendiri, lalu garis horizontal. Kode mudah dibandingkan, tetapi tidak dilabeli sebagai autentikasi identitas guru.
- Susun judul, label, baris informasi, dan tombol pada sumbu kiri yang sama. Ruang kosong memisahkan bagian; gunakan daftar beraturan untuk informasi berulang.
- Kondisi normal didominasi putih, hitam, dan abu netral. Tombol utama berwarna hitam; biru tua hanya untuk fokus dan tautan tindakan. Warna semantik dipakai pada status yang membutuhkan perhatian.
- Warna merah muncul pada penguncian, kegagalan kritis, dan tindakan mengakhiri yang perlu perhatian. Teks, ikon, atau garis berwarna cukup untuk menandai keadaan; jangan mewarnai seluruh layar merah.
- Ikon hanya membantu arti: QR, kamera, gambar, kunci, peringatan, koneksi, dan tanda siap. Sertakan label untuk tindakan.
- Gunakan tulisan `ExamSeal` tebal dan rata kiri sebagai identitas awal. Logo khusus belum ditetapkan.
- Hindari efek neon, gradien dekoratif, glassmorphism, maskot, ilustrasi stok, gamifikasi, kartu mengambang, kapsul dekoratif, dan kartu statistik pengisi ruang.
- Ketegasan visual tetap menjaga kenyamanan membaca. Hindari teks isi kecil, judul kapital semua, tracking lebar, angka dekoratif raksasa, dan grid yang digambar sebagai latar.

Arahan ini menggantikan style lembut membulat pada rekomendasi dan prompt sebelumnya. Jika prompt Stitch lama digunakan, ganti bagian arahan visual serta tokennya dengan bagian 2–5 dokumen ini.

## 3. Token visual

### Warna

| Token | Nilai | Pemakaian |
|---|---|---|
| background | `#FFFFFF` | Latar aplikasi |
| surface | `#FFFFFF` | Form, dialog, lembar konten |
| primary | `#171717` | Tombol utama dan identitas tipografis |
| on-primary | `#FFFFFF` | Teks tombol utama |
| surface-subtle | `#F3F3F3` | Latar sekunder bila diperlukan untuk membedakan area |
| text-primary | `#171717` | Judul dan isi utama |
| text-secondary | `#595959` | Petunjuk dan metadata |
| divider | `#D6D6D6` | Pemisah baris noninteraktif |
| rule-strong | `#171717` | Garis pembatas bagian utama |
| input-border | `#737373` | Batas input yang perlu terlihat |
| focus-link | `#234A78` | Indikator fokus dan tautan tindakan |
| ready | `#216E4E` | Teks/ikon kesiapan |
| ready-soft | `#EDF7F1` | Latar status siap |
| warning | `#8A4B08` | Peringatan pertama dan terakhir |
| warning-soft | `#FFF4DF` | Latar peringatan |
| danger | `#B42318` | Terkunci, kegagalan kritis, tindakan destruktif |
| danger-soft | `#FEF3F2` | Latar status kritis |

Warna semantik selalu dipasangkan dengan teks dan ikon. Hijau hanya muncul ketika pemeriksaan terkait benar-benar lolos. Gunakan latar semantik lembut hanya pada pesan terkait, bukan setiap baris atau seluruh layar. Jangan menyatukan status izin dengan klaim semua proteksi terbukti efektif.

### Tipografi dan ukuran

- Font: Roboto, fallback sans-serif sistem. Satu keluarga sans-serif yang netral untuk hierarki tipografis dan konsistensi Android. Bobot 400, 500, dan 700; tanpa font dekoratif.
- Judul layar: 28–32 sp, bobot 700, rata kiri; judul bagian: 18–20 sp, bobot 700. Header saat ujian cukup 18–20 sp agar ruang soal tetap dominan.
- Isi: 16 sp, tinggi baris sekitar 1,4–1,5; metadata: 14 sp.
- Kode sesi: 20 sp, bobot 700, angka dengan lebar konsisten bila tersedia. Kode tidak terpotong. Gunakan kapital sesuai format kode; label lainnya memakai kapitalisasi kalimat dan jarak huruf normal.
- Spasi: 4, 8, 12, 16, 24, 32 dp. Margin horizontal layar 24 dp; 16 dp pada layar sempit bila diperlukan. Antarbagian utama 32 dp, antarbaris terkait 12–16 dp.
- Tombol utama: hitam solid dengan teks putih, tinggi minimum 56 dp, radius 2 dp. Tinggi boleh bertambah untuk teks besar atau label dua baris. Tombol sekunder memakai garis atau teks sesuai hierarki.
- Input: putih, garis batas 1 dp, tinggi minimum 56 dp, radius 2 dp, label tetap terlihat di atas field. Fokus menggunakan garis biru tua yang lebih tebal tanpa menggeser tata letak.
- Area sentuh minimum 48 × 48 dp. Jarak antaraksi umumnya 8 dp atau lebih.
- Panel informasi: radius 0 dp. Dialog milik aplikasi: radius 4 dp. Pertahankan bentuk native untuk permukaan milik sistem.
- Garis pemisah baris: 1 dp abu; garis bagian utama: 2 dp hitam, dipakai selektif setelah blok identitas atau sebelum tindakan utama.
- Tanpa bayangan pada halaman, baris, tombol, dan panel biasa. Dialog memakai bidang opak dan scrim untuk memisahkan lapisan; bayangan tidak menjadi motif visual.

## 4. Tata letak dan aksesibilitas

- Acuan mockup: portrait 390 × 844 logical pixels. Periksa adaptasi pada lebar 360 dan 412 dp serta pembesaran teks hingga 200%.
- Satu kolom, safe area sistem dihormati. Jangan menjanjikan panel atau navigasi sistem Android tidak dapat dibuka.
- Gunakan grid internal empat kolom dengan gutter 8 dp untuk menjaga keselarasan; alur baca tetap satu kolom. Label/status dapat berbagi baris jika muat, lalu bertumpuk pada layar sempit atau teks besar.
- Judul dan isi rata kiri; jangan meratakan teks kiri-kanan penuh. QR dan bingkai kamera boleh berada di tengah area fungsionalnya, sementara judul serta instruksi tetap mengikuti sumbu kiri.
- Judul panjang boleh membungkus. Pertahankan kode sesi utuh pada baris tersendiri.
- Konten panjang dapat digulir; tindakan bawah memiliki ruang khusus dan tidak menutupi konten atau keyboard. Jika tinggi terbatas, pindahkan tindakan ke alur gulir yang tetap dapat dijangkau.
- Selama ujian, Form memiliki area gulir utama. Hindari membungkus WebView dalam guliran layar kedua.
- Gunakan kontras teks minimum 4,5:1 untuk teks normal dan 3:1 untuk teks besar. Batas kontrol penting juga harus jelas. Verifikasi pasangan warna setelah dirender.
- TalkBack membaca nama ujian, kode, status, lalu tindakan dalam urutan yang masuk akal. Label PIN menyebut lima digit, tetapi tidak membacakan nilainya.
- Perubahan peringatan diumumkan secara aksesibel; jangan membacakan ulang seluruh layar setiap perubahan kecil.
- Animasi transisi singkat sekitar 150–200 ms bila diperlukan. Tidak ada kedipan merah, gerak berulang, atau animasi selama siswa membaca soal. Hormati pengaturan pengurangan animasi.

## 5. Komponen bersama

### Identitas sesi

Nama ujian, kode sesi, dan konteks status. Contoh isi desain: `Matematika Kelas XI` dan `MTH-7K2P`. Ini data contoh mockup; format kode final belum ditetapkan di PRD. Jangan menambahkan jumlah siswa online, nama guru terverifikasi, atau status sinkronisasi.

Letakkan langsung di atas latar putih: nama ujian tebal, label `Kode sesi` kecil, kode utuh, dan garis bawah 2 dp. Jangan membungkus identitas dalam kartu membulat atau kapsul berwarna. Di layar ujian aktif, gunakan versi ringkas dengan pemisah 1 dp.

### Baris kesiapan

Ikon, nama pemeriksaan, status tertulis, dan aksi perbaikan bila relevan. Contoh: `Pengendalian notifikasi` / `Izin diperlukan` / `Atur izin`. Varian: memeriksa, lolos pemeriksaan, perlu izin, tidak didukung, dan gagal memeriksa.

Susun sebagai daftar dengan pemisah horizontal 1 dp. Ikon berukuran konsisten, nama pemeriksaan dominan, status menjadi teks sekunder. Pada lebar yang cukup, status boleh rata kanan; pada teks besar, pindahkan status dan aksi ke bawah label. Hindari badge kapsul dan kartu terpisah untuk setiap pemeriksaan.

`Mulai Ujian` hanya tersedia setelah semua pemeriksaan wajib lolos. Status awal boleh menyebut `Pemeriksaan perangkat lolos`, dengan penjelasan singkat bahwa proteksi ujian diterapkan saat mulai. Setelah menekan mulai, tampilkan `Menyiapkan ujian…`; tampilkan soal hanya setelah state tersimpan dan proteksi wajib diterapkan. Kegagalan menahan akses soal dan memberi arahan bantuan.

### Pesan dan dialog

Gangguan koneksi ditampilkan dekat konten sebagai status persisten, tanpa otomatis menutup Form. Peringatan pelanggaran memakai dialog dengan judul, konsekuensi, dan tombol `Lanjutkan Ujian`. Penguncian menutup soal sepenuhnya dengan lapisan opak; tidak menggunakan blur transparan.

Gunakan judul tebal rata kiri, ikon kecil yang relevan, dan garis penanda semantik. Dialog peringatan dapat memakai latar `warning-soft`; layar terkunci tetap putih dengan judul/penanda merah dan lapisan opak. Hierarki informasi tetap terbaca tanpa warna. Hindari ikon kunci raksasa atau komposisi poster yang mendorong instruksi ke luar layar.

Dialog mengikuti status pengamanan terbaru. Membatalkan PIN atau menutup peringatan tidak boleh mengembalikan soal jika sesi telah terkunci.

### PIN pengawas

Gunakan satu field numerik tersamarkan, lima digit; boleh ditampilkan sebagai lima posisi visual dengan satu fokus input. Terima nol di awal. Gunakan keyboard numerik sistem dan tombol `Verifikasi PIN`; tidak ada pengiriman otomatis pada digit kelima.

Posisi digit, jika dipisahkan secara visual, menggunakan kotak bersudut 2 dp dan garis tipis yang seragam. Fokus terlihat jelas. Jangan mengganti keyboard sistem dengan keypad dekoratif.

Judul selalu menyebut maksud: melanjutkan, mengakhiri, atau mengulang sesi. PIN salah ditampilkan di dekat field. Lima kesalahan berturut-turut memunculkan `Terlalu banyak percobaan. Coba lagi dalam 30 detik.` dengan hitung mundur; hitung mundur ini bukan timer ujian. Membuka ulang aplikasi tidak mereset jeda.

Di HP siswa, jangan menyediakan tombol salin atau tampilkan PIN. PIN benar mengizinkan keputusan untuk tindakan saat itu, bukan akses pengawas permanen.

## 6. Spesifikasi layar

| ID | Layar | Hierarki dan perilaku |
|---|---|---|
| S01 | Beranda | Nama aplikasi, penjelasan satu kalimat, `Scan QR Ujian`, `Pilih dari Galeri`, lalu akses sekunder `Untuk Guru`. Tidak ada login atau navigasi bawah. |
| S02 | Scan QR | Kamera dan bingkai scan, instruksi `Arahkan kamera ke QR sesi dari guru`, tombol galeri yang selalu tersedia, kontrol kembali sebelum sesi aktif. Scan ganda tidak membuat sesi baru. |
| S03 | Persiapan ujian | Identitas sesi, instruksi mencocokkan kode, pemeriksaan perangkat, aturan ringkas, tombol mulai. Belum siap menampilkan alasan serta tindakan perbaikan; perangkat tidak didukung diarahkan ke pengawas untuk alternatif. |
| S04 | Ujian aktif | Header ringkas dengan nama/kode sesi dan `Pelanggaran: 0`; Form mendominasi layar. Aksi sekunder `Minta Persetujuan Selesai` terpisah dari tombol `Kirim` milik Forms. Tidak ada address bar, share URL, refresh, browser luar, atau menu berpindah mode. |
| S05 | Peringatan pertama/kedua | Dialog amber: `Peringatan pertama` atau `Peringatan terakhir`, ringkasan event yang memang dihitung, konsekuensi, tombol lanjut. Jangan menampilkan jenis pemicu yang belum dibuktikan sebagai aturan pasti. |
| S06 | Ujian terkunci | Identitas sesi, ikon kunci, `Ujian dikunci`, jumlah pelanggaran, alasan dan instruksi tetap di tempat/angkat tangan. Tombol `PIN Pengawas`. Tidak ada tombol lanjut langsung atau kembali ke beranda. |
| S07 | Keputusan pengawas | Setelah PIN benar pada sesi terkunci: ringkasan status/kejadian, `Lanjutkan Ujian` sebagai aksi utama, `Akhiri Ujian` sebagai aksi destruktif yang perlu konfirmasi. Counter dan riwayat tidak direset ketika lanjut. |
| S08 | Persetujuan selesai | Panel permintaan: `Tetap di tempat dan angkat tangan.` Jelaskan pengawas memeriksa bukti pengiriman sebelum memasukkan PIN. Sediakan jalur PIN dan pembatalan yang menghormati state terbaru. Setelah PIN, konfirmasi mengakhiri; jangan menutup sesi hanya karena siswa menekan permintaan. |
| S09 | Sesi berakhir | `Sesi ujian berakhir`, identitas sesi dan alasan pengakhiran; bukan nilai atau bukti submit. Tombol `Kembali ke Beranda` sesudah proses pengakhiran aman. Jika pemulihan pengaturan tertunda, tampilkan status sebenarnya. |
| S10 | Pemulihan proses | `Ujian perlu pemeriksaan pengawas`, informasi bahwa aplikasi sempat tertutup dan isian mungkin tidak pulih, jumlah pelanggaran yang tersimpan, PIN untuk keputusan lanjut/akhiri. Tanpa pelanggaran baru otomatis. |
| S11 | Pengulangan sesi | Setelah QR sesi berakhir dipindai dalam retensi: `Sesi ini sudah diakhiri`, penjelasan pengulangan perlu PIN, lalu konfirmasi attempt baru. Counter nol hanya pada attempt baru yang disetujui. |
| T01 | Sesi guru | Daftar sesi lokal sederhana: nama dan kode, akses menampilkan QR yang sama, serta `Buat Sesi Baru`. Empty state menjelaskan belum ada sesi. Tidak ada pemantauan siswa atau agregasi kelas. |
| T02 | Buat sesi | Field `Nama ujian` dan `Link Google Forms`, validasi dekat field, tombol `Buat Sesi`. Jelaskan batas Form tanpa login/upload. Aturan proteksi dan ambang tiga pelanggaran tidak memiliki toggle. |
| T03 | Uji Form sebelum dibagikan | Instruksi uji lengkap sampai submit melalui ExamSeal, cek tidak ada edit/kirim respons lain, lalu konfirmasi manual guru bahwa pemeriksaan selesai. Validasi URL tidak boleh menghasilkan label siap ujian. Jangan ciptakan pemeriksa otomatis submit. |
| T04 | QR sesi | Nama dan kode besar, QR hitam di bidang putih dengan ruang kosong cukup, tombol membagikan QR. Tampilkan ulang menjaga ID/config. Jangan menaruh PIN pada layar QR atau gambar yang dibagikan. |
| T05 | PIN pada HP pembuat | Akses ulang memakai autentikasi perangkat. PIN lima digit baru terlihat setelah autentikasi; ingatkan menyimpan salinan aman. Gunakan tampilan terpisah dari QR. Tidak ada ganti PIN massal. |

Aturan ringkas S03:

1. Pelanggaran pertama dan kedua memberi peringatan; pelanggaran ketiga mengunci ujian.
2. Keluar dari sesi membutuhkan persetujuan dan PIN pengawas.
3. Peringatan dapat disertai bunyi/getaran singkat sesuai kemampuan HP.
4. Panggilan masuk dan jaringan putus tidak otomatis dihitung sebagai pelanggaran.

## 7. Varian gangguan yang wajib didesain

| Kondisi | Pesan dan tindakan |
|---|---|
| Kamera ditolak/gagal | `Kamera tidak tersedia. Pilih gambar QR dari galeri.` Pembatalan sebelum ujian tidak melanggar. |
| Gambar tidak berisi QR/ambigu | Jelaskan kegagalan; tawarkan pilih gambar lain. Tidak memilih kandidat ambigu diam-diam. |
| QR hanya URL biasa | `QR ini bukan QR sesi ExamSeal. Minta QR sesi dari guru.` |
| QR rusak/tidak didukung/konflik | Jelaskan perlu QR sesi yang sesuai; jangan menimpa sesi tersimpan. |
| Koneksi putus | `Koneksi terputus. Jangan tutup aplikasi.` Pertahankan halaman dan counter; jangan reload otomatis atau mengklaim jawaban tersimpan. |
| Form gagal dimuat | Pesan sebab dan aksi coba lagi. Jika pemuatan ulang berisiko menghapus isian, jelaskan konsekuensinya dan minta pemeriksaan pengawas dahulu. |
| Form meminta login/fitur tak didukung | `Form ini memerlukan bantuan pengawas.` Sertakan sebab; jangan menawarkan browser luar. |
| Proteksi gagal saat aktif | `Pengendalian notifikasi bermasalah. Minta bantuan pengawas.` Pertahankan status sesi, tampilkan kegagalan, jangan tetap menampilkan status proteksi penuh. |
| Penyimpanan gagal/data rusak | `Status ujian tidak dapat disimpan` atau `Data sesi tidak dapat dibaca`. Tahan transisi, arahkan ke pengawas; tidak membuat attempt baru otomatis. |
| Pemulihan pengaturan tertunda | `Pengaturan perangkat belum selesai dipulihkan.` Beri jalur penanganan yang sesuai hasil implementasi; jangan mengklaim selesai dipulihkan. |
| Darurat/PIN tidak tersedia | Instruksi menghubungi pengawas dan mendahulukan kebutuhan darurat melalui perangkat/pengawas. Tidak ada bypass PIN di UI. |

Peringatan visual harus tersedia meski alarm/getaran tidak terdengar. Alarm diupayakan maksimal dua detik per kejadian, tidak berulang terus saat terkunci.

## 8. Aturan alur yang tidak boleh berubah lewat desain

- Startup memeriksa sesi aktif/terkunci/pemulihan sebelum membuka beranda atau mode guru. Berpindah mode tidak mengakhiri sesi siswa.
- Memulai sesi pertama tidak memerlukan PIN siswa.
- Counter bertambah hanya untuk event yang telah disepakati dan diuji; gangguan ambigu hanya dicatat.
- Pelanggaran 1 dan 2 memberi peringatan; pelanggaran 3 mengunci. Setelah pengawas melanjutkan, counter tetap dan setiap pelanggaran berikutnya langsung mengunci lagi. Gunakan `Pelanggaran: 3` atau `4`, bukan progres `4/3` atau indikator tiga nyawa yang direset.
- Mengunci mempertahankan WebView selama proses tersedia; UI tidak sengaja memuat ulang Form.
- PIN salah/batal mengikuti state terbaru, termasuk jika penguncian terjadi ketika dialog terbuka.
- Pengakhiran memerlukan PIN benar dan konfirmasi; state disimpan sebelum melepas proteksi.
- Riwayat adalah catatan lokal pada HP terkait, tanpa jawaban/PIN/isi notifikasi. Jika ditampilkan, pisahkan `Dihitung sebagai pelanggaran` dan `Gangguan tercatat`.
- Attempt berakhir disimpan tujuh hari; sesi aktif/terkunci tidak dihapus otomatis. UI tidak menjanjikan riwayat atau pembatasan ulang lintas instalasi/perangkat.

## 9. Kriteria review hasil Stitch

Checklist ini untuk memeriksa hasil desain; belum dinyatakan lulus sebelum mockup dirender dan diperiksa.

- [ ] Bahasa UI Indonesia konsisten; contoh data jelas merupakan data desain.
- [ ] Style Swiss konsisten: latar putih, tipografi hitam tegas, sumbu kiri selaras, radius kecil, dan pemisah garis; tanpa kartu mengambang atau kapsul dekoratif.
- [ ] Hierarki judul, kode, status, dan tindakan terbaca melalui ukuran/bobot teks serta jarak, tanpa bergantung pada warna. Header ujian tetap ringkas.
- [ ] Siswa dapat mengenali nama/kode sesi dan tindakan utama dengan cepat.
- [ ] Layar 360 dp dan teks besar tidak memotong label, kode, input PIN, atau tombol.
- [ ] Kontras, area sentuh, label aksesibel, fokus, dan urutan baca diperiksa.
- [ ] Soal dominan di layar aktif, tertutup opak saat terkunci, dan tidak tertutup tombol tetap.
- [ ] Peringatan, penguncian, gangguan koneksi, dan pemulihan proses tampak berbeda serta memiliki tindakan jelas.
- [ ] PIN tidak terlihat bersamaan dengan QR publik; salah/batal/jeda PIN tercakup.
- [ ] Kesiapan nyata, kegagalan simpan, serta pemulihan pengaturan tidak diberi status sukses palsu.
- [ ] Permintaan selesai, bukti submit Forms, dan sesi berakhir tidak disamakan.
- [ ] Tidak ada fitur di luar MVP atau kontrol yang menyiratkan bypass proteksi.
- [ ] Interaksi prototipe hanya simulasi; tidak dianggap membuktikan WebView, PIN, penyimpanan, atau keamanan Android bekerja.

## 10. Referensi

- [PRD sumber](E:/flutter/examseal/ExamSeal_PRD_MVP.md): kebutuhan dan batas perilaku ExamSeal.
- [Material 3](https://m3.material.io/foundations/): acuan pola interaksi dan aksesibilitas Android; tampilan komponen aplikasi mengikuti arahan Swiss di dokumen ini.
- [Android touch target size](https://support.google.com/accessibility/android/answer/7101858?hl=en-GB): area sentuh minimum dan jarak antaraksi.
- [GOV.UK Warning text](https://design-system.service.gov.uk/components/warning-text/): referensi pesan konsekuensi yang jelas.
