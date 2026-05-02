# Flutter On-Device Document OCR — Plan

## Overview

Fully on-device document scanning and field extraction in a Flutter app.
No server calls. No internet required after app install.
Uses Google ML Kit Flutter plugins exclusively.

**Current scope:** Bangladesh NID card (Bengali + English, fixed layout).
**Future scope:** Passport, driving licence, and other fixed-layout documents —
supported by the architecture without touching existing code.

---

## Design Philosophy: Config-Driven Extensibility

The parsing engine is written **once**. Each document type is a **config** — a Dart
object that declares what labels to look for, where fields live spatially, and what
type each field holds. Adding passport support in the future means creating one config
file and registering it. No engine code changes.

**Design pattern used: Strategy + Configuration Object**

- The **parsing engine** (`GenericDocumentParser`) is the stable core — never changes.
- Each **document config** (`DocumentParserConfig`) is a Strategy that describes a
  specific document's structure.
- The **orchestrator** (`DocumentScanOrchestrator`) selects the right config at runtime
  based on document type.
- New document types are **open for extension, closed for modification** (OCP).

```
DocumentParserConfig (abstract config)
    │
    ├── NidParserConfig     ← implemented now
    ├── PassportConfig      ← future, ~20 lines of Dart
    └── DrivingLicConfig    ← future, ~20 lines of Dart

GenericDocumentParser       ← written once, never changes
    reads any DocumentParserConfig and produces Map<String, String?>
```

---

## Three-Stage Pipeline

```
User selects document type + taps "Scan"
        │
        ▼
┌─────────────────────┐
│  Stage 1            │
│  Document Scanner   │  ← ML Kit Document Scanner
│  Crop + flatten     │     Perspective correction, clean crop
└────────┬────────────┘
         │  file path (cropped image)
         ▼
┌─────────────────────┐
│  Stage 2            │
│  Text Recognition   │  ← ML Kit Text Recognition v2
│  Bengali + Latin    │     Returns RecognizedText with bounding boxes
└────────┬────────────┘
         │  RecognizedText ×2 (Indic + Latin)
         ▼
┌──────────────────────────────────────┐
│  Stage 3 — Config-Driven Parser      │
│                                      │
│  DocumentParserConfig (e.g. NID)     │
│         ↓                            │
│  GenericDocumentParser               │
│    ├── Strategy A: label-anchor      │
│    ├── Strategy B: spatial zones     │
│    └── Strategy C: entity extract    │
└────────┬─────────────────────────────┘
         │  Map<String, String?>
         ▼
   DocumentScanResult
   (displayed in UI)
```

---

## Flutter Packages

```yaml
dependencies:
  google_mlkit_document_scanner: ^0.1.0   # Stage 1
  google_mlkit_text_recognition: ^0.13.0  # Stage 2
  google_mlkit_entity_extraction: ^0.13.0 # Stage 3 assist (dates)
```

`android/app/build.gradle`:
```groovy
android {
    defaultConfig {
        minSdkVersion 21
    }
}
```

---

## Project Structure

```
lib/
├── main.dart
└── features/
    └── document_scanner/               ← generic feature folder (not nid-specific)
        ├── configs/
        │   ├── document_parser_config.dart   ← FieldConfig, FieldType, DocumentParserConfig
        │   ├── nid_config.dart               ← NID-specific config (implemented now)
        │   └── document_type.dart            ← DocumentType enum + registry
        ├── models/
        │   └── document_scan_result.dart     ← generic result model
        ├── services/
        │   ├── document_scan_service.dart    ← Stage 1 (ML Kit Document Scanner)
        │   ├── text_recognition_service.dart ← Stage 2 (ML Kit Text Recognition)
        │   ├── entity_extraction_service.dart← Stage 3C (ML Kit Entity Extraction)
        │   ├── generic_document_parser.dart  ← Stage 3 engine (written once)
        │   └── document_scan_orchestrator.dart ← wires all stages together
        ├── widgets/
        │   └── scan_result_card.dart         ← generic field display widget
        └── screens/
            └── document_scanner_screen.dart  ← scan UI
```

**Key naming decision:** The folder and classes are named `document_scanner`, not
`nid_scanner`. This is intentional — the feature is document scanning. NID is just the
first supported document type. No renaming needed when passport support is added.

---

## Detailed Task List for Claude Code

---

### Task 1 — `configs/document_type.dart`

The `DocumentType` enum is the registry of all supported document types.
Adding a new type in the future = adding one enum value + registering its config.

```dart
// configs/document_type.dart

enum DocumentType {
  bangladeshNid,
  // Future: passport, drivingLicence, birthCertificate
}

extension DocumentTypeExtension on DocumentType {
  String get displayName {
    switch (this) {
      case DocumentType.bangladeshNid:
        return 'Bangladesh NID';
    }
  }

  String get scanInstruction {
    switch (this) {
      case DocumentType.bangladeshNid:
        return 'Place the NID card flat and ensure all text is visible';
    }
  }
}
```

---

### Task 2 — `configs/document_parser_config.dart`

The core abstraction. Every document type describes itself through this config.
This is the **only file** that defines the contract for extensibility.

```dart
// configs/document_parser_config.dart

enum FieldType {
  string,   // names, addresses — returned as-is
  date,     // DOB, expiry — normalized via entity extraction
  digits,   // NID number, passport number — strip non-digits
}

class FieldConfig {
  /// Unique key for this field in the result map (e.g. 'name_en')
  final String fieldKey;

  /// Human-readable label shown in UI (e.g. 'Name (English)')
  final String displayLabel;

  /// Label strings that appear before this field in the document.
  /// Listed in priority order. First match wins.
  /// Include common OCR-error variants (missing colon, OCR substitutions).
  final List<String> labelAnchors;

  /// Normalized Y-axis zone (0.0–1.0) where this field appears.
  /// Used as fallback when label-anchor parsing fails.
  /// Null = label-anchor only, no spatial fallback for this field.
  final (double yMin, double yMax)? yZone;

  /// How to post-process the extracted raw string.
  final FieldType type;

  /// Whether to use entity extraction for this field (dates only).
  final bool useEntityExtraction;

  const FieldConfig({
    required this.fieldKey,
    required this.displayLabel,
    required this.labelAnchors,
    this.yZone,
    this.type = FieldType.string,
    this.useEntityExtraction = false,
  });
}

class DocumentParserConfig {
  /// Identifies this config — must match DocumentType enum value name.
  final DocumentType documentType;

  /// Ordered list of fields to extract.
  /// Order determines display order in the result card.
  final List<FieldConfig> fields;

  /// Normalized X boundary (0.0–1.0) separating the photo from the text area.
  /// Spatial parsing ignores text elements whose x-center < photoXBoundary.
  /// Typically ~0.30 for NID (photo takes left 30%), 0.35 for passport.
  final double photoXBoundary;

  /// Scripts to run text recognition with.
  /// Most documents need latin only. BD NID needs [devanagari, latin].
  final List<TextRecognitionScript> scripts;

  const DocumentParserConfig({
    required this.documentType,
    required this.fields,
    required this.scripts,
    this.photoXBoundary = 0.30,
  });
}
```

---

### Task 3 — `configs/nid_config.dart`

The NID-specific config. This is the **only document-specific file** that needs
to be written when implementing NID support. Everything else is generic.

**Two real card formats (analysed from actual NID card images):**

```
FORMAT 1 — Smart NID (chip card, current format)
──────────────────────────────────────────────────────────────────
Y 0.00 ┌────────────────────────────────────────────────────────┐
        │ গণপ্রজাতন্ত্রী বাংলাদেশ সরকার                       │
        │ Government of the People's Republic of Bangladesh    │ [DOB stamp ↗]
        │ জাতীয় পরিচয়পত্র / National ID Card                 │
Y 0.22 ├──────────────────┬─────────────────────────────────────┤
        │                  │ নাম              ← label, NO colon  │
        │  [Photo]         │ মোঃ আবদুল্লাহ…  ← value next line  │
        │                  │ Name             ← label, NO colon  │
        │                  │ MD ABDULLAH…     ← value next line  │
        │                  │ পিতা             ← NO colon        │
        │                  │ ইউছুফ মজুমদার   ← Bengali only     │
        │                  │ মাতা             ← NO colon        │
        │                  │ আছিয়া খাতুন    ← Bengali only     │
Y 0.72  │                  │ Date of Birth  05 Oct 1957 .        │
        │  [Signature]     │ NID No.  595 537 5075               │
Y 1.00 └──────────────────┴─────────────────────────────────────┘

FORMAT 2 — Laminated NID (older format, still valid and in circulation)
──────────────────────────────────────────────────────────────────
Y 0.00 ┌────────────────────────────────────────────────────────┐
        │ গণপ্রজাতন্ত্রী বাংলাদেশ সরকার                       │
        │ Government of the People's Republic of Bangladesh    │
        │ National ID Card / জাতীয় পরিচয় পত্র               │
Y 0.20 ├──────────────┬─────────────────────────────────────────┤
        │              │ নাম:  জাওয়াদ আবদুল্লাহ ইউসুফ         │ ← WITH colon + value same line
        │  [Photo]     │ Name: ZAWAD ABDULLAH YOUSUF            │ ← WITH colon + value same line
        │              │ পিতা: মোস্তাক মজুমদার                │ ← Bengali only, no EN name
        │  [Signature] │ মাতা: জিনাত সুলতানা চৌধুরী           │ ← Bengali only, no EN name
        │              │ Date of Birth: 29 Oct 1999             │
        │              │ ID NO: 8254988119                      │ ← uppercase, no spaces
Y 1.00 └──────────────┴─────────────────────────────────────────┘
```

**Key corrections from previous plan (based on real card images):**
- `fathers_name_en` and `mothers_name_en` **removed** — neither format has
  English father/mother name fields. These fields do not exist on any BD NID card.
- Label anchors split into with-colon (Format 2) and without-colon (Format 1) variants
- `NID No.` added to NID anchors (Format 1 uses period, not colon)
- `NID No.` number has spaces in Format 1 — stripped automatically by `FieldType.digits`
- `photoXBoundary` lowered to 0.25 (Format 2 photo column is narrower than assumed)
- Y-zones widened to cover both formats; tighten after testing on real cards
- DOB decorative stamp (top-right, Format 1) is excluded by yZone starting at 0.65

```dart
// configs/nid_config.dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'document_parser_config.dart';
import 'document_type.dart';

/// Bangladesh National ID Card parser configuration.
/// Handles both Smart NID (chip card) and Laminated NID (older format).
///
/// Critical label behaviour difference:
///   Smart NID:  labels WITHOUT colon, value on the NEXT line
///   Laminated:  labels WITH colon, value on the SAME line
///
/// _extractAfterLabel handles both automatically:
///   1. checks same line after anchor  → catches Laminated format
///   2. falls back to next line        → catches Smart NID format
///
/// Y-zones below are widened to cover both layouts.
/// After testing on real cards, tighten yMin/yMax per field.

const nidConfig = DocumentParserConfig(
  documentType: DocumentType.bangladeshNid,
  // Format 2 photo column is ~25% wide, Format 1 ~30%.
  // 0.25 avoids clipping Format 2 text that starts closer to the left edge.
  photoXBoundary: 0.25,
  scripts: [
    TextRecognitionScript.devanagari, // Bengali/Indic script
    TextRecognitionScript.latin,      // English text
  ],
  fields: [
    FieldConfig(
      fieldKey: 'name_bn',
      displayLabel: 'নাম',
      labelAnchors: [
        'নাম:', 'নামঃ', 'নাম :', 'নাম: ',   // Format 2 (with colon)
        // Format 1 has bare "নাম" but matching standalone "নাম" risks
        // false positives. Rely on yZone spatial fallback for Format 1.
      ],
      yZone: (0.25, 0.48),
      type: FieldType.string,
    ),
    FieldConfig(
      fieldKey: 'name_en',
      displayLabel: 'Name (English)',
      labelAnchors: [
        'Name:', 'NAME:', 'Name :', 'Nane:',  // Format 2 (with colon)
        'Name',                               // Format 1 (no colon, standalone)
      ],
      yZone: (0.35, 0.58),
      type: FieldType.string,
    ),
    FieldConfig(
      fieldKey: 'fathers_name',
      displayLabel: 'পিতা',
      labelAnchors: [
        'পিতা:', 'পিতাঃ', 'পিতা :',         // Format 2 (with colon)
        'পিতা',                               // Format 1 (no colon)
      ],
      yZone: (0.45, 0.68),
      type: FieldType.string,
      // Both NID formats show father name in Bengali only.
      // NO English father name field exists on BD NID cards.
    ),
    FieldConfig(
      fieldKey: 'mothers_name',
      displayLabel: 'মাতা',
      labelAnchors: [
        'মাতা:', 'মাতাঃ', 'মাতা :',         // Format 2 (with colon)
        'মাতা',                               // Format 1 (no colon)
      ],
      yZone: (0.55, 0.78),
      type: FieldType.string,
      // Both NID formats show mother name in Bengali only.
      // NO English mother name field exists on BD NID cards.
    ),
    FieldConfig(
      fieldKey: 'dob',
      displayLabel: 'Date of Birth',
      labelAnchors: [
        'Date of Birth:', 'Date of Birth',    // both formats (EN label only)
        'DOB:', 'D.O.B:', 'Birth Date:',
        // NOTE: No Bengali DOB label observed on either card format.
        // The decorative DOB stamp (top-right, Format 1) is at ~Y 0.15
        // and excluded by this yZone starting at 0.65.
      ],
      yZone: (0.65, 0.88),
      type: FieldType.date,
      useEntityExtraction: true,
    ),
    FieldConfig(
      fieldKey: 'nid_no',
      displayLabel: 'NID Number',
      labelAnchors: [
        'NID No.', 'NID No:', 'NID No',  // Format 1 (period after No)
        'ID NO:', 'ID No:',              // Format 2 (uppercase, colon)
        '1D NO:', 'NID:',               // common OCR misreads
      ],
      yZone: (0.82, 0.99),
      type: FieldType.digits,
      // FieldType.digits strips spaces and non-digit chars automatically:
      //   Format 1: "595 537 5075" → "5955375075" (10 digits ✓)
      //   Format 2: "8254988119"   → "8254988119" (10 digits ✓)
      // Valid BD NID lengths: 10, 13, or 17 digits.
    ),
  ],
);
```

**Adding a new document type in the future — this is all that's needed:**
```dart
// configs/passport_config.dart  (future — ~35 lines)
const passportConfig = DocumentParserConfig(
  documentType: DocumentType.passport,   // add this to enum first
  photoXBoundary: 0.35,
  scripts: [TextRecognitionScript.latin],
  fields: [
    FieldConfig(fieldKey: 'surname',     displayLabel: 'Surname',      labelAnchors: ['Surname:'],      yZone: (0.20, 0.28)),
    FieldConfig(fieldKey: 'given_names', displayLabel: 'Given Names',  labelAnchors: ['Given Names:'],  yZone: (0.28, 0.36)),
    FieldConfig(fieldKey: 'passport_no', displayLabel: 'Passport No',  labelAnchors: ['Passport No:'],  yZone: (0.36, 0.44), type: FieldType.digits),
    FieldConfig(fieldKey: 'nationality', displayLabel: 'Nationality',  labelAnchors: ['Nationality:'],  yZone: (0.44, 0.52)),
    FieldConfig(fieldKey: 'dob',         displayLabel: 'Date of Birth',labelAnchors: ['Date of Birth:'],yZone: (0.52, 0.60), type: FieldType.date, useEntityExtraction: true),
    FieldConfig(fieldKey: 'expiry',      displayLabel: 'Expiry Date',  labelAnchors: ['Date of Expiry:'],yZone: (0.60, 0.68),type: FieldType.date, useEntityExtraction: true),
  ],
);
// Then: add DocumentType.passport to enum, register in configRegistry below.
// Zero changes to GenericDocumentParser, orchestrator, or UI.
```

---

### Task 4 — Config Registry (add to `document_type.dart`)

A single place that maps `DocumentType` → `DocumentParserConfig`.
This is the only place to touch when adding new document support.

```dart
// Add to document_type.dart

import 'nid_config.dart';
// Future: import 'passport_config.dart';

/// Registry of all supported document configs.
/// Add new document types here only — no other file needs changing.
final Map<DocumentType, DocumentParserConfig> configRegistry = {
  DocumentType.bangladeshNid: nidConfig,
  // Future:
  // DocumentType.passport: passportConfig,
  // DocumentType.drivingLicence: drivingLicenceConfig,
};

DocumentParserConfig configFor(DocumentType type) {
  final config = configRegistry[type];
  if (config == null) {
    throw UnimplementedError('No parser config registered for $type');
  }
  return config;
}
```

---

### Task 5 — `models/document_scan_result.dart`

Generic result model — works for any document type.

```dart
// models/document_scan_result.dart

class DocumentScanResult {
  final DocumentType documentType;

  /// Key-value pairs matching the fieldKey values in DocumentParserConfig.fields
  final Map<String, String?> fields;

  /// Number of fields successfully extracted (non-null, non-empty)
  final int extractionScore;

  /// Total fields attempted
  final int totalFields;

  /// Cropped image file path (from Document Scanner) for display
  final String imagePath;

  const DocumentScanResult({
    required this.documentType,
    required this.fields,
    required this.extractionScore,
    required this.totalFields,
    required this.imagePath,
  });

  double get extractionRate => totalFields == 0 ? 0 : extractionScore / totalFields;

  bool get isComplete => extractionScore == totalFields;
}
```

---

### Task 6 — `services/document_scan_service.dart` (Stage 1)

```dart
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

class DocumentScanService {
  Future<String?> scan() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.filter,
        pageLimit: 1,
        isGalleryImport: true,
      ),
    );
    try {
      final result = await scanner.scanDocument();
      if (result.images.isEmpty) return null;
      return result.images.first;
    } finally {
      scanner.close();
    }
  }
}
```

---

### Task 7 — `services/text_recognition_service.dart` (Stage 2)

Accepts a list of scripts from the config — runs one recognizer per script.

```dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class TextRecognitionService {
  final Map<TextRecognitionScript, TextRecognizer> _recognizers = {};

  /// Initialize recognizers for the scripts required by a document config.
  /// Call this before recognize() — call close() when done.
  void initForScripts(List<TextRecognitionScript> scripts) {
    close();
    for (final script in scripts) {
      _recognizers[script] = TextRecognizer(script: script);
    }
  }

  /// Run all initialized recognizers on the image.
  /// Returns one RecognizedText per script.
  Future<List<RecognizedText>> recognize(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final results = <RecognizedText>[];
    for (final recognizer in _recognizers.values) {
      results.add(await recognizer.processImage(input));
    }
    return results;
  }

  void close() {
    for (final r in _recognizers.values) {
      r.close();
    }
    _recognizers.clear();
  }
}
```

---

### Task 8 — `services/entity_extraction_service.dart` (Stage 3C assist)

```dart
import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';

class EntityExtractionService {
  final _extractor = EntityExtractor(
    language: EntityExtractorLanguage.english,
  );

  /// Extract a date string from OCR text. Returns the first date found, or null.
  Future<String?> extractDate(String text) async {
    if (text.trim().isEmpty) return null;
    try {
      final annotations = await _extractor.annotateText(text);
      for (final annotation in annotations) {
        for (final entity in annotation.entities) {
          if (entity.type == EntityType.dateTime) {
            return annotation.text;
          }
        }
      }
    } catch (_) {
      return null;   // entity extraction is a best-effort assist, never throw
    }
    return null;
  }

  Future<void> close() => _extractor.close();
}
```

---

### Task 9 — `services/generic_document_parser.dart` (Stage 3 engine)

**Written once. Never modified when adding new document types.**

```dart
import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../configs/document_parser_config.dart';
import 'entity_extraction_service.dart';

class GenericDocumentParser {
  final EntityExtractionService _entityExtraction;

  GenericDocumentParser(this._entityExtraction);

  /// Parse all fields defined in [config] from the recognized text results.
  /// [recognizedTexts] — one entry per script (e.g. Indic + Latin)
  /// [imageSize] — dimensions of the cropped image for spatial normalization
  Future<Map<String, String?>> parse({
    required List<RecognizedText> recognizedTexts,
    required DocumentParserConfig config,
    required Size imageSize,
  }) async {
    // Merge all recognized text into one string for label-anchor parsing
    final fullText = recognizedTexts.map((r) => r.text).join('\n');

    final result = <String, String?>{};

    for (final field in config.fields) {
      // Strategy A — label-anchor (primary)
      String? value = _extractByLabel(fullText, field.labelAnchors);

      // Strategy B — spatial fallback
      if (_isEmpty(value) && field.yZone != null) {
        value = _extractByZone(
          recognizedTexts: recognizedTexts,
          yZone: field.yZone!,
          photoXBoundary: config.photoXBoundary,
          imageSize: imageSize,
        );
      }

      // Strategy C — entity extraction assist for date fields
      if (field.useEntityExtraction && !_isEmpty(value)) {
        final entityDate = await _entityExtraction.extractDate(value!);
        if (!_isEmpty(entityDate)) value = entityDate;
      } else if (field.useEntityExtraction && _isEmpty(value)) {
        // Try entity extraction on the full latin text as last resort for dates
        final latinText = recognizedTexts
            .map((r) => r.text)
            .join('\n');
        value = await _entityExtraction.extractDate(latinText);
      }

      // Apply type-specific post-processing
      result[field.fieldKey] = _applyType(value, field.type);
    }

    return result;
  }

  // ── Strategy A — Label-anchor ───────────────────────────────────────────

  String? _extractByLabel(String fullText, List<String> anchors) {
    final lines = fullText.split('\n').map((l) => l.trim()).toList();

    for (final anchor in anchors) {
      for (int i = 0; i < lines.length; i++) {
        // Case-insensitive contains check — tolerates OCR spacing noise
        if (lines[i].toLowerCase().contains(anchor.toLowerCase())) {
          // Check if value is on the same line after the anchor
          final idx = lines[i].toLowerCase().indexOf(anchor.toLowerCase());
          final afterAnchor = lines[i].substring(idx + anchor.length).trim();
          if (!_isEmpty(afterAnchor)) return afterAnchor;

          // Otherwise take the next non-empty line
          for (int j = i + 1; j < lines.length; j++) {
            if (!_isEmpty(lines[j])) return lines[j].trim();
          }
        }
      }
    }
    return null;
  }

  // ── Strategy B — Spatial zone ───────────────────────────────────────────

  String? _extractByZone({
    required List<RecognizedText> recognizedTexts,
    required (double yMin, double yMax) yZone,
    required double photoXBoundary,
    required Size imageSize,
  }) {
    final h = imageSize.height;
    final w = imageSize.width;
    final (yMin, yMax) = yZone;

    final candidates = <({String text, double x, double y})>[];

    for (final recognized in recognizedTexts) {
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          final rect = line.boundingBox;
          final yNorm = (rect.top + rect.height / 2) / h;
          final xNorm = (rect.left + rect.width / 2) / w;

          if (yNorm >= yMin && yNorm <= yMax && xNorm > photoXBoundary) {
            candidates.add((text: line.text, x: xNorm, y: yNorm));
          }
        }
      }
    }

    if (candidates.isEmpty) return null;

    // Sort left-to-right within the zone, join
    candidates.sort((a, b) => a.x.compareTo(b.x));
    return candidates.map((c) => c.text).join(' ').trim();
  }

  // ── Type post-processing ────────────────────────────────────────────────

  String? _applyType(String? raw, FieldType type) {
    if (_isEmpty(raw)) return null;
    switch (type) {
      case FieldType.string:
        return raw!.trim();
      case FieldType.digits:
        final digits = raw!.replaceAll(RegExp(r'\D'), '');
        // Validate BD NID length (10, 13, or 17 digits)
        if (digits.length == 10 || digits.length == 13 || digits.length == 17) {
          return digits;
        }
        return digits.isEmpty ? null : digits;  // return anyway, let UI flag it
      case FieldType.date:
        return raw!.trim();  // entity extraction already normalized it
    }
  }

  bool _isEmpty(String? s) => s == null || s.trim().isEmpty;
}
```

---

### Task 10 — `services/document_scan_orchestrator.dart`

Wires all three stages together. Accepts a `DocumentType`, looks up its config,
runs the full pipeline, returns a `DocumentScanResult`.

```dart
import 'dart:ui';
import 'dart:io';
import 'package:flutter/painting.dart';
import '../configs/document_type.dart';
import '../models/document_scan_result.dart';
import 'document_scan_service.dart';
import 'text_recognition_service.dart';
import 'entity_extraction_service.dart';
import 'generic_document_parser.dart';

class DocumentScanOrchestrator {
  final _scanService       = DocumentScanService();
  final _textService       = TextRecognitionService();
  final _entityService     = EntityExtractionService();
  late final _parser       = GenericDocumentParser(_entityService);

  Future<DocumentScanResult?> scan(DocumentType documentType) async {
    // Look up config from registry — throws if unregistered type
    final config = configFor(documentType);

    // Stage 1 — Document Scanner
    final imagePath = await _scanService.scan();
    if (imagePath == null) return null;  // user cancelled

    // Stage 2 — Text Recognition (using scripts from config)
    _textService.initForScripts(config.scripts);
    final recognizedTexts = await _textService.recognize(imagePath);

    // Get image dimensions for spatial parsing
    final imageSize = await _getImageSize(imagePath);

    // Stage 3 — Config-driven parsing
    final fields = await _parser.parse(
      recognizedTexts: recognizedTexts,
      config: config,
      imageSize: imageSize,
    );

    final extractionScore = fields.values
        .where((v) => v != null && v.isNotEmpty)
        .length;

    return DocumentScanResult(
      documentType: documentType,
      fields: fields,
      extractionScore: extractionScore,
      totalFields: config.fields.length,
      imagePath: imagePath,
    );
  }

  Future<Size> _getImageSize(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
  }

  void dispose() {
    _textService.close();
    _entityService.close();
  }
}
```

---

### Task 11 — `screens/document_scanner_screen.dart`

Screen is generic — renders whatever fields `DocumentScanResult` returns.
No NID-specific code in the UI layer.

```dart
// document_scanner_screen.dart

class DocumentScannerScreen extends StatefulWidget {
  final DocumentType documentType;   // passed in from caller
  const DocumentScannerScreen({required this.documentType, super.key});
  ...
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  final _orchestrator = DocumentScanOrchestrator();
  DocumentScanResult? _result;
  bool _loading = false;
  String? _error;

  Future<void> _scan() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _orchestrator.scan(widget.documentType);
      setState(() { _result = result; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  void dispose() {
    _orchestrator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = configFor(widget.documentType);
    return Scaffold(
      appBar: AppBar(title: Text(widget.documentType.displayName)),
      body: Column(
        children: [
          if (!_loading && _result == null)
            _ScanPrompt(
              instruction: widget.documentType.scanInstruction,
              onScan: _scan,
            ),
          if (_loading)
            const _LoadingIndicator(),
          if (_result != null)
            _ResultView(result: _result!, config: config, onRescan: _scan),
          if (_error != null)
            _ErrorView(error: _error!, onRetry: _scan),
        ],
      ),
    );
  }
}
```

---

### Task 12 — `widgets/scan_result_card.dart`

Renders a `DocumentScanResult` generically — iterates `config.fields` for display
labels, looks up values from `result.fields`. No document-specific logic.

```dart
class ScanResultCard extends StatefulWidget {
  final DocumentScanResult result;
  final DocumentParserConfig config;
  ...
}

// For each field in config.fields:
//   display config.field.displayLabel on the left
//   display result.fields[field.fieldKey] ?? '—' on the right
//   allow inline editing (TextField) so user can correct OCR errors
//   show extraction rate badge: "6/8 fields extracted"
```

---

## UI Design

Four screens covering the complete user journey. All screens are generic — they work
for any document type, not just NID. The design is implemented in
`document_scanner_screen.dart` and `scan_result_card.dart`.

---

### Screen 1 — Document type selection

Entry point. User selects which document to scan. Supported types are active;
future types show a "Soon" badge. When a new config is registered, the badge
disappears automatically — no UI code changes.

```
┌─────────────────────────────────────┐
│ 9:41                            ●●● │
├─────────────────────────────────────┤
│ Scan document                       │
│ Select a document type              │
├─────────────────────────────────────┤
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 🪪  Bangladesh NID        [✓]  │ │  ← selected (2px blue border)
│ │     National Identity Card      │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 🛂  Passport          [Soon]   │ │  ← future type (greyed badge)
│ │     International travel doc    │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 🚗  Driving licence   [Soon]   │ │
│ │     BRTA issued licence         │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │          Continue →             │ │  ← primary CTA (blue, full width)
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

**Behaviour:**
- Tapping an active item selects it (2px blue border + "Selected" badge)
- Tapping a "Soon" item does nothing (no navigation)
- "Continue" is always enabled once one type is selected
- `DocumentType` enum drives this list — no hardcoded document names in the UI

---

### Screen 2 — Scan

ML Kit Document Scanner launches as a full-screen native view.
This screen shows before the scanner opens — it provides instruction and
lets the user choose between camera scan or gallery import.

```
┌─────────────────────────────────────┐
│ 9:41                            ●●● │
├─────────────────────────────────────┤
│ ←  Bangladesh NID                   │
│     Position card in the frame      │
├─────────────────────────────────────┤
│                                     │
│ ┌─────────────────────────────────┐ │
│ │                                 │ │
│ │    ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┐    │ │
│ │    │                      │    │ │  ← dashed card outline
│ │    │   Align card here    │    │ │     corner indicators in blue
│ │    │                      │    │ │
│ │    └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┘    │ │
│ │                                 │ │
│ └─────────────────────────────────┘ │
│                                     │
│  Place the NID card flat and ensure │
│  all text is clearly visible        │
│                                     │
│  ┌──────────────┐ ┌───────────────┐ │
│  │   Gallery    │ │  📷  Scan    │ │
│  └──────────────┘ └───────────────┘ │
└─────────────────────────────────────┘
```

**Behaviour:**
- "Scan" button opens ML Kit Document Scanner (`DocumentScanService.scan()`)
- "Gallery" opens image picker (`isGalleryImport: true`)
- ML Kit handles the edge detection, crop, and perspective correction internally
- After scan completes, navigate to Screen 3 automatically

---

### Screen 3 — Processing

Shown while Stages 2 and 3 run (text recognition + field parsing).
Displays the cropped card image as confirmation + a live stage progress list.

```
┌─────────────────────────────────────┐
│ 9:41                            ●●● │
├─────────────────────────────────────┤
│ Extracting information              │
│ Bangladesh NID                      │
├─────────────────────────────────────┤
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ [photo] ════════════════════   │ │  ← cropped NID preview
│ │  col   ════════════════        │ │     actual scanned image
│ │        ══════════════════      │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │  ◌  Reading text...            │ │  ← spinner + label
│ │  This may take a few seconds   │ │
│ │                                 │ │
│ │  ● Document scanned and cropped │ │  ← green dot (done)
│ │  ◉ Recognising Bengali + EN    │ │  ← blue pulsing dot (active)
│ │  ○ Extracting fields           │ │  ← grey dot (pending)
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

**Behaviour:**
- Stage dots update in real time as each stage completes
- Stage labels come from the pipeline — not hardcoded per document type
- Cannot go back during processing (AppBar back button disabled)
- On completion, automatically navigate to Screen 4
- On error, show an error card with a "Try again" button

---

### Screen 4 — Results

The most important screen. Shows all extracted fields with confidence indicator.
Every field is editable. Undetected fields are visible and prompt manual entry.

```
┌─────────────────────────────────────┐
│ 9:41                            ●●● │
├─────────────────────────────────────┤
│ ←  Extracted fields                 │
│     Tap any field to edit           │
├─────────────────────────────────────┤
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 5 / 5 fields  █████████  100% │ │  ← extraction score bar (blue)
│ └─────────────────────────────────┘ │
│                                     │
│ নাম (Bengali name)                  │
│ মোঃ করিম হোসেন          [Edit]    │
│ ─────────────────────────────────── │
│ Name (English)                      │
│ Md. Karim Hossain        [Edit]    │
│ ─────────────────────────────────── │
│ পিতা                                │
│ মোঃ রহিম হোসেন          [Edit]    │
│ ─────────────────────────────────── │
│ মাতা                                │
│ ফাতেমা বেগম              [Edit]    │
│ ─────────────────────────────────── │
│ Date of birth                       │
│ 01 Jan 1990              [Edit]    │
│ ─────────────────────────────────── │
│ NID number                          │
│ 3719842610               [Edit]    │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ Review fields before confirming │ │  ← amber warning note
│ └─────────────────────────────────┘ │
│                                     │
│  ┌───────────┐  ┌─────────────────┐ │
│  │  Rescan   │  │   Confirm →    │ │
│  └───────────┘  └─────────────────┘ │
└─────────────────────────────────────┘
```

**Behaviour:**
- Field rows are rendered by iterating `config.fields` — generic, not NID-specific
- Display label comes from `FieldConfig.displayLabel`
- Value comes from `DocumentScanResult.fields[fieldKey]`
- Null/empty fields show "Not detected — tap to enter" in muted italic
- Tapping any row (detected or not) opens an inline `TextField` for editing
- Extraction score bar: `extractionScore / totalFields` from `DocumentScanResult`
- "Rescan" → back to Screen 2
- "Confirm" → passes the final (possibly edited) `Map<String, String?>` to the caller

---

### UI colour conventions

| Element | Colour |
|---|---|
| Primary action (CTA, confirm) | Blue — `#185FA5` |
| Selected state border | Blue — `#185FA5`, 2px |
| Extraction score bar | Blue fill on blue-tinted background |
| Active stage indicator | Blue pulsing dot |
| Completed stage indicator | Teal/green dot |
| Warning note (review fields) | Amber background `#FAEEDA`, dark amber text |
| Missing field text | Muted italic, `color-text-tertiary` |
| "Soon" badge | Neutral secondary background |
| Card borders | `0.5px solid color-border-tertiary` |
| All surfaces | White / `color-background-primary` |

---

### UI implementation notes for Claude Code

- Field list in Screen 4 is built with `ListView.builder` iterating
  `config.fields` — never a hardcoded list of NID field names.
- Each field row is a `StatefulWidget` that toggles between display mode
  (`Text`) and edit mode (`TextField`) on tap.
- The extraction score bar is a `LinearProgressIndicator` with value
  `result.extractionRate` (0.0–1.0).
- Stage progress in Screen 3 is driven by a `ValueNotifier<int>` that the
  orchestrator updates after each stage completes.
- "Soon" items in Screen 1 are determined by checking if `configRegistry`
  contains the `DocumentType` — no separate `isAvailable` flag needed.
- All screen transitions use `Navigator.push` — no named routes required for
  this feature.
- Screen 3 disables the system back button during processing using
  `PopScope(canPop: false, ...)` to prevent partial-state navigation.

---

## Implementation Order for Claude Code

Implement strictly in this order — each file depends on those above it:

1. Task 1 — `configs/document_type.dart` (enum only, no registry yet)
2. Task 2 — `configs/document_parser_config.dart`
3. Task 3 — `configs/nid_config.dart`
4. Task 4 — add registry + `configFor()` to `document_type.dart`
5. Task 5 — `models/document_scan_result.dart`
6. Task 6 — `services/document_scan_service.dart`
7. Task 7 — `services/text_recognition_service.dart`
8. Task 8 — `services/entity_extraction_service.dart`
9. Task 9 — `services/generic_document_parser.dart`
10. Task 10 — `services/document_scan_orchestrator.dart`
11. Task 11 — `screens/document_scanner_screen.dart`
12. Task 12 — `widgets/scan_result_card.dart`
13. Add dependencies to `pubspec.yaml`, set `minSdkVersion 21`

---

## How to Add Passport Support (Future — Reference)

This is the complete list of changes required to add a new document type.
No existing file is modified except where noted with a ✏️.

| Step | File | Change |
|---|---|---|
| 1 | `configs/document_type.dart` ✏️ | Add `passport` to `DocumentType` enum + display name/instruction |
| 2 | `configs/passport_config.dart` | Create new file (~35 lines) |
| 3 | `configs/document_type.dart` ✏️ | Import passport config, add to `configRegistry` map |

That's it. `GenericDocumentParser`, orchestrator, screen, and result card all work
unchanged with the new document type.

---

## Pros & Cons Analysis

### Overall Approach

| | Pros | Cons |
|---|---|---|
| Fully on-device | No internet, no server cost, instant response, privacy-preserving | Accuracy ceiling is lower than server-side VLM |
| Config-driven design | New document = ~35 lines, no engine changes | Y-zone calibration requires real image testing per document type |
| ML Kit | Free, Google-maintained, fast on-device | Not fine-tuned for BD NID specifically |
| Flutter | Single codebase | ML Kit Document Scanner is Android-only |

### Stage 1 — Document Scanner

**Pros:** Built-in perspective correction, edge detection, scanning UI — all free.
Dramatically improves OCR accuracy on the cropped output.

**Cons:** Native full-screen UI, limited Flutter customization. Fails gracefully
only if card edges are clearly distinguishable from the background.

### Stage 2 — Text Recognition v2

**Pros:** Bengali (Indic) + Latin in one SDK. Returns bounding boxes enabling
spatial parsing. Fast (~200–500ms). On-device.

**Cons:** Two recognizer passes needed for bilingual documents. Bengali accuracy
lower than English. No per-character confidence score.

### Stage 3 — Parsing

**Strategy A (label-anchor):** Fast, deterministic, easy to debug. Fails if the
label itself is misread. Mitigate by including OCR-error variants in `labelAnchors`.

**Strategy B (spatial):** Works regardless of label quality. Requires Y-zone
calibration on real NID images. Sensitive to crop alignment.

**Strategy C (entity extraction):** Excellent for date normalization. English-only,
no custom entities. Use only for `FieldType.date` fields.

### Honest Accuracy Expectations

For clean, flat, well-lit images:

| Field | Expected accuracy |
|---|---|
| NID number | ~95% (digits, format-validatable) |
| Date of birth | ~90% |
| English name | ~85% |
| Bengali name | ~75% |
| Bengali father/mother name | ~70% |

Worn, folded, or poor-lighting cards: subtract 15–30% from all values.
Always show a confirmation step — never auto-submit OCR output.

---

## Notes for Claude Code

- The feature folder is named `document_scanner`, not `nid_scanner`. This is
  intentional and must not be changed — it reflects the generic scope of the feature.

- `nid_config.dart` Y-zone values are estimates. After implementation, test on 10+
  real NID images, log the normalized Y positions of each detected line, and calibrate
  `yMin`/`yMax` values in `nid_config.dart`. No other file needs changing.

- `TextRecognitionScript.devanagari` is used for Bengali. If accuracy is poor in
  testing, also try `TextRecognitionScript.chinese` — it covers more scripts in some
  ML Kit versions. Update `nid_config.scripts` only.

- Always call `orchestrator.dispose()` in the screen's `dispose()` method to free
  ML Kit native recognizer memory.

- `GenericDocumentParser` must never contain any document-specific logic (no `if
  documentType == bangladeshNid` branches). If a document needs special parsing
  behaviour beyond label/spatial/entity, introduce a `customParser` field on
  `DocumentParserConfig` that accepts an optional function.

- Run Stage 2 + Stage 3 in a `compute()` isolate if UI jank is observed on
  low-end devices — ML Kit async calls can still block the UI thread on some
  devices.

- `configFor()` throws `UnimplementedError` for unregistered document types.
  This is intentional — it surfaces missing registrations at development time,
  not silently at runtime.
