import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'document_parser_config.dart';
import 'document_type.dart';

/// Bangladesh National ID Card parser configuration.
/// Handles both Smart NID (chip card) and Laminated NID (older format).
///
/// Critical label behaviour difference:
///   Smart NID:  labels WITHOUT colon, value on the NEXT line
///   Laminated:  labels WITH colon, value on the SAME line
const nidConfig = DocumentParserConfig(
  documentType: DocumentType.bangladeshNid,
  photoXBoundary: 0.25,
  scripts: [
    TextRecognitionScript.devanagiri,
    TextRecognitionScript.latin,
  ],
  fields: [
    FieldConfig(
      fieldKey: 'name_bn',
      displayLabel: 'নাম',
      labelAnchors: [
        'নাম:', 'নামঃ', 'নাম :', 'নাম: ',
      ],
      yZone: (0.25, 0.48),
      type: FieldType.string,
    ),
    FieldConfig(
      fieldKey: 'name_en',
      displayLabel: 'Name (English)',
      labelAnchors: [
        'Name:', 'NAME:', 'Name :', 'Nane:',
        'Name',
      ],
      yZone: (0.35, 0.58),
      type: FieldType.string,
    ),
    FieldConfig(
      fieldKey: 'fathers_name',
      displayLabel: 'পিতা',
      labelAnchors: [
        'পিতা:', 'পিতাঃ', 'পিতা :',
        'পিতা',
      ],
      yZone: (0.45, 0.68),
      type: FieldType.string,
    ),
    FieldConfig(
      fieldKey: 'mothers_name',
      displayLabel: 'মাতা',
      labelAnchors: [
        'মাতা:', 'মাতাঃ', 'মাতা :',
        'মাতা',
      ],
      yZone: (0.55, 0.78),
      type: FieldType.string,
    ),
    FieldConfig(
      fieldKey: 'dob',
      displayLabel: 'Date of Birth',
      labelAnchors: [
        'Date of Birth:', 'Date of Birth',
        'DOB:', 'D.O.B:', 'Birth Date:',
      ],
      yZone: (0.65, 0.88),
      type: FieldType.date,
      useEntityExtraction: true,
    ),
    FieldConfig(
      fieldKey: 'nid_no',
      displayLabel: 'NID Number',
      labelAnchors: [
        'NID No.', 'NID No:', 'NID No',
        'ID NO:', 'ID No:',
        '1D NO:', 'NID:',
      ],
      yZone: (0.82, 0.99),
      type: FieldType.digits,
    ),
  ],
);
