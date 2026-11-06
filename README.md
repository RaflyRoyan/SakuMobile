# Saku

Aplikasi keuangan pribadi untuk mencatat uang **dari gajian ke gajian**. Setiap periode punya saldo awal per akun, anggaran per kelompok kategori, langganan berulang, dan sisa saldo yang disetor ke tabungan saat periode ditutup ("tutup buku").

Aplikasi ini adalah klien Flutter untuk **Saku API**: Hono di Vercel dengan data di Google Sheets, yang juga dipakai oleh versi web.

## Fitur

- **Beranda**: total saldo semua akun, persentase dana terpakai, akun, tabungan, anggaran, pengeluaran terbesar, transaksi terakhir, pengingat langganan, dan tagihan split bill yang belum dibayar.
- **Transaksi**: keluar, masuk, dan transfer (dengan biaya admin), kategori bertingkat, edit, dan hapus (geser ke kiri di Riwayat).
- **Anggaran** per kelompok kategori, dengan status aman / hampir / lewat.
- **Tabungan**: setoran otomatis saat tutup buku, dan tarik tabungan.
- **Langganan berulang** dengan notifikasi lokal pukul 08.00 WIB menjelang jatuh tempo.
- **Statistik** per periode: donat per kelompok, grafik harian, dan rincian per akun.
- **Split Bill**:
  - foto struk lalu OCR on-device (ML Kit) untuk mengisi item;
  - item dibagi ke tiap peserta, dengan pajak, servis, dan diskon dibagi proporsional;
  - centang lunas otomatis mencatat pemasukan;
  - kartu tagihan berisi QRIS bernominal bisa dibagikan ke WhatsApp dan aplikasi lain.
- **Terima QRIS**: isi nominal, lalu QR merchant tampil dengan nominal sudah terisi. Tersedia juga pencatatan "Sudah dibayar". Fitur ini tetap jalan offline karena payload QRIS di-cache.
- **Kunci aplikasi** dengan biometrik atau PIN perangkat, aktif setelah aplikasi 30 detik di latar belakang.
- **Kelola pengguna** (khusus admin) dan pilihan akun per pengguna.

> QRIS dinamis dibuat dari QRIS statis merchant (misalnya GoBiz). Aplikasi tidak menerima callback pembayaran, jadi status lunas dicatat manual.

## Teknologi

| Bagian | Paket |
|---|---|
| UI | Flutter (Dart `^3.13.5`), `google_fonts` |
| API & sesi | `http`, `flutter_secure_storage` (cookie `saku_token`) |
| Perangkat | `flutter_local_notifications`, `timezone`, `local_auth`, `shared_preferences` |
| Split bill & QRIS | `google_mlkit_text_recognition`, `google_mlkit_barcode_scanning`, `image_picker`, `qr_flutter`, `share_plus` |
| Aset | `flutter_launcher_icons`, `flutter_native_splash` |

## Struktur

```
lib/
  api/        API client (cookie auth, ProblemDetails → ApiException), model, endpoint
  state/      SessionController + AppScope (context.api, context.session, context.services)
  services/   prefs, notifikasi, kunci perangkat, kamera/OCR/share (MediaServices)
  split/      logika murni QRIS (CRC16, parse, dinamis), hitung bagian, parser struk, kartu tagihan
  screens/    satu file per layar
  widgets/    komponen UI bersama
  theme/      palet warna & tema
  utils/      format rupiah & tanggal WIB
test/         unit test + widget test dengan fake server (tanpa jaringan)
assets/logo/  sumber SVG/PNG logo
```

## Menjalankan

Kebutuhan:
- Flutter SDK dengan Dart 3.13 atau lebih baru.
- Android SDK.
- Di Windows, **Developer Mode** harus aktif supaya plugin bisa di-build: jalankan `start ms-settings:developers`.

```bash
flutter pub get
flutter run                     # ke device/emulator yang terhubung
```

Secara default aplikasi memakai API produksi `https://saku-web-one.vercel.app/api`. Untuk memakai server lokal (`npm run dev` di repo web), jalankan:

```bash
flutter run --dart-define=SAKU_API_URL=http://10.0.2.2:5173/api   # emulator Android
```

Autentikasi memakai cookie, jadi aplikasi hanya jalan di target native (Android/iOS/desktop), tidak di Flutter web.

## Tes & analisis

```bash
flutter analyze
flutter test
flutter test test/qris_test.dart                          # satu file
flutter test --plain-name "Every screen builds without overflow"
```

Tes tidak pernah mengakses jaringan. `test/fake_server.dart` meniru API lengkap dengan cek cookie dan fixture. Kalau menambah endpoint baru, tambahkan juga fixture-nya di sana.

## Build rilis

```bash
flutter build apk --release --split-per-abi
```

Hasilnya ada di `build/app/outputs/flutter-apk/`. Untuk kebanyakan HP Android, pakai `app-arm64-v8a-release.apk`.

> Saat ini build rilis masih ditandatangani dengan **debug key** (lihat `android/app/build.gradle.kts`). Sebelum dipublikasikan ke Play Store, buat keystore sendiri dan pasang `signingConfigs.release`. Jangan commit keystore atau `key.properties`; keduanya sudah ada di `android/.gitignore`.

## Mengganti logo

1. Edit SVG di `assets/logo/`, lalu render ulang PNG-nya.
2. Jalankan:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Konfigurasi kedua perintah ada di bagian bawah `pubspec.yaml`.
