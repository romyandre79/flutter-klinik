# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Kreatif Klinik** is an offline-first clinic POS and management system built with Flutter. It supports Android, iOS, macOS, Windows, and web with background data synchronization to a remote API.

## Commands

```bash
# Install dependencies
flutter pub get

# Run app
flutter run

# Analyze
flutter analyze

# Test
flutter test

# Run a single test file
flutter test test/path/to/test_file.dart

# Clean
flutter clean
```

### Build Scripts

```batch
# Windows
build.bat apk        # Android APK
build.bat windows    # Windows desktop
build.bat all        # Both

# macOS/Linux
./build.sh apk
./build.sh ios
./build.sh macos
./build.sh all
```

Scripts run: clean → pub get → generate launcher icons → build.

## Architecture

Clean Architecture with Cubit (flutter_bloc) state management across four layers:

```
lib/
  core/         # Cross-cutting: API, services, theme, utils, constants
  data/         # Models, repositories, database_helper.dart (SQLite singleton)
  logic/        # Cubits + States (one subdirectory per feature)
  presentation/ # Screens + Widgets (one subdirectory per feature)
  main.dart     # Entry point
```

### Data Flow

```
UI (BlocBuilder) → Cubit method → Repository → DatabaseHelper / ApiService → emit(State)
```

- **Models** extend `Equatable` — always compare by value, not reference.
- **States** extend `Equatable`. Emit a fresh state object; never mutate in place.
- **Repositories** are the only place that touch `DatabaseHelper` or `ApiService`.
- Cubits call repositories; they never access the database directly.

### State Management Pattern

Each feature has a `*_cubit.dart` + `*_state.dart`. States follow:
- `*Initial` → `*Loading` → `*Loaded(data)` or `*Error(message)`

Use `BlocBuilder` for rebuilds, `BlocListener` for one-off side effects (snackbars, navigation).

### Database

- **Singleton:** `DatabaseHelper.instance` in `lib/data/database_helper.dart`
- **Current schema version:** 11 — increment and add a migration case in `onUpgrade` for any schema change.
- **Platform:** `sqflite` on mobile/web; `sqflite_ffi` on Windows/Linux (initialized in `main.dart`).
- **Sync flag:** Orders and items carry `is_synced` (0/1). `SyncService` uploads rows where `is_synced = 0`.

### Offline-First Sync

`lib/core/sync_service.dart` handles:
1. Upload unsynced local records (`is_synced = 0`) to the API.
2. Download master data (products, customers, services) from the API.
3. Server timestamps win on conflict.

Sync is triggered manually from the UI; the app is fully functional without a network connection.

### Core Services (lib/core/)

| File | Purpose |
|---|---|
| `api/api_service.dart` | Dio-based HTTP client with auth headers |
| `api/api_config.dart` | Base URL, endpoints |
| `sync_service.dart` | Offline→online data sync |
| `printer_service.dart` | Bluetooth thermal receipt printer |
| `store_print.dart` | Receipt layout/content |
| `pdf_service.dart` | PDF generation |
| `export_service.dart` | Excel export |
| `import_service.dart` | Excel import |
| `fonnte_service.dart` | SMS integration |
| `whatsapp_service.dart` | WhatsApp messaging |
| `session_service.dart` | User session (SharedPreferences) |
| `log_service.dart` | Error/activity logging |

### Theme

`lib/core/theme/app_theme.dart` — Material 3, Poppins font (Google Fonts).

- Primary color: `#2196F3`
- Spacing scale: `xs(4)` `sm(8)` `md(16)` `lg(24)` `xl(32)`
- Border radius: `xs(4)` → `full(100)`
- Always use theme tokens; avoid hardcoded colors or spacing.

### Currency & Numbers

Use `lib/core/utils/currency_formatter.dart` for IDR formatting and `lib/core/utils/thousand_separator_formatter.dart` for input fields. Do not format money inline.

## Key Dependencies

| Package | Purpose |
|---|---|
| `flutter_bloc ^9.1.1` | Cubit state management |
| `sqflite ^2.4.2` / `sqflite_common_ffi` | SQLite (mobile + desktop) |
| `dio ^5.9.1` | HTTP client |
| `equatable ^2.0.8` | Value equality |
| `print_bluetooth_thermal` / `esc_pos_utils_plus` | Thermal printer |
| `excel ^4.0.6` | Excel import/export |
| `pdf ^3.11.3` + `printing ^5.14.2` | PDF generation/printing |
| `fl_chart ^1.1.1` | Charts in reports |
| `google_fonts ^7.0.2` | Poppins font |
| `shared_preferences ^2.5.4` | Session/settings persistence |
| `uuid ^4.5.2` | UUID generation for new records |

## Adding a New Feature

1. **Model** in `lib/data/models/` — extend `Equatable`, list all fields in `props`.
2. **Repository** in `lib/data/repositories/` — depends on `DatabaseHelper` and/or `ApiService`.
3. **Cubit + State** in `lib/logic/cubits/<feature>/` — inject repository via constructor.
4. **Register** the repository in `MultiRepositoryProvider` and the cubit in `MultiBlocProvider` (both in `main.dart`).
5. **Screen(s)** in `lib/presentation/screens/<feature>/`.
