import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../configs/document_parser_config.dart';
import 'entity_extraction_service.dart';

class GenericDocumentParser {
  final EntityExtractionService _entityExtraction;

  GenericDocumentParser(this._entityExtraction);

  Future<Map<String, String?>> parse({
    required List<RecognizedText> recognizedTexts,
    required DocumentParserConfig config,
    required Size imageSize,
  }) async {
    final fullText = recognizedTexts.map((r) => r.text).join('\n');

    debugPrint('========== PARSER START [${config.documentType.name}] ==========');
    debugPrint('imageSize=${imageSize.width.toInt()}x${imageSize.height.toInt()}');

    final result = <String, String?>{};

    final globalAnchors = <String>{
      for (final f in config.fields)
        for (final a in f.labelAnchors) a.trim().toLowerCase(),
    };

    final double Function(double) mapY =
        _computeYMapping(recognizedTexts, config, imageSize);

    for (final field in config.fields) {
      String strategy = 'none';
      String? value;

      if (field.valueRegex != null) {
        final m = field.valueRegex!.firstMatch(fullText);
        if (m != null && m.groupCount >= 1) {
          value = m.group(1)?.trim();
          if (!_isEmpty(value)) strategy = 'regex';
        }
      }

      if (_isEmpty(value)) {
        value = _extractByLabel(fullText, field.labelAnchors);
        if (!_isEmpty(value)) strategy = 'label';
      }

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

      final processed = _applyType(value, field.type);
      result[field.fieldKey] = processed;
      debugPrint(
          '  [${field.fieldKey}] strategy=$strategy raw="${value ?? ''}" final="${processed ?? ''}"');
    }

    debugPrint('========== PARSER END ==========');
    debugPrint('PARSED: $result');
    return result;
  }

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

    filtered.sort((a, b) {
      final dy = a.y.compareTo(b.y);
      return dy != 0 ? dy : a.x.compareTo(b.x);
    });

    if (filtered.length == 1) return filtered.first.text.trim();

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

    filtered.sort((a, b) => b.text.length.compareTo(a.text.length));
    return filtered.first.text.trim();
  }

  String? _applyType(String? raw, FieldType type) {
    if (_isEmpty(raw)) return null;
    switch (type) {
      case FieldType.string:
        return raw!.trim();
      case FieldType.digits:
        final digits = raw!.replaceAll(RegExp(r'\D'), '');
        if (digits.length == 10 || digits.length == 13 || digits.length == 17) {
          return digits;
        }
        return digits.isEmpty ? null : digits;
      case FieldType.date:
        return raw!.trim();
    }
  }

  bool _isEmpty(String? s) => s == null || s.trim().isEmpty;
}
