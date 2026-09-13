# PRD ExamSeal: MVP Uji Coba

Tanggal dokumen: 12 September 2026  
Target: APK siap dites dan uji satu kelas SMK, sekitar 30-40 siswa, selesai paling lambat 5 Oktober 2026. Tanggal ini bukan kewajiban rilis publik.  
Platform: Android, HP pribadi siswa, Flutter dengan Kotlin untuk kebutuhan native.  
Backend ExamSeal: tidak ada. Google Forms tetap membutuhkan layanan Google dan koneksi internet.

Keputusan dalam percakapan dan hasil sesi grilling menjadi dasar dokumen ini. Bagian 10 mencatat keputusan Q01-Q13 dari versi awal serta pekerjaan teknis yang masih perlu dibuktikan. Nomor Q di bagian tersebut mengacu ke PRD awal, bukan nomor pertanyaan wawancara. Kandidat teknologi tidak dianggap hasil pengujian atau jaminan dukungan.

## 1. Problem statement

Guru yang menjalankan ujian Google Forms pada HP pribadi siswa membutuhkan cara untuk membatasi navigasi dan menangani siswa yang meninggalkan ujian. Browser umum tidak menyediakan alur persetujuan pengawas untuk keluar, riwayat pelanggaran lokal, atau penguncian sesi sesuai aturan kelas.

Pihak yang terdampak:

- Guru dan pengawas harus memperhatikan sekitar 30-40 siswa sekaligus, termasuk memeriksa gangguan perangkat dan dugaan pelanggaran.
- Siswa yang mengikuti aturan dapat dirugikan oleh akses bantuan di luar ujian oleh peserta lain.
- Siswa yang mengalami panggilan masuk, jaringan putus, atau gangguan sistem dapat dirugikan jika semua kehilangan fokus dianggap sebagai pelanggaran.

ExamSeal menyediakan sesi ujian Google Forms dengan navigasi terbatas, proteksi layar, pengendalian notifikasi, deteksi pelanggaran, dan tindakan pengawas melalui PIN. Pengawas hadir selama ujian dan tetap menjadi pihak yang memutuskan kelanjutan ujian.

Validasi masalah, frekuensi kecurangan, dan besarnya pengurangan beban pengawas belum diukur. Pilot harus mengumpulkan bukti tersebut tanpa menganggap setiap event aplikasi sebagai kecurangan.

## 2. Target user dan dua persona

Target produk jangka panjang mencakup seluruh jenjang pendidikan. Pilot pertama dibatasi pada satu kelas SMK dengan sekitar 30-40 siswa, HP Android pribadi, dan pengawas yang hadir langsung. Tidak ada kewajiban mengumpulkan inventaris model HP atau versi Android peserta secara manual; pemeriksaan kesiapan dilakukan melalui aplikasi sebelum mulai. Pengujian efektivitas proteksi tetap menjadi tanggung jawab pengembang.

Persona berikut adalah persona kerja berdasarkan konteks penggunaan, belum merupakan hasil riset pengguna.

| Persona | Tugas utama | Kebutuhan | Hambatan yang perlu diuji |
|---|---|---|---|
| Guru/pengawas ujian | Menyiapkan Google Form, membagikan QR, memeriksa pelanggaran, dan menyetujui keluar | Persiapan singkat, satu sesi untuk satu pelaksanaan ujian, kontrol melalui PIN, status siswa yang mudah diperiksa di HP siswa | Antrean persetujuan untuk 30-40 siswa; gangguan teknis; menjaga PIN tetap diketahui pengawas |
| Siswa peserta ujian | Masuk ke sesi yang benar, mengerjakan dan mengirim jawaban, meminta persetujuan selesai | Scan yang mudah, alternatif galeri, aturan jelas, ujian tetap tersedia setelah gangguan sementara | Kamera bermasalah, jaringan tidak stabil, perbedaan Android, salah deteksi pelanggaran |

Guru dapat merangkap pengawas. Guru membuat sesi dan membagikan QR; aplikasi menghasilkan PIN acak lima digit per sesi. Siswa memindai QR yang dibagikan guru. Pilot menggunakan distribusi langsung dengan pengawas hadir. Aplikasi tidak membutuhkan akun dan belum memverifikasi identitas pembuat QR secara mandiri. Nama ujian dan kode sesi ditampilkan pada HP siswa agar dapat dibandingkan langsung dengan milik guru; ini pemeriksaan operasional, bukan autentikasi identitas pembuat QR.

Pilot ditujukan sebagai kontrol operasional dengan pengawas hadir. Perlindungan PIN dan pembatasan percobaan tetap wajib, tetapi ketahanan terhadap analisis QR/aplikasi pada perangkat siswa tidak dijanjikan sebelum rancangan verifikasi offline diuji.

## 3. Goals dan non-goals

### Goals

1. Guru dapat menyiapkan satu sesi ujian dengan Google Form, ID sesi, dan PIN pengawas, lalu membagikannya melalui QR.
2. Siswa dapat memulai pertama kali melalui QR tanpa PIN masuk.
3. Semua fitur MVP yang telah dipilih tersedia dalam pilot, termasuk pengendalian notifikasi.
4. Pelanggaran pertama dan kedua memberi peringatan; pelanggaran ketiga mengunci ujian untuk ditangani pengawas.
5. Keluar normal, melanjutkan sesi terkunci atau pemulihan setelah proses mati, dan mengulang sesi yang telah diakhiri selama masa retensi memerlukan PIN pengawas yang benar.
6. Status pengamanan bertahan saat aplikasi dibuka ulang selama data aplikasi masih tersedia. Riwayat percobaan berakhir disimpan tujuh hari; sesi aktif/terkunci tidak dihapus otomatis.
7. Gangguan jaringan dan panggilan masuk tidak otomatis menambah pelanggaran.
8. Pilot menghasilkan bukti kompatibilitas, ketepatan deteksi, dan beban kerja pengawas sebelum produk dianggap siap digunakan lebih luas.

### Non-goals MVP

- Backend ExamSeal, akun, student roster, autentikasi melalui server, dan sinkronisasi antarperangkat.
- Pembuatan soal, penyimpanan jawaban oleh ExamSeal, penilaian, dan pengganti Google Forms.
- Dashboard pengawas, pemantauan jarak jauh, remote unlock, dan keputusan nilai otomatis.
- Deteksi otomatis bahwa jawaban Google Forms berhasil dikirim.
- Subscription, pembayaran, pengelolaan sekolah, iOS, dan desktop.
- Jaminan antikecurangan 100%, pencegahan penggunaan perangkat kedua, atau ketahanan status terhadap penghapusan data aplikasi.
- Pengelolaan perangkat sekolah sebagai device owner/MDM pada MVP BYOD ini.

MVP hanya mendukung Form tanpa kewajiban login, tanpa upload file, tanpa kebutuhan membuka layanan luar, serta tanpa alur edit respons atau pengiriman ulang yang dapat diakses siswa. Timer ujian khusus belum menjadi komitmen scope dan tidak ditambahkan melalui revisi ini. Pergantian PIN massal saat ujian dan tombol keluar tanpa PIN tidak termasuk MVP.

## 4. User stories

| ID | User story |
|---|---|
| US01 | Sebagai guru, saya ingin memasukkan Google Form dan membuat sesi dengan PIN supaya satu pelaksanaan ujian mempunyai aturan keluar yang sama. |
| US02 | Sebagai guru, saya ingin menampilkan QR sesi supaya siswa dapat masuk tanpa mengetik URL. |
| US03 | Sebagai siswa, saya ingin memindai QR dengan kamera supaya dapat membuka ujian yang dibagikan guru. |
| US04 | Sebagai siswa yang kameranya bermasalah, saya ingin memilih gambar QR dari galeri supaya tetap dapat mengikuti ujian. |
| US05 | Sebagai siswa, saya ingin melihat aturan dan status kesiapan perangkat supaya mengetahui konsekuensi sebelum mulai. |
| US06 | Sebagai pengawas, saya ingin navigasi keluar dan tangkapan layar dibatasi supaya akses soal lebih terkendali selama sesi. |
| US07 | Sebagai siswa, saya ingin gangguan notifikasi dikendalikan supaya dapat mengerjakan ujian tanpa membuka aplikasi lain. |
| US08 | Sebagai siswa, saya ingin panggilan masuk dan jaringan putus ditangani dengan benar supaya gangguan teknis tidak otomatis menjadi pelanggaran. |
| US09 | Sebagai pengawas, saya ingin peringatan pelanggaran terlihat dan terdengar sesuai kemampuan perangkat supaya dapat memeriksa kejadian. |
| US10 | Sebagai pengawas, saya ingin memasukkan PIN untuk melanjutkan atau mengakhiri sesi terkunci supaya keputusan tetap berada pada pengawas. |
| US11 | Sebagai siswa, saya ingin meminta persetujuan selesai setelah mengirim jawaban supaya dapat keluar dengan prosedur yang jelas. |
| US12 | Sebagai pengawas, saya ingin status sesi bertahan setelah aplikasi dibuka ulang supaya pelanggaran tidak hilang hanya karena aplikasi ditutup. |
| US13 | Sebagai pengawas, saya ingin pengulangan sesi memerlukan PIN supaya siswa tidak langsung mendapatkan percobaan baru. |

## 5. Daftar fitur: MVP, v2, dan nanti

| Tahap | Fitur | Status |
|---|---|---|
| MVP | Teacher Mode: nama ujian, URL Google Form, ID/kode sesi, PIN acak lima digit, generate dan tampilkan QR | Wajib |
| MVP | Student Mode: scan kamera dan baca QR dari galeri | Wajib |
| MVP | Validasi QR, URL, dan navigasi WebView | Wajib |
| MVP | Pre-exam, aturan, dan pemeriksaan proteksi | Wajib |
| MVP | Google Forms tanpa kewajiban login dalam WebView | Wajib; pembatasan Form mengikuti FR03 |
| MVP | Proteksi screenshot dan konten pada tampilan tidak aman | Wajib, diuji per perangkat |
| MVP | Meredam gangguan notifikasi dan menyembunyikan banner/isi pada cakupan yang diuji | Wajib; tidak menjanjikan panel sistem tidak dapat dibuka |
| MVP | Deteksi pelanggaran, peringatan pertama/kedua, kunci pada ketiga | Wajib; event ambigu hanya dicatat, matriks pemicu masih perlu diuji |
| MVP | Alarm dan getaran singkat, maksimal dua detik per pelanggaran | Wajib sebagai upaya sesuai kemampuan perangkat; visual selalu tersedia |
| MVP | PIN untuk keluar, membuka keputusan pengawas, dan mengulang sesi | Wajib |
| MVP | Penyimpanan status dan riwayat pengamanan lokal | Wajib |
| MVP | Penanganan jaringan, gangguan sistem, dan pemulihan aplikasi | Wajib |
| v2 | Dashboard, pemantauan dan unlock jarak jauh, identitas sesi terverifikasi, ekspor laporan, sinkronisasi | Kandidat, belum menjadi komitmen; beberapa membutuhkan backend |
| Nanti | Pengelolaan sekolah, billing/subscription, dukungan platform tambahan, pengelolaan perangkat sekolah | Kandidat, belum diprioritaskan |

Tidak ada fitur MVP yang dipindahkan ke v2 untuk mengejar tanggal uji coba tanpa keputusan perubahan scope. Ketidakmampuan memenuhi definisi blokir notifikasi pada perangkat tertentu harus dilaporkan sebagai batas dukungan.

## 6. Functional requirement per fitur MVP

### FR01. Pembuatan sesi oleh guru

- Guru memasukkan nama ujian dan URL Google Form. Aplikasi membuat ID sesi unik, kode sesi yang mudah dibandingkan, serta PIN acak lima digit; satu sesi mewakili satu pelaksanaan ujian dan dipakai seluruh peserta kelas tersebut.
- QR yang ditampilkan kembali untuk sesi yang sama harus mempertahankan ID dan konfigurasi sesi. Tindakan membuat sesi baru harus dibedakan dari menampilkan ulang QR.
- Aturan keamanan inti tidak dapat diubah guru atau siswa: proteksi layar aktif, navigasi keluar dibatasi, dan ambang penguncian awal tiga pelanggaran.
- QR memuat versi format, ID/kode sesi, nama ujian, referensi Form, dan bahan verifikasi PIN sesuai rancangan keamanan yang diuji. PIN mentah tidak boleh dimasukkan ke QR.
- Membuka Teacher Mode tidak dapat membatalkan atau mengganti sesi siswa yang masih aktif/terkunci pada HP yang sama.
- Guru dapat mengakses ulang sesi dan melihat kembali PIN di HP pembuat setelah autentikasi perangkat. Bahan PIN disimpan terlindungi; mekanisme penyimpanan dan verifikasi offline harus diuji sebelum pilot.
- Guru menyimpan salinan PIN secara aman sebelum ujian. MVP tidak menyediakan pergantian PIN massal di HP peserta. Bila PIN bocor, kontrol sesi tidak lagi dianggap dapat dipercaya; pengawas menghentikan pelaksanaan sesi dan menentukan penggantinya.
- Setiap pelaksanaan ujian berikutnya menggunakan sesi baru. Guru tidak memakai kembali QR lama setelah masa retensinya berakhir.

Penerimaan: generate QR, tampilkan ulang, lalu scan pada dua HP menghasilkan ID dan Form yang sama. Pengulangan tampilan QR tidak membuat sesi baru. URL salah tidak menghasilkan QR siap ujian.

### FR02. Scan kamera, galeri, dan validasi QR

- Siswa dapat memindai kamera atau memilih gambar QR dari galeri. Kegagalan kamera tidak menghapus jalur galeri.
- Pembatalan pemilihan gambar atau penolakan izin sebelum ujian tidak dihitung sebagai pelanggaran.
- Payload harus memiliki versi yang didukung dan field sesi yang lengkap. Scan ganda akibat beberapa frame kamera tidak boleh membuat dua sesi.
- Gambar tanpa QR, format rusak, dan lebih dari satu kandidat QR yang tidak dapat dipilih dengan jelas menghasilkan pesan kesalahan yang dapat ditindaklanjuti.
- URL Google Form saja tidak memuat informasi yang cukup untuk PIN per sesi. Student Mode mensyaratkan payload sesi lengkap; QR URL biasa ditolak dengan arahan meminta QR sesi dari guru. Tidak ada tambahan kompatibilitas QR lama yang melewati validasi payload.
- Jika sesi lokal sudah ada, hasil scan harus diarahkan ke status tersimpan sebelum membuka Form. Payload dengan ID sama tetapi URL atau data verifikasi PIN berbeda harus ditolak, bukan menimpa data sesi.

Penerimaan: kedua jalur scan dapat membuka pre-exam untuk QR sah; input tidak sah tetap di alur scan dengan pesan sebab kegagalan. Scan sesi terkunci tidak membuka soal.

### FR03. Validasi URL dan WebView terbatas

- Gunakan HTTPS dan pemeriksaan struktur URL. Host awal yang diperbolehkan adalah `forms.gle` dan `docs.google.com` dengan jalur Google Forms yang sesuai.
- Resolusi short link harus memeriksa tujuan redirect. Host yang hanya mengandung teks `google.com`, skema selain HTTPS, dan tujuan di luar allowlist harus ditolak.
- Form dibuka dalam WebView tanpa address bar, copy URL, share URL, menu browser, atau tombol membuka browser luar.
- Navigasi halaman utama harus tetap berada pada Form dan endpoint yang diperlukan untuk menjalankannya. Kebijakan navigasi halaman utama harus dibedakan dari pemuatan aset/subresource Google yang diperlukan.
- Link luar, new window, intent aplikasi, download yang tidak didukung, dan perpindahan ke Form lain tidak boleh membuka aplikasi lain secara otomatis.
- Nama, kelas, soal, jawaban, dan submit ditangani Google Forms. Aplikasi tidak menambahkan identitas siswa sendiri.
- Form yang mewajibkan login atau fitur yang belum didukung tidak boleh dialihkan diam-diam ke browser umum. Tampilkan sebab dan arahkan siswa meminta bantuan pengawas.
- Form pilot tidak boleh membutuhkan login, upload file, atau layanan luar. Alur edit respons dan Kirim respons lain tidak boleh dapat diakses siswa di dalam sesi yang sama; PIN untuk mengulang ExamSeal saja tidak memenuhi pembatasan ini.
- Sebelum QR dibagikan, guru menjalankan satu percobaan lengkap sampai submit melalui ExamSeal dan memeriksa pembatasan di atas. Form tidak diubah selama ujian berlangsung. Validasi URL saja tidak menyatakan Form siap ujian.

Penerimaan: Form pilot dapat dikerjakan dan dikirim; URL peniru serta redirect keluar ditolak; tautan keluar tidak meluncurkan aplikasi lain. Allowlist lengkap diuji dengan Form pilot, tidak ditebak dari dua domain awal saja.

### FR04. Pre-exam dan mulai sesi

- Tampilkan nama ujian, kode sesi, aturan tiga pelanggaran, kebutuhan PIN untuk keluar, alarm/getaran, serta status nyata proteksi perangkat. Pengawas membandingkan kode tersebut dengan sesi resmi.
- Pemeriksaan izin kamera/galeri dan pengaturan khusus notifikasi dilakukan sebelum sesi aktif sejauh memungkinkan.
- Sesi pertama yang sah dapat dimulai tanpa PIN siswa. State aktif harus tersimpan dan proteksi layar aktif sebelum soal ditampilkan.
- UI tidak boleh menyatakan proteksi notifikasi aktif ketika akses atau kemampuan OS belum tersedia.
- Pemeriksaan kesiapan berlangsung melalui aplikasi, tanpa meminta siswa/guru mengisi model HP atau versi Android. Hasil pemeriksaan izin tidak boleh dianggap sebagai bukti efektivitas seluruh proteksi; bukti tersebut berasal dari pengujian pengembang.
- Perangkat atau izin yang tidak memenuhi proteksi wajib mendapat status belum siap dan tidak dapat mulai. Pengawas menyediakan ujian alternatif; tidak ada pengecualian yang meloloskan proteksi berkurang sebagai terproteksi penuh.

Penerimaan: tombol mulai tidak menghasilkan soal tanpa state sesi yang tersimpan; informasi readiness sesuai hasil pemeriksaan perangkat; pembatalan sebelum mulai tidak membuat pelanggaran.

### FR05. Deteksi dan pencatatan pelanggaran

- Counter awal sesi adalah nol; ambang penguncian awal adalah tiga.
- Pelanggaran pertama menampilkan peringatan, alarm, dan getaran sesuai kemampuan perangkat. Pelanggaran kedua menampilkan peringatan terakhir.
- Ketiga mengubah state menjadi terkunci dan menampilkan instruksi memanggil pengawas.
- Satu kejadian pengguna tidak boleh dihitung beberapa kali karena beberapa callback lifecycle. Event perlu identitas/korelasi untuk mencegah duplikasi.
- Kehilangan fokus saja tidak cukup sebagai bukti pelanggaran. Jaringan putus dan panggilan masuk tidak otomatis menambah counter. UI PIN, peringatan milik aplikasi, serta dialog yang memang diminta aplikasi harus dikenali dalam klasifikasi.
- Catatan lokal menyimpan jenis event, waktu, apakah event dihitung, counter setelah event, dan hasil tindakan pengawas bila ada. Jangan menyebut catatan ini sebagai bukti pasti kecurangan.
- Event ambigu dicatat tanpa menambah counter. Hanya pemicu yang disepakati dalam matriks deteksi dan terbukti melalui pengujian yang dihitung. Daftar pemicu konkret, toleransi/debounce, dan perilaku lintas vendor masih merupakan pekerjaan validasi teknis sebelum pilot.

Penerimaan: tiga event terpisah yang telah disetujui dalam matriks deteksi menghasilkan urutan peringatan, peringatan terakhir, lalu terkunci. Satu aksi yang memicu beberapa callback hanya dihitung sekali. Skenario panggilan masuk dan putus koneksi tidak otomatis menambah counter.

### FR06. Sesi terkunci dan keputusan pengawas

- Saat terkunci, konten soal disembunyikan dan tidak dapat diinteraksikan. Sesi WebView dipertahankan selama proses masih tersedia; mengunci tidak boleh sengaja me-reload Form.
- Proteksi ujian tetap diterapkan saat terkunci. Siswa hanya mendapat alur meminta bantuan dan memasukkan PIN pengawas.
- PIN benar membuka tindakan Lanjutkan Ujian dan Akhiri Ujian. PIN salah atau pembatalan mempertahankan status terkunci.
- Lanjutkan menggunakan sesi yang sama dan mempertahankan riwayat. Penguncian tidak menetapkan nilai nol atau gagal secara otomatis.
- Akhiri menyimpan status berakhir dan tindakan pengawas sebelum melepaskan proteksi.
- Lanjutkan mempertahankan counter. Setelah penguncian karena pelanggaran ketiga, setiap pelanggaran berikutnya langsung mengunci kembali; pengawas tidak memberi tiga kesempatan baru.

Penerimaan: siswa tidak dapat mengakses soal dengan membatalkan dialog, menekan Back, atau memindai ulang QR yang sama. PIN benar memungkinkan pengawas memilih satu tindakan; satu autentikasi tidak memberi akses permanen untuk keluar berikutnya.

### FR07. Selesai normal, PIN, dan pengulangan

- Setelah submit di Google Forms, Exam Mode tetap aktif. Aplikasi tidak mengklaim sudah menerima bukti submit otomatis.
- Siswa menekan End Exam, tetap di tempat, dan mengangkat tangan. Pengawas mendatangi siswa, memeriksa bukti submit, lalu memasukkan PIN langsung agar PIN tidak tersebar.
- Jika layar terkunci setelah submit, guru memeriksa respons di Google Forms melalui perangkatnya. Jika belum dapat dipastikan, pengawas dapat melanjutkan sesi dengan PIN untuk pemeriksaan halaman; aplikasi tidak menyimpulkan submit berhasil dari state lokal.
- PIN benar dan konfirmasi tindakan mengakhiri sesi. PIN salah atau pembatalan mempertahankan state pengamanan terbaru dengan proteksi tetap aktif; jika sesi sudah terkunci, siswa tidak kembali ke soal.
- State berakhir tidak boleh dianggap bukti bahwa Google Forms menerima jawaban. Sesi yang diakhiri pengawas akibat pelanggaran juga berstatus berakhir dengan alasan berbeda.
- Selama masa retensi, scan ulang sesi yang sudah berakhir memerlukan PIN untuk mengulang. Persetujuan membuat attempt baru dengan counter nol; riwayat attempt lama dipertahankan sampai masa retensinya berakhir.
- Jaminan pembatasan pengulangan lokal berlaku selama data sesi masih disimpan dalam masa retensi tujuh hari setelah berakhir. Setelah penanda sesi dihapus, aplikasi tidak menjanjikan dapat mengenali percobaan lama; guru wajib memakai sesi baru untuk pelaksanaan berikutnya.
- Persetujuan PIN harus terikat pada sesi dan tindakan yang diminta. PIN sesi lain tidak memberikan izin.
- Lima kesalahan PIN berturut-turut pada HP siswa memberi jeda 30 detik sebelum percobaan berikutnya. Jeda membatasi percobaan melalui aplikasi, bukan pengganti pengamanan verifier offline. Uji pembukaan ulang aplikasi agar tidak menghapus pembatasan yang masih berlaku.
- Otorisasi berlaku untuk satu tindakan pada sesi/attempt yang diminta; tidak memberi izin permanen dan tidak dipulihkan setelah proses mati. Pergantian PIN massal tidak tersedia. PIN terlupa ditangani dengan akses ulang terlindungi di HP pembuat atau salinan aman milik guru; jika tetap tidak tersedia, ikuti prosedur darurat dan ujian alternatif.

Penerimaan: mulai pertama tidak meminta PIN; keluar normal dan pengulangan sesi yang sama meminta PIN; PIN salah tidak mengubah state. Uji aplikasi dibuka ulang sebelum dan setelah transisi untuk memastikan hasil yang sama. Jika pelanggaran ketiga terjadi saat dialog PIN terbuka, pembatalan dialog harus tetap menghasilkan sesi terkunci.

### FR08. Proteksi screenshot dan layar

- Terapkan proteksi layar Android sebelum konten soal terlihat; pertahankan selama aktif, peringatan, PIN, dan terkunci.
- Gunakan kemampuan native seperti `FLAG_SECURE` untuk mencegah tangkapan konten pada jalur screenshot dan display tidak aman yang didukung Android. Proteksi tersebut memiliki batasan dan perlu pengujian perangkat. [Android: secure sensitive activities](https://developer.android.com/security/fraud-prevention/activities)
- Uji screenshot sistem, preview recent apps, casting/recording yang tersedia pada perangkat uji, dan pergantian layar internal agar tidak ada frame soal terbuka tanpa proteksi.
- Memblokir screenshot tidak otomatis berarti setiap percobaan screenshot dapat dideteksi atau dihitung sebagai pelanggaran. Penghitungan mengikuti klasifikasi event pada FR05: hanya pemicu yang terbukti yang dihitung, event ambigu dicatat.
- Setelah sesi berakhir melalui prosedur sah, proteksi khusus ujian dilepas.

Penerimaan: konten soal tidak muncul pada hasil tangkapan di matriks perangkat/jalur yang dinyatakan didukung. Perangkat yang gagal harus tercatat sebagai gagal dukungan, tidak dilaporkan lulus secara umum.

### FR09. Blokir notifikasi

Status: wajib MVP. Blokir berarti meredam suara/getaran gangguan notifikasi serta menyembunyikan banner/isi sesuai cakupan yang dibuktikan pada perangkat yang didukung. Panel sistem yang sama sekali tidak dapat dibuka bukan janji pilot.

- Pengendalian harus berlangsung selama sesi aktif dan terkunci, dengan status yang dapat diperiksa siswa/pengawas.
- Perangkat yang tidak memenuhi hasil proteksi wajib menggunakan ujian alternatif. Izin ditolak sebelum mulai menghasilkan status belum siap; pencabutan atau kegagalan proteksi saat ujian harus terlihat dan ditangani pengawas tanpa menghapus state sesi atau mengklaim proteksi tetap penuh.
- Implementasi yang memakai DND membutuhkan akses Notification Policy dari pengguna. Aplikasi memeriksa akses sebenarnya sebelum menyatakan fitur aktif. [Android: NotificationManager](https://developer.android.com/reference/android/app/NotificationManager#isNotificationPolicyAccessGranted())
- Kemampuan menyembunyikan notifikasi berbeda menurut versi Android. API 28 menyediakan pengaturan supresi tambahan, termasuk banner dan daftar notifikasi yang terkena DND. Ini tidak sama dengan menonaktifkan panel notifikasi. [Android: NotificationManager.Policy](https://developer.android.com/reference/android/app/NotificationManager.Policy#SUPPRESSED_EFFECT_NOTIFICATION_LIST)
- Pada aplikasi yang menargetkan Android API 35+, perubahan DND berkontribusi melalui aturan milik aplikasi. Selesai ujian harus menonaktifkan kontribusi ExamSeal tanpa mematikan aturan DND pengguna/aplikasi lain. [Android 15: DND changes](https://developer.android.com/about/versions/15/behavior-changes-15#dnd-changes)
- Penolakan/pencabutan izin, perubahan pengaturan oleh pengguna, dan aturan yang masih aktif setelah crash harus ditangani secara terlihat. Jangan menyatakan perlindungan tetap aktif tanpa pemeriksaan ulang.
- DND yang sangat ketat dapat membungkam alarm/getaran. Kebijakan yang dipilih harus diuji bersama FR10. [Android: interruption filters](https://developer.android.com/reference/android/app/NotificationManager#INTERRUPTION_FILTER_NONE)
- Pemblokiran panel dan navigasi sistem penuh tidak boleh dijanjikan melalui DND. Lock task yang dikelola memiliki kebutuhan DPC/allowlist, sementara screen pinning biasa dapat ditinggalkan pengguna. [Android: lock task mode](https://developer.android.com/work/dpc/dedicated-devices/lock-task-mode)

Penerimaan: gangguan suara/getaran dan banner/isi ditekan pada cakupan yang dinyatakan didukung. Hasil aktual, pengecualian panggilan/notifikasi sistem, ketukan notifikasi, serta pemberian/penolakan/pencabutan izin dicatat dalam pengujian pengembang. Panel sistem dapat tetap diakses sesuai batas BYOD; perlindungan isi notifikasi tetap harus diuji. Alarm ExamSeal mengikuti kemampuan perangkat dan FR10; proteksi notifikasi tidak boleh dinyatakan lulus hanya karena alarm terdengar. Kegagalan cakupan wajib menghasilkan status tidak didukung.

### FR10. Alarm dan getaran pelanggaran

- Peringatan visual harus tetap tersedia walaupun audio/getaran tidak dapat dijalankan.
- Aplikasi mencoba memainkan alarm pada tingkat yang diizinkan perangkat. Jangan menjanjikan volume 100% atau suara selalu keluar dari speaker.
- Jika volume diubah, simpan kondisi yang diperlukan dan pulihkan perubahan milik aplikasi setelah alarm/sesi selesai tanpa menimpa perubahan baru pengguna secara sembarangan.
- Alarm dan getaran harus berhenti ketika rangkaian peringatan selesai; tidak boleh terus berbunyi setelah sesi berakhir.
- Uji bersama DND, mode senyap, headset/Bluetooth, panggilan aktif, dan kondisi perangkat tanpa getaran.
- Bunyi dan getaran berlangsung singkat, maksimal dua detik pada tiap pelanggaran, tanpa pengulangan terus-menerus. Saat terkunci, tampilkan instruksi memanggil pengawas. Keterdengaran alarm bukan satu-satunya jalur penanganan; jika DND/rute audio membatasinya, peringatan visual dan prosedur pengawas tetap berlaku.

Penerimaan: setiap event yang sah memicu peringatan visual dan upaya audio/getaran; hasil aktual tercatat dalam pengujian perangkat. Kegagalan audio tidak boleh menghasilkan status seolah alarm sudah terdengar.

### FR11. Jaringan dan pemulihan halaman

- Koneksi putus menampilkan status gangguan tanpa mengakhiri sesi atau menambah pelanggaran.
- Pertahankan halaman yang masih tersedia. Jangan melakukan reload otomatis yang berisiko membuang isian.
- Kembalinya jaringan tidak otomatis berarti submit berhasil. Keberhasilan pengiriman tetap mengikuti halaman Google Forms dan pemeriksaan pengawas.
- Jika halaman gagal dimuat, sediakan percobaan ulang yang jelas. Jika reload dapat membuang isian, tampilkan konsekuensinya dan minta pemeriksaan pengawas sebelum pemulihan yang berisiko.
- Aplikasi tidak menyediakan antrean jawaban offline atau cadangan isian milik ExamSeal.
- Google mendokumentasikan autosave draft untuk pengguna yang masuk ke akun Google dan menyatakan autosave tidak berjalan saat offline. Untuk penggunaan Form tanpa login, PRD ini tidak menjanjikan pemulihan jawaban setelah proses WebView hilang. Form berlogin berada di luar cakupan pilot. [Google Forms: autosave response progress](https://support.google.com/docs/answer/10952360?hl=en)

- Setelah proses mati/crash/reboot, melanjutkan ujian memerlukan PIN dan pemeriksaan pengawas tanpa otomatis menambah pelanggaran. Jika isian hilang, pengawas berwenang menentukan ujian alternatif dan kompensasi waktu. Prosedur dan kewenangan ini harus tersedia sebelum pilot.

Penerimaan: putus-sambung jaringan mempertahankan state pengamanan dan counter. Pemulihan isian diuji terpisah dari pemulihan state; keduanya tidak boleh digabung dalam satu klaim berhasil.

### FR12. Penyimpanan lokal dan pemulihan sesi

- Simpan ID/config sesi, state, counter, event, dan tindakan pengawas pada penyimpanan privat aplikasi. Tidak membutuhkan server ExamSeal.
- Transisi penting harus tersimpan sebelum UI memberi akses yang baru. Penulisan yang gagal tidak boleh menghasilkan state baru yang terlihat sah.
- Saat diluncurkan ulang, baca sesi aktif/terkunci sebelum menampilkan Home, Teacher Mode, atau Form baru. Sesi terkunci tetap terkunci.
- Peluncuran ulang juga harus menyelesaikan pelepasan proteksi/perubahan OS milik aplikasi yang tertunda setelah sesi berakhir. State berakhir tidak boleh menyebabkan pemulihan pengaturan yang belum selesai diabaikan.
- Bila proses masih hidup, gangguan sementara tidak perlu membuat sesi baru. Jika proses hilang, pulihkan catatan dan tahan akses soal sampai pengawas memasukkan PIN untuk melanjutkan atau mengakhiri. Counter tidak otomatis bertambah; pemulihan state tidak menjamin pemulihan isian Form.
- Data hilang/rusak yang terdeteksi tidak boleh diam-diam dipulihkan menjadi counter nol dan sesi baru yang dipercaya.
- Hapus data, instal ulang, pemulihan backup, dan pindah HP berada pada batas penyimpanan lokal. Tanpa identitas dan server, aturan lintas instalasi/perangkat tidak dapat dijanjikan.
- Jangan menyimpan isi jawaban, isi notifikasi, rekaman layar, atau kredensial Google dalam log ExamSeal. Penyimpanan/cache WebView tetap perlu dikaji terpisah dari data aplikasi yang dirancang sendiri.
- Riwayat attempt yang berakhir disimpan tujuh hari sejak waktu berakhir, lalu dihapus otomatis. Sesi aktif/terkunci tidak boleh dihapus oleh retensi. Data sesi/bahan verifikasi yang masih diperlukan attempt aktif atau masa retensi attempt lain tetap dipertahankan; mekanisme pembersihan harus diuji bersama pemulihan pengaturan yang masih tertunda.
- Setelah seluruh data pengenal sesi melewati retensi dan dihapus, pembatasan pengulangan sesi lama tidak dijamin. Ini batas produk yang diterima, bukan bukti bahwa sesi belum pernah diikuti.
- Pengawas mencatat kejadian yang diperlukan untuk evaluasi sebelum riwayat dihapus. Pembersihan data WebView dibedakan dari riwayat pengamanan dan hanya dilakukan setelah pengiriman jawaban diperiksa. Mekanisme backup Android dan pembersihan storage/WebView masih perlu ditetapkan serta diuji secara teknis.

Penerimaan: tutup/buka aplikasi tidak menghapus counter atau kunci; kegagalan simpan tidak memberi jalan keluar tanpa izin; crash diuji sebelum dan sesudah perubahan state. Uji khusus proses mati setelah state berakhir tersimpan tetapi sebelum proteksi/pengaturan dipulihkan. Hapus data diuji sebagai batas produk, bukan diklaim lulus persistensi.

### Prosedur darurat dan ujian alternatif

- Kebutuhan darurat untuk memakai HP didahulukan. Gunakan prosedur melalui perangkat dan pengawas; MVP tidak menambahkan tombol keluar tanpa PIN dan tidak menjanjikan sistem Android tidak dapat ditinggalkan.
- Keluar melalui perangkat dalam keadaan darurat tidak otomatis menjadi pengakhiran sesi yang sah. Saat kembali ke aplikasi, sesi memerlukan pemeriksaan dan PIN pengawas sebelum melanjutkan; catatan yang tersedia dipertahankan dan gangguan tidak otomatis dianggap pelanggaran.
- Pengawas menangani PIN yang tidak tersedia, kegagalan storage, data rusak/hilang, atau perpindahan HP melalui penghentian operasional dan ujian alternatif. Aplikasi tidak mengklaim dapat memulihkan otorisasi atau riwayat lintas instalasi/perangkat.
- Satu guru penanggung jawab berwenang menentukan kelanjutan, ujian alternatif, serta kompensasi waktu bila jawaban hilang akibat gangguan. Prosedur ini dijelaskan sebelum uji kelas.

### Alur state yang harus konsisten

Dialog PIN dan peringatan adalah lapisan UI di atas state pengamanan yang tersimpan. Deteksi tetap berjalan sesuai klasifikasi event yang sah selama dialog terbuka. Menutup dialog atau memulihkan aplikasi harus membaca state terbaru; dialog tidak dapat mengembalikan state lama atau menyimpan otorisasi PIN setelah proses mati.

| State awal | Pemicu | State/hasil berikutnya |
|---|---|---|
| Belum mengikuti sesi | QR sah dan pemeriksaan siap | Pre-exam |
| Pre-exam | Mulai pertama | Aktif, tanpa PIN |
| Aktif | Pelanggaran pertama/kedua | Peringatan, lalu aktif |
| Aktif | Pelanggaran ketiga | Terkunci |
| Aktif | Permintaan End Exam | Tetap aktif dengan dialog PIN, proteksi tetap aktif |
| Aktif dengan dialog PIN keluar | PIN benar dan konfirmasi tindakan sesuai state terbaru | Berakhir |
| Dialog PIN keluar terbuka | PIN salah/batal | Ikuti state terbaru: aktif atau terkunci |
| Aktif dengan dialog PIN keluar | Pelanggaran ketiga | Terkunci; dialog tidak dapat membatalkan penguncian |
| Terkunci | PIN benar + Lanjutkan | Aktif pada sesi yang sama, counter tetap; jika sudah mencapai tiga, pelanggaran berikutnya langsung mengunci |
| Terkunci | PIN benar + Akhiri | Berakhir |
| Terkunci | PIN salah/batal atau scan ulang | Tetap terkunci |
| Berakhir, data masih dalam retensi | Scan sesi yang sama | PIN untuk attempt baru dengan counter nol; riwayat lama mengikuti retensi |
| Aktif/terkunci | Jaringan putus | State pengamanan tetap, status koneksi berubah |
| Terkunci | Aplikasi dibuka ulang | Tetap terkunci |
| Aktif | Proses hilang lalu dibuka ulang | Pulihkan catatan; tahan akses soal sampai PIN dan keputusan pengawas, tanpa menambah counter otomatis |
| Aktif/terkunci | Kembali setelah keluar darurat | Pemeriksaan dan PIN pengawas diperlukan; bukan pengakhiran sah otomatis |
| Berakhir | Tujuh hari sejak berakhir | Hapus riwayat yang jatuh tempo; jangan hapus data yang masih dibutuhkan sesi aktif/terkunci |

### Kompatibilitas dan batas penyelesaian teknis

Keinginan mendukung Android serendah mungkin belum menetapkan versi minimum yang dapat dijamin. Dokumentasi Flutter saat diperiksa mencantumkan API 24 sebagai batas bawah dukungan; paket `webview_flutter` dan `image_picker` yang diperiksa juga mencantumkan SDK 24+. Android 7.0/API 24 adalah kandidat awal, bukan janji kompatibilitas seluruh fitur. [Flutter supported platforms](https://docs.flutter.dev/reference/supported-platforms), [webview_flutter](https://pub.dev/packages/webview_flutter), [image_picker](https://pub.dev/packages/image_picker)

Versi Flutter, plugin, dependency native, minimum OS final, dan cakupan dukungan harus dikunci bersama pengujian proteksi notifikasi oleh pengembang. Tidak ada inventaris manual HP peserta atau kewajiban siswa mengumpulkan model/versi OS. Aplikasi memeriksa kesiapan sebelum mulai; pengembang tetap mencatat konfigurasi perangkat uji sebagai bukti dukungan. Tidak cukup membuktikan APK dapat diinstal atau izin diberikan: seluruh alur wajib harus lulus pada konfigurasi yang dinyatakan didukung.

## 7. Sketsa data model

Model ini bersifat logis. Pilihan library penyimpanan, enkripsi, algoritma verifikasi PIN, dan format payload final belum ditetapkan.

| Entitas | Lokasi | Field kunci |
|---|---|---|
| ExamSession | HP guru, payload QR, salinan pada HP siswa | `sessionId`, `sessionCode`, `examName`, `schemaVersion`, `formUrl`, `createdAt`, `securityPolicyVersion`, `initialViolationLimit=3` |
| PinVerificationMaterial | Payload QR dan penyimpanan siswa | `sessionId`, `scheme`, `parameters`, `saltIfRequired`, `verifier`; rancangan offline masih harus diuji, tanpa PIN mentah |
| TeacherSessionSecret | HP pembuat sesi | `sessionId`, `protectedPinMaterial`; PIN acak lima digit, akses ulang melalui autentikasi perangkat |
| LocalAttempt | HP siswa | `attemptId`, `sessionId`, `attemptNumber`, `state`, `violationCount`, `startedAt`, `endedAt`, `endReason`, `updatedAt` |
| SessionEvent | HP siswa | `eventId`, `attemptId`, `eventType`, `occurredAt`, `countedAsViolation`, `counterAfter`, `correlationId` |
| SupervisorAction | HP siswa | `actionId`, `attemptId`, `actionType`, `authorizedAt`, `result`; tanpa PIN atau klaim identitas guru terverifikasi |
| ProtectionState | HP siswa | `attemptId`, `secureWindowState`, `notificationProtectionState`, `notificationAccessGranted`, `ownedRuleIdIfAny`, `restoreDataIfNeeded`, `restorePending`, `lastCheckedAt` |

Relasi: satu ExamSession memiliki beberapa LocalAttempt; satu LocalAttempt memiliki banyak SessionEvent dan SupervisorAction. Data percobaan berada di masing-masing HP siswa, tanpa agregasi kelas otomatis.

Invariant data:

- ID sesi yang sudah dikenal tidak dapat mengganti URL atau bahan verifikasi PIN secara diam-diam.
- Keputusan pengawas terikat pada satu sesi/percobaan dan satu tindakan.
- Berakhir berarti Exam Mode berakhir; bukan bukti submit atau nilai.
- Tidak ada entitas akun siswa, roster, jawaban ujian, atau hasil nilai di storage ExamSeal.
- QR dan verifier yang dapat dibaca siswa membutuhkan rancangan keamanan offline. Keberadaan hash/verifier dan jeda percobaan PIN di UI tidak boleh dianggap cukup untuk membuktikan keamanan PIN. Pilot mengandalkan guru untuk membagikan serta memeriksa kode sesi yang benar; ID/kode sesi tidak memverifikasi identitas pembuatnya.
- Riwayat attempt berakhir mengikuti retensi tujuh hari; data yang diperlukan sesi aktif/terkunci tetap tersedia. Jaminan pengulangan lokal berakhir setelah penanda sesi dihapus.

## 8. Edge case dan failure state

| Kasus | Perilaku yang diwajibkan atau keputusan yang tersisa |
|---|---|
| Kamera rusak/izin ditolak | Sediakan jalur galeri; tanpa pelanggaran sebelum mulai |
| Galeri dibatalkan/gambar tidak valid | Kembali ke pemilihan/scan dengan pesan yang jelas |
| QR URL biasa/payload tidak lengkap | Tolak dan minta QR sesi lengkap dari guru; jangan memulai sesi tanpa PIN |
| Redirect short link ke situs lain | Tolak; jangan membuka browser luar |
| Form ditutup, dihapus, atau meminta login | Tampilkan gangguan; jangan menyebut siap ujian atau melepas proteksi otomatis; gunakan bantuan pengawas/ujian alternatif |
| ID sama, URL/PIN berbeda | Tolak perubahan payload dan pertahankan sesi lokal |
| QR bukan berasal dari distribusi guru | Pengawas membandingkan nama ujian/kode sesi pada HP siswa dengan milik guru; identitas pembuat tidak terverifikasi secara mandiri |
| Siswa memindai sesi lain saat masih aktif/terkunci | Jangan mengganti sesi yang belum diakhiri sah |
| Internet hilang saat mengerjakan/submit | Counter tetap; tampilkan status; jangan mengklaim submit berhasil |
| Panggilan, dialog OS, perubahan fokus | Tidak otomatis menjadi pelanggaran; event ambigu dicatat tanpa menambah counter |
| Home/Recent Apps, split screen, notification tap | Hanya dihitung jika masuk matriks pemicu yang disepakati dan terbukti dalam pengujian |
| Screenshot/recording | Proteksi diuji per perangkat; upaya screenshot tidak otomatis dapat dideteksi |
| DND ditolak/dicabut atau tidak efektif | Sebelum mulai: belum siap dan ujian alternatif; saat ujian: tampilkan kegagalan, pertahankan state, minta penanganan pengawas |
| DND meredam alarm/getaran | Visual tetap ada; alarm adalah upaya maksimal dua detik sesuai kemampuan perangkat, bukan jaminan terdengar |
| Bluetooth/headset tersambung | Uji rute audio aktual; jangan mengklaim pengawas pasti mendengar |
| PIN salah berulang atau pengawas lupa PIN | Lima kesalahan berturut-turut: jeda 30 detik. Guru melihat PIN melalui autentikasi perangkat/salinan aman; jika tidak tersedia, prosedur darurat/alternatif |
| PIN diketahui siswa lain | Pengawas menghentikan pelaksanaan sesi dan menentukan pengganti; tidak ada pergantian PIN massal |
| Pengawas melanjutkan setelah pelanggaran ketiga | Counter/riwayat tetap; setiap pelanggaran berikutnya langsung mengunci |
| App crash, proses dimatikan OS, reboot | Pulihkan catatan, minta PIN dan pemeriksaan pengawas; tanpa pelanggaran otomatis. Isian hilang: alternatif/kompensasi waktu |
| Storage penuh/penulisan gagal | Jangan melakukan transisi yang membutuhkan state tersimpan; tampilkan kegagalan |
| Data aplikasi dihapus/HP diganti | Persistensi lintas instalasi/perangkat tidak dijamin; pengawas menentukan penanganan dan ujian alternatif |
| Banyak siswa meminta selesai bersamaan | Siswa tetap di tempat dan mengangkat tangan; pengawas mendatangi siswa. Catat total waktu penyelesaian dan antrean terlama |
| Gangguan darurat atau pengawas tidak dapat memasukkan PIN | Dahulukan kebutuhan darurat melalui perangkat/pengawas; tidak ada tombol keluar tanpa PIN. Kembali ke aplikasi memerlukan pemeriksaan dan PIN |
| Terkunci setelah submit | Guru memeriksa respons pada perangkatnya atau membuka kembali sesi dengan PIN untuk pemeriksaan; bukan bukti submit otomatis |
| Kirim respons lain/edit respons di Form | Tidak boleh dapat diakses dalam Form pilot; guru memeriksa alur sampai submit sebelum membagikan QR |
| Riwayat melewati tujuh hari | Hapus otomatis data yang jatuh tempo; jangan menghapus sesi aktif/terkunci. QR lama tidak boleh dipakai untuk pelaksanaan berikutnya |

## 9. Success metrics dan definisi selesai

APK siap dites dan uji satu kelas SMK harus selesai paling lambat 5 Oktober 2026. Pilot pertama dipakai untuk memperoleh baseline; penyelesaian sesuai tanggal tidak otomatis berarti produk lulus atau siap dirilis luas.

Pengukuran dilakukan melalui pengujian skenario, catatan lokal yang diperiksa saat pilot, lembar observasi pengawas, dan hasil submit yang dilihat guru di Google Forms. Tidak ada kebutuhan backend analytics pada MVP. Catatan dikumpulkan manual oleh satu guru penanggung jawab; tidak ada ekspor/dashboard pada pilot ini.

| Metrik | Definisi pengukuran | Target |
|---|---|---|
| Keberhasilan masuk | Peserta yang berhasil masuk ke Form yang benar / peserta yang mencoba; pisahkan kamera dan galeri | Belum ditetapkan; laporkan angka aktual pilot |
| Waktu persiapan kelas | Waktu dari guru mulai menyiapkan sesi sampai seluruh peserta yang didukung siap mengerjakan | Belum ditetapkan; laporkan angka aktual pilot |
| Kelancaran sesi | Percobaan yang mencapai pengakhiran sah tanpa kegagalan teknis yang menghentikan ujian / percobaan dimulai | Belum ditetapkan; laporkan angka aktual pilot |
| Salah deteksi | Event yang dihitung sebagai pelanggaran tetapi dinilai pengawas sebagai gangguan sah / event pelanggaran yang ditinjau | Belum ditetapkan; laporkan angka aktual dan siswa terdampak |
| Deteksi skenario wajib | Skenario perpindahan yang terdeteksi sesuai aturan / skenario yang diuji pada perangkat didukung | Seluruh skenario wajib lulus sebelum uji kelas |
| Persistensi | Skenario buka ulang yang mempertahankan state/counter dengan benar / skenario persistensi yang diuji | Seluruh skenario wajib lulus |
| Kontrol PIN | Upaya akses keluar/lanjut/ulang yang ditolak tanpa PIN benar / skenario otorisasi yang diuji | Seluruh skenario wajib lulus |
| Proteksi layar/notifikasi | Skenario sesuai definisi proteksi yang lulus / skenario pada matriks perangkat didukung | Seluruh skenario wajib lulus pada cakupan yang dinyatakan didukung |
| Beban pengawas | Jumlah intervensi per sesi, waktu layanan PIN, dan waktu tunggu siswa; pisahkan gangguan teknis dan pelanggaran | Belum ditetapkan; laporkan angka aktual pilot |
| Pengiriman jawaban | Peserta dengan respons yang diperiksa guru di Forms / peserta yang semestinya mengirim | Belum ditetapkan; jangan diturunkan dari status berakhir |

Syarat kelulusan pilot (disepakati dalam sesi grilling):

1. Semua fitur MVP tersedia dan seluruh keputusan perilaku wajib pada bagian 10 sudah diterapkan pada acceptance test.
2. Alur guru, kedua jalur scan, pelanggaran, PIN, pemulihan, layar, dan notifikasi lulus pada matriks perangkat yang diuji pengembang.
3. Tidak ada bug terbuka yang memungkinkan UI melewati otorisasi PIN, mereset kunci secara tidak sah selama data tersedia, atau mengumumkan proteksi aktif padahal gagal.
4. Pilot satu kelas SMK sekitar 30-40 siswa dijalankan dengan pengawas dan menghasilkan catatan gangguan, antrean PIN, serta pemeriksaan respons Forms.
5. Uji kelas boleh selesai sesuai tanggal tetapi hasilnya belum layak digunakan lebih luas; keputusan lanjut dibuat berdasarkan hasil pengujian, bukan hanya tanggal.

Ambang numerik metrik yang belum ditetapkan sengaja dibiarkan "laporkan angka aktual": pilot adalah pengukuran pertama, belum ada baseline untuk menetapkan target. Guru penanggung jawab satu orang ditetapkan sebelum uji kelas; jalur distribusi build adalah instalasi langsung dengan pengawas hadir.

## 10. Keputusan dan pekerjaan teknis tersisa

Bagian ini menggantikan daftar open questions versi awal. Semua Q01-Q13 telah diputuskan dalam sesi grilling; nomor Q dipertahankan sebagai rujukan silang. Setiap entri mencatat keputusan final dan, bila ada, pekerjaan pembuktian teknis yang masih wajib sebelum pilot.

| ID | Keputusan | Pekerjaan teknis tersisa |
|---|---|---|
| Q01 | Minimum Android final ditetapkan setelah stack dikunci dan dibuktikan pengujian; kandidat awal API 24. Tanpa inventaris manual perangkat peserta; readiness check via aplikasi, bukti proteksi dari pengujian pengembang. | Kunci versi Flutter/plugin/dependency native; jalankan seluruh alur wajib pada konfigurasi yang diuji; tetapkan minimum OS final dari hasil, bukan kandidat. |
| Q02 | Blokir notifikasi berarti meredam suara/getaran gangguan dan menyembunyikan banner/isi pada cakupan yang dibuktikan. Panel sistem tidak dijanjikan tak bisa dibuka. Izin ditolak sebelum mulai: belum siap, ujian alternatif. Dicabut saat ujian: terlihat, ditangani pengawas, state dipertahankan. | Definisikan dan uji matriks hasil aktual (suara, getaran, banner, isi panel, ketukan notifikasi, panggilan, notifikasi sistem) per versi Android; uji interaksi DND dengan alarm FR10. |
| Q03 | Event ambigu dicatat tanpa menambah counter. Panggilan masuk dan jaringan putus tidak otomatis melanggar. Kehilangan fokus saja bukan bukti. Hanya pemicu yang disepakati dalam matriks dan terbukti lewat pengujian yang dihitung. | Susun daftar pemicu konkret, toleransi/debounce, dan perilaku lintas vendor; buktikan lewat pengujian sebelum uji kelas. |
| Q04 | Guru mengakses ulang sesi/PIN di HP pembuat setelah autentikasi perangkat. QR URL biasa ditolak; tidak ada kompatibilitas QR lama. Verifikasi identitas pembuat QR tidak ditambahkan ke pilot. | Uji alur akses ulang PIN terlindungi pada HP pembuat. |
| Q05 | PIN acak lima digit per sesi. Lima kesalahan berturut-turut: jeda 30 detik (bertahan saat app dibuka ulang). Otorisasi sekali per tindakan, tidak permanen, tidak dipulihkan setelah proses mati. Pergantian PIN massal tidak tersedia; PIN bocor: hentikan sesi, tentukan pengganti. PIN terlupa: akses ulang terlindungi atau salinan aman; jika tetap tidak tersedia, gunakan prosedur darurat. | Rancang dan uji verifikasi offline (PIN mentah tidak di QR; verifier yang dapat dibaca siswa diuji ketahannya); uji jeda 30 detik lintas restart. |
| Q06 | Setelah Lanjutkan dari kondisi terkunci: counter dan riwayat tetap, pelanggaran berikutnya langsung mengunci. Pengulangan sesi berakhir (dengan PIN) membuat attempt baru counter nol; riwayat lama mengikuti retensi. | Terapkan pada state machine; uji transisi. |
| Q07 | Setelah crash/reboot/proses mati pada sesi aktif: pulihkan catatan, tahan akses soal, PIN dan pemeriksaan pengawas untuk melanjutkan; tanpa pelanggaran otomatis. Isian hilang: pengawas berwenang ujian alternatif dan kompensasi waktu (prosedur siap sebelum pilot). | Uji pemulihan state vs isian terpisah; uji proses mati sebelum/sesudah transisi state. |
| Q08 | Alarm singkat maksimal dua detik per pelanggaran, tanpa pengulangan terus-menerus; berhenti saat rangkaian peringatan selesai. Saat terkunci: instruksi memanggil pengawas, bukan alarm panjang. Visual selalu tersedia; audio/getaran upaya terbaik sesuai kemampuan perangkat. | Uji bersama DND, mode senyap, headset/Bluetooth, panggilan aktif, perangkat tanpa getaran. |
| Q09 | Darurat: kebutuhan siswa didahulukan lewat perangkat dan pengawas; tidak ada tombol keluar tanpa PIN. Kembali ke aplikasi memerlukan pemeriksaan dan PIN; bukan pengakhiran sah otomatis. Satu guru penanggung jawab memberi keputusan. | Sosialisasikan prosedur ke pengawas sebelum uji kelas. |
| Q10 | Riwayat attempt berakhir disimpan tujuh hari lalu dihapus otomatis. Sesi aktif/terkunci tidak ikut terhapus. Penghapusan oleh retensi hanya menyentuh data jatuh tempo. Pembersihan WebView dibedakan dari riwayat pengamanan, setelah jawaban diperiksa. Batas pengulangan lokal berlaku selama retensi; setelah itu guru wajib sesi baru. | Uji mekanisme retensi; kaji backup Android dan pembersihan storage/WebView. |
| Q11 | Catatan dikumpulkan manual oleh guru penanggung jawab (tanpa ekspor/dashboard). Antrean PIN: siswa di tempat, angkat tangan, pengawas mendatangi; catat total waktu penyelesaian dan antrean terlama. Ambang numerik metrik belum ditetapkan; pilot melaporkan angka aktual sebagai baseline. | Siapkan lembar observasi sederhana sebelum uji kelas. |
| Q12 | Tenggat adalah 5 Oktober 2026: APK siap dites dan uji kelas selesai paling lambat tanggal itu; bukan kewajiban rilis publik. Pilot satu kelas SMK 30-40 siswa. Jadwal: APK kandidat 28 September, simulasi kelompok kecil 29-30 September, uji kelas 1-2 Oktober, evaluasi selesai 5 Oktober. Distribusi build: instalasi langsung dengan pengawas hadir. | Capai jadwal build; tetapkan satu guru penanggung jawab nama sebelum 28 September. |
| Q13 | Pilot hanya mendukung Form tanpa login, tanpa upload file, tanpa layanan luar, tanpa alur edit respons/Kirim respons lain yang dapat diakses siswa. Timer ujian khusus tidak termasuk scope. Guru wajib menjalankan satu percobaan lengkap sampai submit melalui ExamSeal dan memeriksa pembatasan sebelum membagikan QR; Form tidak diubah selama ujian. | Susun Form uji sesuai pembatasan; jalankan percobaan penuh guru. |

Pekerjaan tersisa di atas adalah pembuktian teknis dan persiapan operasional, bukan pertanyaan produk yang menunggu keputusan baru. Tidak ada perubahan scope MVP tanpa keputusan eksplisit.

Sumber konteks produk: ringkasan ExamSeal yang diberikan pengguna dan keputusan dalam percakapan. Sumber platform ditautkan pada requirement terkait; diperiksa 12 September 2026. Verifikasi dokumentasi menggunakan situs resmi/maintainer setelah Context7 tidak dapat dijalankan.
