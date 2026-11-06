# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Saku is a personal-finance app (Indonesian UI) that tracks money "dari gajian ke gajian": pay periods, accounts, budgets, subscriptions, and savings filled from leftover balances when a period is closed ("tutup buku"). UI follows the design mockup at https://claude.ai/artifact/KiPmaBnFYDyVDx3555QKGn. All screens are wired to the live **Saku API** (Hono on Vercel, data in Google Sheets).

- Backend repo: `D:\code\saku-web-vercel`. Business rules & endpoints: `docs/SAKU_API_SPEC.md`, but `docs/02-pekerjaan-dan-tampilan.md` §2 overrides it (the spec still describes .NET/Bearer). Current request/response shapes: `src/lib/apiKatalog.ts` and the TS interfaces in `src/hooks/*.ts` — `lib/api/models.dart` mirrors those.
- Base URL `https://saku-web-one.vercel.app/api`; override with `--dart-define=SAKU_API_URL=...`.
- Dart SDK `^3.13.5`, lints from `flutter_lints`. Deps: `http`, `flutter_secure_storage`, `google_fonts`. google_fonts 9.x returns `material_ui`'s `TextTheme` (incompatible with `flutter/material`'s), so `AppTheme` sets `fontFamily` by name — don't use `GoogleFonts.*TextTheme()`.
- On Windows, building plugins needs Developer Mode (symlink support): `start ms-settings:developers`. `android/gradle.properties` sets `kotlin.incremental=false` because Kotlin incremental caches fail when the pub cache (C:) and project (D:) are on different drives.
- App display name is "Saku" (package/binary names stay `saku_mobile`; macOS `PRODUCT_NAME` left as `saku_mobile` because the Xcode project references `saku_mobile.app`).
- Logo: source SVGs in `assets/logo/` (`saku_icon.svg` full-bleed, `saku_logo.svg` rounded, `saku_foreground.svg` for the Android adaptive icon / native splash). After editing an SVG, re-render the PNGs (e.g. with `sharp`), then `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create` (configs at the bottom of `pubspec.yaml`). The in-app splash/login use `assets/logo/saku_logo.png`; native and in-app splash share background `#0B3B2A`.
- Android `applicationId`: `com.sakumobile.saku_mobile`. Cookie auth below only works on native targets (not Flutter web).

## Architecture

- **Auth is a cookie, not Bearer.** The server reads only cookie `saku_token` (set by login/setup/ganti password; login body is `{ pengguna, expiresAt }`, no token). `lib/api/api_client.dart` captures it from `Set-Cookie`, stores it via `TokenStore` (secure storage; `MemoryTokenStore` in tests) and sends `Cookie: saku_token=…`. Every request also sends `X-Requested-With: saku` (server CSRF guard → 403 without it on POST/PUT/DELETE). A 401 on a non-auth call clears the token and fires `onUnauthorized`, which `SakuApp` uses to return to Login.
- Errors are ProblemDetails → `ApiException(status, title, errors{field: [msg]})`; field keys are camelCase body names (`nominal`, `akunId`, …). Forms map `errors` to fields and fall back to `title`.
- `lib/api/saku_api.dart` — one typed method per endpoint. `periodeAktif()` / `pratinjauTutup()` return null on 404 (no active period). Calls whose result is unused are typed `<dynamic>` because the server may answer 204.
- `lib/state/app_scope.dart` — `SessionController` (current `Pengguna`, login/logout/restore) exposed by the `AppScope` InheritedNotifier; `context.api` / `context.session` read it. After any write call `session.dataChanged()`; `AsyncView` (`lib/widgets/async_view.dart`) and the history screen reload when `dataVersion` changes. `runAction()` wraps a mutation with toast + refresh; `showPeringatan()` shows the server's non-blocking `peringatan[]` (negative balance, budget exceeded).
- `lib/app.dart` — `Routes`; starts at `SplashScreen` (restores session via `/auth/me`) → Login or Home. Login switches to "Setup Admin" when `/auth/status` says `perluSetup`. `Routes.editTransaction` takes the transaction id; `AddTransactionScreen(editId:)` handles both create and edit/delete. Transactions with `kodeSistem == TARIK_TABUNGAN` are read-only (server returns 409).
- `HomeShell` = `IndexedStack` of 4 tabs (Beranda `/dashboard`, Riwayat, Anggaran, Tabungan) + raised FAB. Dashboard switches tabs through `onSelectTab` (`HomeTab` indices).
- Dates: API uses `yyyy-MM-dd` / `yyyy-MM` in WIB; `lib/utils/format.dart` has `todayWib()`, `ymd`, `ym`, Indonesian labels, and money formatting (`rupiah`, `thousands`, `signed` with real minus `−`, `parseNominal`). Money is `int` rupiah.
- Akun & Kategori are shared masters (admin writes them in the web app); users pick their own accounts via `/akun/pilihan` (Pengaturan → Akun saya). Admin "Kelola pengguna" is in-app.
- **Device services** (`lib/services/`): `AppServices` = `AppPrefs` (shared_preferences), `ReminderScheduler` (flutter_local_notifications, WIB via `timezone`), `DeviceAuth` (local_auth). `main()` passes `AppServices.nyata()`; `SakuApp` defaults to `AppServices.memori()` (no plugins), which tests use. `SessionController.syncPengingat()` reschedules subscription reminders from `/berulang` on login/restore/`dataChanged`/resume; schedule rules are pure in `jadwal_pengingat.dart`. `AppLock` (`MaterialApp.builder`) covers the app on resumed sessions and after 30 s in background; it skips the prompt right after a password login. Android needs `FlutterFragmentActivity`, core library desugaring, the notification receivers in the manifest, and `res/drawable/ic_notif.xml` (kept via `res/raw/keep.xml`).
- Statistik (`Routes.statistics`) uses `GET /periode/{id}/ringkasan` (per kelompok/kategori) plus all transactions of the period for the per-day chart; charts are `CustomPainter`, colours from `AppColors.chart`.
- **Split bill & QRIS** (`lib/split/`): pure logic ported 1:1 from the web repo (`src/lib/qris.ts`, `splitHitung.ts`, `parseStruk.ts`) — `qris.dart` (CRC16, `parseQris`, `qrisDinamis`), `split_hitung.dart` (`hitungBagian`, rounding = JS `Math.round`), `parse_struk.dart`; keep them in sync with the web tests. The model is `SplitBill` (Flutter already has a `Split` curve). Request bodies use peserta INDICES in `items[].peserta`, responses use IDs. Camera/gallery, ML Kit OCR + QR decoding and the share sheet go through `MediaServices` (`AppServices.media`; fake in tests). `kartu_tagihan.dart` builds the share card as a widget in a `RepaintBoundary` (360 dp, rendered at 3×). The merchant QRIS payload is cached in prefs (`qris_store.dart`) so Terima QRIS works offline. `android/app/proguard-rules.pro` silences R8 for the non-Latin ML Kit recognizers (compileOnly in the plugin).
- UI kit: `lib/theme/app_colors.dart` (mockup palette — use tokens, not hex), `lib/widgets/common.dart` (`SakuCard`, `Pill`, `SegmentedTabs`, `InfoNote`, `FieldRow`, `BusyButton`, `showSakuSheet`, …), `form_fields.dart` (`NominalField` with thousands formatter, `pickOne` sheet picker, `pickDate`, `SelectRow`), `saku_rows.dart` (`TransaksiRow`, `AkunBadge`).

## Commands

```bash
flutter pub get                         # install dependencies
flutter run                             # run on connected device (-d <id>)
flutter run --dart-define=SAKU_API_URL=http://10.0.2.2:5173/api   # against local `npm run dev` of the web repo (Android emulator)
flutter analyze                         # static analysis + lints
flutter test                            # all tests
flutter test test/api_client_test.dart  # single file
flutter test --plain-name "Every screen builds without overflow"   # single test by name
flutter build apk                       # Android release build
```

Tests never hit the network: `test/fake_server.dart` is a `MockClient` that mimics the API (cookie check, fixtures). Inject it with `SakuApp(api: FakeServer().api())`. Add fixtures there for new endpoints — unknown routes return 404. Tests set `GoogleFonts.config.allowRuntimeFetching = false` and render with the wide test font, so they catch overflows the real font hides; the "Every screen builds" test visits each tab and pushes each route at 390×844 — add new routes to its list.
