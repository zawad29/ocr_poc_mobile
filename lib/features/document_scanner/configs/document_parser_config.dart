import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'document_type.dart';

enum FieldType {
  string,
  date,
  digits,
}

class FieldConfig {
  final String fieldKey;
  final String displayLabel;
  final List<String> labelAnchors;
  final (double yMin, double yMax)? yZone;
  final (double xMin, double xMax)? xZone;
  final FieldType type;
  final bool useEntityExtraction;
  final RegExp? valueRegex;

  /// Whitelist of characters allowed in the final value. Anything not matching
  /// is stripped during post-extraction. Null = no character filtering.
  final RegExp? allowedCharsRegex;

  /// For [FieldType.digits]: acceptable digit-string lengths. If the digits
  /// stripped from the OCR don't match one of these, the field is nulled out
  /// rather than handing back a wrong-length number.
  final List<int>? validDigitLengths;

  const FieldConfig({
    required this.fieldKey,
    required this.displayLabel,
    required this.labelAnchors,
    this.yZone,
    this.xZone,
    this.type = FieldType.string,
    this.useEntityExtraction = false,
    this.valueRegex,
    this.allowedCharsRegex,
    this.validDigitLengths,
  });
}

class DocumentParserConfig {
  final DocumentType documentType;
  final List<FieldConfig> fields;
  final double photoXBoundary;
  final List<TextRecognitionScript> scripts;

  /// Optional landmark text used to vertically align field zones against
  /// varying scan crops. With only the top anchor set, the parser applies a
  /// uniform offset; with both top + bottom anchors, it linearly remaps
  /// every field's yZone (handles translation *and* vertical scaling).
  final String? yAnchor;
  final double? yAnchorExpected;
  final String? yAnchorBottom;
  final double? yAnchorBottomExpected;

  const DocumentParserConfig({
    required this.documentType,
    required this.fields,
    required this.scripts,
    this.photoXBoundary = 0.30,
    this.yAnchor,
    this.yAnchorExpected,
    this.yAnchorBottom,
    this.yAnchorBottomExpected,
  });
}
