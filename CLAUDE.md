# CLAUDE.md

Guidance for Claude Code working on this repo.

## What this is

Flutter app, fully on-device document OCR. Current scope: Bangladesh NID
(Bengali + English). Architected for arbitrary fixed-layout documents.

## Architecture

Three-stage pipeline, all on-device, no network calls except first-launch
ML Kit model downloads.

```
ML Kit Document Scanner  →  Text Recognition (Latin + Devanagari)  →  Config-driven parser
```

**Strategy + Configuration Object pattern.** Engine
(`GenericDocumentParser`) is generic and stable. Each document type is a
`DocumentParserConfig` declaring fields, label anchors, spatial zones,
and types. Adding a new doc type = one config file + enum value +
registry entry. Engine, orchestrator, screens, and result card never
change.

Three parsing strategies tried per field, in order:
1. **Label anchor** — find label string, take same line after it or next
   non-empty line.
2. **Spatial zone** — fall back to normalized Y-zone + X boundary
   (excludes photo column).
3. **Entity extraction** — for date fields only, normalize via ML Kit
   Entity Extraction.

## Layout

```
lib/features/document_scanner/
  configs/
    document_type.dart            DocumentType enum + configRegistry + configFor()
    document_parser_config.dart   FieldConfig, FieldType, DocumentParserConfig
    nid_config.dart               BD NID-specific config
  models/document_scan_result.dart
  services/
    document_scan_service.dart      Stage 1 wrapper (ML Kit Document Scanner)
    text_recognition_service.dart   Stage 2 (multi-script recognizer pool)
    entity_extraction_service.dart  Stage 3C (ML Kit Entity Extraction)
    generic_document_parser.dart    Stage 3 engine — DO NOT add doc-specific logic
    document_scan_orchestrator.dart Wires all three stages
  screens/
    document_type_selection_screen.dart  Screen 1
    document_scanner_screen.dart         Screens 2/3/4
  widgets/scan_result_card.dart          Editable field rows + score bar
lib/main.dart                            Entry → DocumentTypeSelectionScreen
plan.md                                  Original implementation plan
```

## Adding a new document type

1. Add value to `DocumentType` enum in [configs/document_type.dart](lib/features/document_scanner/configs/document_type.dart).
2. Add `displayName` + `scanInstruction` cases in extension.
3. Create `configs/<type>_config.dart` with a `DocumentParserConfig`.
4. Register in `configRegistry` map.

Zero changes to engine, services, screens, or widgets. Type-selection
screen auto-includes the new type.

## Gotchas

- **Package enum typo:** `TextRecognitionScript.devanagiri` (not
  `devanagari`). Upstream typo in `google_mlkit_text_recognition`.
- **Bengali ≠ Devanagari.** ML Kit has no Bengali recognizer. Devanagari
  module covers Hindi/Marathi/Sanskrit. BD NID Bengali fields likely
  fail. Latin fields fine.
- **Native module dep required.** Each non-Latin script needs explicit
  Android Gradle dep. Already added: `com.google.mlkit:text-recognition-devanagari:16.0.1`
  in [android/app/build.gradle.kts](android/app/build.gradle.kts).
- **Document Scanner is Android-only.** iOS build will fail on the
  scanner plugin until a different Stage 1 is wired.
- **Google Play Services required** for Document Scanner. Bare AOSP
  emulator won't work — use real device or emulator with Play Store.
- **`minSdk` pinned to 21** explicitly in build.gradle.kts. ML Kit
  requires it.
- **Y-zones in nid_config are estimates.** Calibrate against real card
  images. Debug logs print bbox positions per line.

## Commands

```bash
flutter pub get
flutter analyze lib/        # must be clean before commit
flutter clean && flutter run  # use clean when changing native deps
```

## Debug logging

`debugPrint` calls in:
- `text_recognition_service.dart` — raw OCR per script + per-line bbox
- `generic_document_parser.dart` — per-field strategy + raw + final
- `document_scan_orchestrator.dart` — image path + extraction score

`debugPrint` is no-op in release. View via `flutter run` console or
`adb logcat -s flutter`.

## Conventions

- Folder named `document_scanner`, not `nid_scanner`. Don't rename — it's
  generic by design.
- `GenericDocumentParser` must never branch on document type. If a
  document needs custom logic, add an optional `customParser` callback
  field on `DocumentParserConfig`.
- Always call `orchestrator.dispose()` in screen dispose to free native
  recognizer memory.
- Field display in result card is built by iterating `config.fields` —
  never hardcode field names in UI.
