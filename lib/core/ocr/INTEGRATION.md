# OCR Service — Host Integration Guide

This folder is a self-contained, UI-free, on-device OCR library. Drop it
into a host Flutter app, wire three pubspec deps and one Gradle line,
and call `DocumentScanOrchestrator().scan(type)`.

The demo at `lib/features/document_scanner/` and `lib/main.dart` is **not
part of the library** — it is a reference UI only. Do not copy it.

## What you get

A three-stage pipeline, fully on-device (the only network calls are
ML Kit's first-launch model downloads):

```
ML Kit Document Scanner  →  Text Recognition (multi-script)  →  Config-driven parser
```

Adding a document type means adding one config file — the engine,
services, and result type never change.

## Copy these files

Copy the entire `lib/core/ocr/` directory into your host app (path is
your choice — e.g. `lib/services/ocr/` or `lib/core/ocr/`):

```
ocr/
  ocr.dart                              ← public barrel (the only file hosts import)
  INTEGRATION.md                        ← this file
  configs/
    document_type.dart                  DocumentType enum + configFor()
    document_parser_config.dart         FieldConfig, FieldType, DocumentParserConfig
    field_char_sets.dart
    nid_config.dart
    educational_certificate_config.dart
    birth_registration_config.dart
    plaintext_config.dart
  models/
    document_scan_result.dart
  services/
    document_scan_orchestrator.dart     ← public entry
    generic_document_parser.dart        (internal)
    document_scan_service.dart          (internal — Stage 1)
    text_recognition_service.dart       (internal — Stage 2)
    entity_extraction_service.dart      (internal — Stage 3C)
```

All imports inside `ocr/` are relative — copying the folder works as-is,
no rewrites needed.

## Public API

Hosts import **only** `ocr.dart`. Anything not exported by `ocr.dart` is
an implementation detail and may change without notice.

Exported:

- `DocumentScanOrchestrator` — entry point. `scan(type)` + `dispose()`.
- `DocumentScanResult` — the result entity.
- `DocumentType` + `DocumentTypeExtension` — enum with `displayName` and `scanInstruction`.
- `configFor(DocumentType)` — accessor for a type's parser config (useful for rendering field lists).
- `DocumentParserConfig`, `FieldConfig`, `FieldType` — config types, exposed so hosts can iterate fields when rendering results.

## pubspec.yaml

Add to your host's `pubspec.yaml` under `dependencies:`:

```yaml
google_mlkit_document_scanner: ^0.4.1
google_mlkit_text_recognition: ^0.15.1
google_mlkit_entity_extraction: ^0.15.1
```

Then `flutter pub get`.

## Android setup

`android/app/build.gradle.kts`:

1. Set `minSdk = 21` or higher (all ML Kit plugins require API 21+).
   If your app already targets a higher `minSdk`, no change is needed.
2. Add the Devanagari recognizer dep (Latin ships with the base
   `text-recognition` module; non-Latin scripts each need a separate
   native dep):

```kotlin
dependencies {
    implementation("com.google.mlkit:text-recognition-devanagari:16.0.1")
}
```

See this repo's [`android/app/build.gradle.kts`](../../../android/app/build.gradle.kts)
for a working example.

If you add a new document type whose `scripts` list includes Chinese,
Japanese, or Korean, add the matching `text-recognition-<script>`
Gradle dep too.

## Platform constraints and device compatibility

- **Android only.** The `google_mlkit_document_scanner` plugin has no
  iOS implementation. `DocumentScanOrchestrator.isSupported()` returns
  `false` on iOS so you can gate the UI accordingly. iOS builds will fail
  at link time until a different Stage 1 is wired in.
- **Google Play Services required.** The Document Scanner module is
  delivered via Play Services — bare AOSP emulators won't work. Use a
  real device or an emulator image with Play Store.
- **API 21+ required at runtime.** The ML Kit plugins declare
  `minSdkVersion 21`. If your host app has a lower `minSdk`, older
  devices may have the app installed but the OCR feature will fail.
- **First launch downloads models.** `google_mlkit_entity_extraction`
  downloads its model on first use. After that everything is offline.

### Handling unsupported devices

`scan()` throws `OcrUnsupportedDeviceException` if Google Play Services are
missing or incompatible at runtime (covers devices with outdated Play Services
or API levels below the ML Kit minimum). Callers must catch it:

```dart
try {
  final result = await orchestrator.scan(DocumentType.bangladeshNid);
  if (result == null) return; // user cancelled
  // use result...
} on OcrUnsupportedDeviceException catch (e) {
  // show "not available on this device" message
} catch (e) {
  // other unexpected errors
}
```

## Usage

```dart
import 'package:HOST/PATH/ocr/ocr.dart';

class MyScanFlow {
  final _orchestrator = DocumentScanOrchestrator();

  Future<void> scanNid() async {
    try {
      final result = await _orchestrator.scan(DocumentType.bangladeshNid);
      if (result == null) return; // user cancelled the scanner UI

      // result.fields           : Map<String, String?> keyed by FieldConfig.name
      // result.extractionScore  : count of non-empty fields
      // result.totalFields      : count of fields the config declared
      // result.extractionRate   : 0.0–1.0
      // result.isComplete       : true iff every field was extracted
      // result.imagePath        : on-disk path to the cropped page image
      // result.documentType     : echoes the enum you passed in
    } on OcrUnsupportedDeviceException {
      // device not supported — show fallback UI
    } finally {
      _orchestrator.dispose(); // releases native ML Kit recognizers
    }
  }
}
```

`DocumentScanOrchestrator` is cheap to instantiate. Typical pattern:
one orchestrator per scan flow (e.g. one per screen), `dispose()` when
the flow ends.

## Rendering results generically

Avoid hardcoding field names per document type — iterate the config:

```dart
final config = configFor(result.documentType);
for (final field in config.fields) {
  final value = result.fields[field.name];
  // render `field.name` as label, `value` as value
}
```

This way, adding a new document type requires no UI changes.

## Cancellation & errors

- User cancels the scanner sheet → `scan()` returns `null`.
- Device not supported / Play Services unavailable → `scan()` throws `OcrUnsupportedDeviceException`. **Callers must catch this.**
- Other ML Kit / I/O errors → `scan()` throws. Wrap in a general `catch` block.

## Adding a new document type

All four steps happen inside `core/ocr/`:

1. Add a value to the `DocumentType` enum in `configs/document_type.dart`.
2. Add `displayName` + `scanInstruction` cases in `DocumentTypeExtension`
   (same file).
3. Create `configs/<type>_config.dart` declaring a `DocumentParserConfig`
   (use the existing configs as templates — they show field types,
   label anchors, spatial Y/X zones, regex strategies).
4. Register the new type in the `configRegistry` map in
   `configs/document_type.dart`.

You do **not** need to add the new config file to `ocr.dart` — the host
reaches it via `configFor(type)`, which goes through the registry.

The engine (`GenericDocumentParser`), services, and orchestrator never
change when adding a document type.

## Lifecycle

- One orchestrator per scan flow; call `dispose()` when done.
- Calling `scan()` again on the same orchestrator after a successful
  scan is fine — internal services are reused.
- Don't share an orchestrator across concurrent scans.

## Gotchas

- **Package enum typo:** `TextRecognitionScript.devanagiri` (not
  `devanagari`). Upstream typo in `google_mlkit_text_recognition`. If
  you write a new config, copy the spelling from existing configs.
- **Bengali ≠ Devanagari.** ML Kit has no Bengali recognizer. The
  Devanagari module covers Hindi/Marathi/Sanskrit only. BD NID Bengali
  fields will likely fail; Latin fields are fine.
- **Native module dep required per non-Latin script.** See Android setup.
- **Y-zones in `nid_config` are estimates.** Calibrate against real
  card images. Debug logs print bbox positions per line.

## Debug logging

`debugPrint` calls (no-op in release builds) in:

- `services/text_recognition_service.dart` — raw OCR per script + per-line bbox.
- `services/generic_document_parser.dart` — per-field strategy + raw + final.
- `services/document_scan_orchestrator.dart` — image path + extraction score.

View via `flutter run` console or `adb logcat -s flutter`.

## Verifying the boundary

If you're modifying this library inside the POC repo, two greps prove
the library stays clean and host-agnostic:

```bash
# Library must not import any UI or feature code.
grep -rE "package:flutter/(material|widgets|cupertino)|features/" lib/core/ocr/
# (expected: no matches)

# Demo (and any host) must consume the library only via the barrel.
grep -r "package:ocr_app/core/ocr/" lib/features lib/main.dart
# (expected: only `ocr.dart` import paths)
```
