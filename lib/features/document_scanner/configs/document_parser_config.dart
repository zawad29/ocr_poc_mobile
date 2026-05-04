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
  final FieldType type;
  final bool useEntityExtraction;
  final RegExp? valueRegex;

  const FieldConfig({
    required this.fieldKey,
    required this.displayLabel,
    required this.labelAnchors,
    this.yZone,
    this.type = FieldType.string,
    this.useEntityExtraction = false,
    this.valueRegex,
  });
}

class DocumentParserConfig {
  final DocumentType documentType;
  final List<FieldConfig> fields;
  final double photoXBoundary;
  final List<TextRecognitionScript> scripts;

  const DocumentParserConfig({
    required this.documentType,
    required this.fields,
    required this.scripts,
    this.photoXBoundary = 0.30,
  });
}
