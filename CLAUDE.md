# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Saku is a personal-finance app (Indonesian UI) that tracks money "dari gajian ke gajian": pay periods, accounts, budgets, subscriptions, and savings filled from leftover balances when a period is closed ("tutup buku"). The UI is implemented from the design mockup at https://claude.ai/artifact/KiPmaBnFYDyVDx3555QKGn (10 artboards). **It is UI-only**: every screen reads static values from `lib/data/mock_data.dart`, buttons mostly pop or no-op, and login accepts any non-empty credentials. No backend, persistence, or state-management package exists yet (the mockup's footer says data will live in Google Sheets). Don't assume one — ask.

- Dart SDK constraint: `^3.13.5`. Lints come from `flutter_lints` (`analysis_options.yaml`, platform folders excluded from analysis).
- Dependencies: `google_fonts` (Plus Jakarta Sans, fetched at runtime). google_fonts 9.x returns `material_ui`'s `TextTheme`, which is incompatible with `flutter/material`'s — don't use `GoogleFonts.*TextTheme()`; `AppTheme` sets `fontFamily` by name instead.
- On Windows, building plugins needs Developer Mode (symlink support): `start ms-settings:developers`.

## Architecture

- `lib/app.dart` — `SakuApp` (`MaterialApp`) and `Routes` (named routes). Starts at `Routes.login`. `Routes.editTransaction` is built in `onGenerateRoute` and takes an `EditMode` argument (active period / closed period / locked "Tarik Tabungan" transaction).
- `lib/screens/home_shell.dart` — after login: `IndexedStack` of 4 tabs (Beranda, Riwayat, Anggaran, Tabungan) + custom bottom nav with a raised centre FAB that pushes Tambah Transaksi. Use `HomeTab` indices; the dashboard switches tabs via its `onSelectTab` callback instead of pushing routes.
- Pushed screens (own `Scaffold` + `SubPageHeader`): add/edit transaction, subscriptions (Langganan), close period (Mulai periode baru), settings.
- `lib/theme/app_colors.dart` holds every colour from the mockup — reuse these tokens instead of hex literals. `AppTheme.tabular` gives tabular figures for amounts.
- `lib/widgets/common.dart` — shared building blocks matching the mockup (`SakuCard`, `DividedColumn`, `SectionHeader`, `Pill`, `ProgressBar`, `IconTile`, `SegmentedTabs`, `InfoNote`, `FieldRow`, `PrimaryButton`/`OutlineBtn`, `showSakuSheet`). `TransactionRow` lives in `dashboard_screen.dart` and is reused by the history screen.
- `lib/data/models.dart` + `mock_data.dart` — plain immutable models and the mockup's sample data. Money is `int` rupiah; format with `lib/utils/format.dart` (`rupiah`, `thousands`, `signed` — uses a real minus sign `−`).
- Android `applicationId` / namespace: `com.sakumobile.saku_mobile`.
- Targets: android, ios, web, windows, macos, linux (all scaffolded).

## Commands

```bash
flutter pub get                         # install dependencies
flutter run                             # run on connected device (-d windows / -d chrome / -d <id>)
flutter analyze                         # static analysis + lints
dart format .                           # format
flutter test                            # all tests
flutter test test/widget_test.dart      # single file
flutter test --plain-name "Every screen builds without overflow"   # single test by name
flutter build apk                       # Android release build
```

Tests set `GoogleFonts.config.allowRuntimeFetching = false` (no network) and render with the wide test font, so they catch layout overflows the real font hides. The "Every screen builds" test pushes each named route at 390×844 — add new routes to its list.
