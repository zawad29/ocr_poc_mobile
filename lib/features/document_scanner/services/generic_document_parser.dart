import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../configs/document_parser_config.dart';
import 'entity_extraction_service.dart';

/// Document-type-agnostic parser. Each [DocumentParserConfig] declares its
/// fields; this engine picks the value for each field by trying a fixed
/// strategy ladder and never branches on document type.
class GenericDocumentParser {
  final EntityExtractionService _entityExtraction;

  GenericDocumentParser(this._entityExtraction);

  /// Per-field strategy ladder, in order of preference:
  ///   1. valueRegex     — pattern match against the full OCR text
  ///   2. labelAnchors   — find a label, take what follows
  ///   3. (yZone, xZone) — pick lines whose bbox falls in a normalized
  ///                       region of the image (true position-based)
  ///   4. entity extraction — ML Kit date normaliser, applied either to
  ///      the value found above OR (as a last resort) to the full text
  ///
  /// First strategy that returns a non-empty value wins. Each field's
  /// config picks which strategies are even attempted.
  Future<Map<String, String?>> parse({
    required List<RecognizedText> recognizedTexts,
    required DocumentParserConfig config,
    required Size imageSize,
  }) async {
    final fullText = recognizedTexts.map((r) => r.text).join('\n');

    debugPrint('========== PARSER START [${config.documentType.name}] ==========');
    debugPrint('imageSize=${imageSize.width.toInt()}x${imageSize.height.toInt()}');

    final result = <String, String?>{};

    // Pool of all label strings used by any field. Zone extraction will skip
    // these so a field's zone never returns its own (or a sibling's) label.
    final globalAnchors = <String>{
      for (final f in config.fields)
        for (final a in f.labelAnchors) a.trim().toLowerCase(),
    };

    // Build a y-coordinate remap (identity if no anchors configured) so all
    // configured zones realign against this particular scan's framing —
    // see _computeYMapping.
    final double Function(double) mapY =
        _computeYMapping(recognizedTexts, config, imageSize);

    for (final field in config.fields) {
      String strategy = 'none';
      String? value;

      // Strategy 1: regex — strongest signal when a field has a stable
      // pattern (e.g. "of <institution name> School").
      if (field.valueRegex != null) {
        final m = field.valueRegex!.firstMatch(fullText);
        if (m != null && m.groupCount >= 1) {
          value = m.group(1)?.trim();
          if (!_isEmpty(value)) strategy = 'regex';
        }
      }

      // Strategy 2: label anchor — find label text, take what follows.
      // Reliable for single-column layouts where reading order puts the
      // value next to / below the label.
      if (_isEmpty(value)) {
        value = _extractByLabel(fullText, field.labelAnchors);
        if (!_isEmpty(value)) strategy = 'label';
      }

      // Strategy 3: spatial zone — for fixed-layout documents (tables,
      // columnar forms) where labels collide or reading order is unreliable.
      // The yZone is remapped through mapY so zones track scan-crop drift.
      if (_isEmpty(value) && field.yZone != null) {
        final (yMin, yMax) = field.yZone!;
        value = _extractByZone(
          recognizedTexts: recognizedTexts,
          yZone: (mapY(yMin), mapY(yMax)),
          xZone: field.xZone,
          photoXBoundary: config.photoXBoundary,
          imageSize: imageSize,
          globalAnchors: globalAnchors,
        );
        if (!_isEmpty(value)) strategy = 'zone';
      }

      // Strategy 4: ML Kit entity extraction (dates only).
      // - If we already have a value, normalise it (e.g. "29 OCTOBER 1999"
      //   → ISO form when supported).
      // - If no strategy found anything, scan the entire OCR text for *any*
      //   date as a desperation fallback. May pick the wrong date when the
      //   doc has multiple — only useful when we know there's just one.
      if (field.useEntityExtraction && !_isEmpty(value)) {
        final entityDate = await _entityExtraction.extractDate(value!);
        if (!_isEmpty(entityDate)) {
          value = entityDate;
          strategy = '$strategy+entity';
        }
      } else if (field.useEntityExtraction && _isEmpty(value)) {
        final latinText = recognizedTexts.map((r) => r.text).join('\n');
        value = await _entityExtraction.extractDate(latinText);
        if (!_isEmpty(value)) strategy = 'entity-fallback';
      }

      final processed = _applyType(value, field);
      result[field.fieldKey] = processed;
      debugPrint(
          '  [${field.fieldKey}] strategy=$strategy raw="${value ?? ''}" final="${processed ?? ''}"');
    }

    debugPrint('========== PARSER END ==========');
    debugPrint('PARSED: $result');
    return result;
  }

  /// Label-anchor extraction. For each anchor in priority order, walks lines
  /// of the OCR text looking for one that contains it. When a match is found:
  ///   - First, take whatever follows the anchor on the same line
  ///     (Laminated-NID style: "Name: ZAWAD ABDULLAH").
  ///   - Else fall back to the next non-empty line
  ///     (Smart-NID style: label one line, value the next).
  /// Anchors are tried in the order the config lists them, so put the most
  /// specific variants ("Date of Birth:", "DOB:") before bare prefixes.
  String? _extractByLabel(String fullText, List<String> anchors) {
    final lines = fullText.split('\n').map((l) => l.trim()).toList();

    for (final anchor in anchors) {
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].toLowerCase().contains(anchor.toLowerCase())) {
          final idx = lines[i].toLowerCase().indexOf(anchor.toLowerCase());
          final afterAnchor = lines[i].substring(idx + anchor.length).trim();
          if (!_isEmpty(afterAnchor)) return afterAnchor;

          for (int j = i + 1; j < lines.length; j++) {
            if (!_isEmpty(lines[j])) return lines[j].trim();
          }
        }
      }
    }
    return null;
  }

  /// Builds a function that maps a config-space y (where zones were calibrated)
  /// to an OCR-space y for *this particular scan*. Returns identity if the
  /// config declares no anchors or none are found.
  ///
  /// Why: the document scanner crops/scales each capture differently, so a
  /// fixed normalized yZone like (0.46, 0.51) shifts off the intended row
  /// across captures. We compensate by finding landmark text whose position
  /// is known and re-projecting all zones accordingly.
  ///
  /// Three modes, in falling order of correction power:
  ///   - Two anchors (top + bottom): linear remap absorbing both
  ///     **translation** (where the doc starts) and **vertical scale**
  ///     (how stretched/compressed it is). Most robust.
  ///   - One anchor: uniform offset only. Fixes translation, not scale.
  ///   - None / not found: identity (zones used as-declared).
  double Function(double) _computeYMapping(
    List<RecognizedText> recognizedTexts,
    DocumentParserConfig config,
    Size imageSize,
  ) {
    final h = imageSize.height;
    final topActual = _findAnchorY(recognizedTexts, config.yAnchor, h);
    final bottomActual =
        _findAnchorY(recognizedTexts, config.yAnchorBottom, h);
    final topExpected = config.yAnchorExpected;
    final bottomExpected = config.yAnchorBottomExpected;

    // Two-anchor mode: linear interpolation. Pin config-space topExpected to
    // topActual and bottomExpected to bottomActual; everything else scales
    // linearly. The (>1e-6) guard rejects degenerate configs that would
    // collapse to division by zero.
    if (topActual != null &&
        bottomActual != null &&
        topExpected != null &&
        bottomExpected != null &&
        (bottomExpected - topExpected).abs() > 1e-6) {
      final scale =
          (bottomActual - topActual) / (bottomExpected - topExpected);
      debugPrint(
          'yAnchor remap: top=${topActual.toStringAsFixed(4)} bottom=${bottomActual.toStringAsFixed(4)} scale=${scale.toStringAsFixed(3)}');
      return (y) => topActual + (y - topExpected) * scale;
    }

    // Single-anchor mode: shift every y by a constant.
    if (topActual != null && topExpected != null) {
      final offset = topActual - topExpected;
      debugPrint('yAnchor offset=${offset.toStringAsFixed(4)} (single-anchor)');
      return (y) => y + offset;
    }

    if (config.yAnchor != null) {
      debugPrint('yAnchor "${config.yAnchor}" not found — no remap');
    }
    return (y) => y;
  }

  /// Returns the normalized y-center of the first OCR line containing
  /// [anchor] (case-insensitive substring match). Pick anchor strings that
  /// occur exactly once in the document AND that ML Kit reliably keeps as a
  /// single TextLine — short single words are safest because multi-word
  /// labels can split across lines under noisy OCR.
  double? _findAnchorY(
      List<RecognizedText> recognizedTexts, String? anchor, double h) {
    if (anchor == null) return null;
    final needle = anchor.toLowerCase();
    for (final recognized in recognizedTexts) {
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          if (line.text.toLowerCase().contains(needle)) {
            final rect = line.boundingBox;
            return (rect.top + rect.height / 2) / h;
          }
        }
      }
    }
    return null;
  }

  /// Spatial extraction: pick OCR lines whose bbox center falls inside the
  /// (already remapped) yZone — and, if [xZone] is provided, also inside that
  /// horizontal band. Then reduce the surviving lines to a single string.
  ///
  /// X-filtering modes:
  ///   - xZone set: column-based parsing for tabular layouts where multiple
  ///     values share the same y. The <4-char filter is disabled in this
  ///     mode because column isolation makes short legitimate values like
  ///     "MALE" or "M" safe.
  ///   - xZone null: legacy left-cutoff via [photoXBoundary] (excludes the
  ///     photo column on ID cards).
  ///
  /// Reduction strategy after filtering:
  ///   - Drop empties, drop lines that match any global label, dedup
  ///     identical text.
  ///   - 1 survivor: return it.
  ///   - Multiple, all within 0.05 normalized-y of each other: assume they
  ///     are word-fragments of one wrapped line and join with spaces (e.g.
  ///     "MD ABDULLAH" + "AL MOSTAQ MAZUMDER").
  ///   - Multiple, vertically separated: pick the longest. Heuristic
  ///     assumes the "value" line is longer than incidental neighbours
  ///     (headers, decorations) — works often, fails on ties.
  String? _extractByZone({
    required List<RecognizedText> recognizedTexts,
    required (double yMin, double yMax) yZone,
    (double xMin, double xMax)? xZone,
    required double photoXBoundary,
    required Size imageSize,
    required Set<String> globalAnchors,
  }) {
    final h = imageSize.height;
    final w = imageSize.width;
    final (yMin, yMax) = yZone;

    // 1. Collect every OCR line whose bbox center falls inside (yZone, xZone).
    //    Center-based (rather than edge-based) so a line that slightly spills
    //    over a boundary is still attributed to its dominant zone.
    final raw = <({String text, double x, double y})>[];

    for (final recognized in recognizedTexts) {
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          final rect = line.boundingBox;
          final yNorm = (rect.top + rect.height / 2) / h;
          final xNorm = (rect.left + rect.width / 2) / w;

          if (yNorm < yMin || yNorm > yMax) continue;
          if (xZone != null) {
            if (xNorm < xZone.$1 || xNorm > xZone.$2) continue;
          } else {
            if (xNorm <= photoXBoundary) continue;
          }
          raw.add((text: line.text, x: xNorm, y: yNorm));
        }
      }
    }

    if (raw.isEmpty) return null;

    // 2. Filter noise: empty lines, label text from any field, OCR specks
    //    (only when no xZone — column isolation makes the length filter
    //    counterproductive). Dedup exact text repeats from multiple
    //    recognizers (Latin + Devanagari often see the same line).
    final seen = <String>{};
    final filtered = <({String text, double x, double y})>[];
    for (final c in raw) {
      final t = c.text.trim();
      if (t.isEmpty) continue;
      if (globalAnchors.contains(t.toLowerCase())) continue;
      if (xZone == null && t.replaceAll(RegExp(r'\s'), '').length < 4) continue;
      if (!seen.add(t)) continue;
      filtered.add(c);
    }

    if (filtered.isEmpty) return null;

    // 3. Sort top-to-bottom, then left-to-right within the same row, so the
    //    join in step 4 produces words in reading order.
    filtered.sort((a, b) {
      final dy = a.y.compareTo(b.y);
      return dy != 0 ? dy : a.x.compareTo(b.x);
    });

    if (filtered.length == 1) return filtered.first.text.trim();

    // 4. If every surviving line is within wrapTolerance of every other, treat
    //    them as fragments of one wrapped value (e.g. ML Kit splitting a long
    //    name into two TextLines) and join with spaces.
    final wrapTolerance = 0.05;
    bool allAdjacent = true;
    for (int i = 1; i < filtered.length; i++) {
      if ((filtered[i].y - filtered[i - 1].y).abs() > wrapTolerance) {
        allAdjacent = false;
        break;
      }
    }
    if (allAdjacent) {
      return filtered.map((c) => c.text.trim()).join(' ');
    }

    // 5. Mixed y-positions: lines belong to different rows. Pick the longest
    //    string and hope it is the value rather than a stray header. Fragile
    //    when zones are too tall — calibrate zones tightly to avoid this path.
    filtered.sort((a, b) => b.text.length.compareTo(a.text.length));
    return filtered.first.text.trim();
  }

  /// Post-extraction normalisation. Runs after every strategy succeeds.
  ///
  /// - string: optionally filter to [FieldConfig.allowedCharsRegex] (e.g. keep
  ///   only Bengali letters for a Bengali name). Whitespace is collapsed.
  /// - digits: strip everything that isn't 0-9, then enforce
  ///   [FieldConfig.validDigitLengths] if set. ID numbers are critical — a
  ///   wrong-length value is nulled out rather than handed back as if valid.
  /// - date: untouched (entity extraction handles normalisation upstream).
  String? _applyType(String? raw, FieldConfig field) {
    if (_isEmpty(raw)) return null;
    switch (field.type) {
      case FieldType.string:
        var s = raw!;
        if (field.allowedCharsRegex != null) {
          final allowed = field.allowedCharsRegex!;
          final buf = StringBuffer();
          for (final ch in s.split('')) {
            if (allowed.hasMatch(ch)) buf.write(ch);
          }
          s = buf.toString();
        }
        s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
        return s.isEmpty ? null : s;
      case FieldType.digits:
        final digits = raw!.replaceAll(RegExp(r'\D'), '');
        if (digits.isEmpty) return null;
        final lengths = field.validDigitLengths;
        if (lengths != null && !lengths.contains(digits.length)) return null;
        return digits;
      case FieldType.date:
        return raw!.trim();
    }
  }

  bool _isEmpty(String? s) => s == null || s.trim().isEmpty;
}
