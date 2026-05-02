# OCR App — On-Device Document Scanner

Flutter app for fully on-device document scanning and field extraction.
No server calls. No internet after first-launch model download.

**Current scope:** Bangladesh NID card (Smart + Laminated formats).
**Future:** Passport, driving licence, any fixed-layout document — added
via a single config file.

## Pipeline

```
ML Kit Document Scanner  →  Text Recognition (Latin + Devanagari)  →  Config-driven parser  →  Editable result UI
```

## Tech stack

- Flutter (Dart 3.11+)
- `google_mlkit_document_scanner`
- `google_mlkit_text_recognition`
- `google_mlkit_entity_extraction`

## Platform support

- **Android:** API 21+ (Android 5.0 Lollipop and up). Tested on Android 14.
- **iOS:** Not supported. ML Kit Document Scanner is Android-only.

Device must have **Google Play Services**. Bare AOSP emulators won't
work.

## Setup

1. Install Flutter SDK + Android Studio (for Android SDK + tooling).
2. Set `ANDROID_HOME` and add SDK `platform-tools` to PATH.
3. Accept SDK licenses:
   ```bash
   flutter doctor --android-licenses
   ```
4. Verify:
   ```bash
   flutter doctor
   ```

## Run

```bash
flutter pub get
flutter run
```

First build takes 3–10 min (Gradle download).

## Build release APK

```bash
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

## Project layout

See [CLAUDE.md](CLAUDE.md) for full architecture notes. Key dirs:

- `lib/features/document_scanner/configs/` — document type configs
- `lib/features/document_scanner/services/` — pipeline services + parser
- `lib/features/document_scanner/screens/` — UI screens
- `plan.md` — original design document

## Adding a new document type

Three-step process. No engine changes.

1. Add enum value to `DocumentType` in
   [lib/features/document_scanner/configs/document_type.dart](lib/features/document_scanner/configs/document_type.dart)
   plus its `displayName` and `scanInstruction`.
2. Create `lib/features/document_scanner/configs/<type>_config.dart`
   declaring fields, label anchors, Y-zones.
3. Register the config in `configRegistry`.

The type-selection screen, scanner screen, parser, and result card all
adapt automatically.

## Known limitations

- Bengali OCR uses ML Kit's Devanagari module (no Bengali-specific
  model). Latin fields recognize cleanly; Bengali fields are
  best-effort.
- Y-zones in `nid_config.dart` are initial estimates. Calibrate against
  10+ real card images per format.
- Document Scanner UI is native and not theme-customizable.

## Repo

Remote: `git@github.com:zawad29/ocr_poc_mobile.git`
