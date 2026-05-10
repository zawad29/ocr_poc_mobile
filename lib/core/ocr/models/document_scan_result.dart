import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../configs/document_type.dart';

class DocumentScanResult {
  final DocumentType documentType;
  final Map<String, String?> fields;
  final int extractionScore;
  final int totalFields;
  final String imagePath;
  final List<RecognizedText> rawOcrTexts;

  const DocumentScanResult({
    required this.documentType,
    required this.fields,
    required this.extractionScore,
    required this.totalFields,
    required this.imagePath,
    required this.rawOcrTexts,
  });

  double get extractionRate => totalFields == 0 ? 0 : extractionScore / totalFields;

  bool get isComplete => extractionScore == totalFields;
}
