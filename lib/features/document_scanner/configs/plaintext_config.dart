import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'document_parser_config.dart';
import 'document_type.dart';

const plainTextConfig = DocumentParserConfig(
  documentType: DocumentType.plainText,
  fields: [],
  scripts: [
    TextRecognitionScript.latin,
    TextRecognitionScript.devanagiri,
  ],
);
