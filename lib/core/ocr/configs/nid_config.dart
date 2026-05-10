import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'document_parser_config.dart';
import 'document_type.dart';
import 'field_char_sets.dart';

/// Bangladesh National ID Card parser configuration.
/// Handles both Smart NID (chip card) and Laminated NID (older format).
///
/// Critical label behaviour difference:
///   Smart NID:  labels WITHOUT colon, value on the NEXT line
///   Laminated:  labels WITH colon, value on the SAME line
final nidConfig = DocumentParserConfig(
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
        'নাম',
      ],
      yZone: (0.32, 0.44),
      type: FieldType.string,
      allowedCharsRegex: bengaliChars,
    ),
    FieldConfig(
      fieldKey: 'name_en',
      displayLabel: 'Name (English)',
      labelAnchors: [
        'Name:', 'NAME:', 'Name :', 'Nane:',
        'Name',
      ],
      yZone: (0.45, 0.55),
      type: FieldType.string,
      allowedCharsRegex: latinNameChars,
    ),
    FieldConfig(
      fieldKey: 'fathers_name',
      displayLabel: 'পিতা',
      labelAnchors: [
        'পিতা:', 'পিতাঃ', 'পিতা :',
        'পিতা',
      ],
      yZone: (0.55, 0.66),
      type: FieldType.string,
      allowedCharsRegex: bengaliChars,
    ),
    FieldConfig(
      fieldKey: 'mothers_name',
      displayLabel: 'মাতা',
      labelAnchors: [
        'মাতা:', 'মাতাঃ', 'মাতা :',
        'মাতা',
      ],
      yZone: (0.67, 0.80),
      type: FieldType.string,
      allowedCharsRegex: bengaliChars,
    ),
    FieldConfig(
      fieldKey: 'dob',
      displayLabel: 'Date of Birth',
      labelAnchors: [
        'Date of Birth:', 'Date of Birth',
        'DOB:', 'D.O.B:', 'Birth Date:',
      ],
      yZone: (0.80, 0.90),
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
      yZone: (0.88, 0.97),
      type: FieldType.digits,
      validDigitLengths: [10, 13, 17],
    ),
  ],
);
