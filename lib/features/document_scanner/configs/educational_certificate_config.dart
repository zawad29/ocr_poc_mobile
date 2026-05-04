import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'document_parser_config.dart';
import 'document_type.dart';

final educationalCertificateConfig = DocumentParserConfig(
  documentType: DocumentType.educationalCertificate,
  photoXBoundary: 0.0,
  scripts: const [
    TextRecognitionScript.latin,
  ],
  fields: [
    FieldConfig(
      fieldKey: 'board_name',
      displayLabel: 'Board',
      labelAnchors: const ['BOARD OF'],
      valueRegex: RegExp(r'(BOARD OF[^\n]+)', caseSensitive: false),
      type: FieldType.string,
    ),
    FieldConfig(
      fieldKey: 'certificate_type',
      displayLabel: 'Certificate Type',
      labelAnchors: const ['CERTIFICATE EXAMINATION', 'EXAMINATION'],
      valueRegex: RegExp(
        r'((?:[A-Z][A-Z]+\s+){1,4}(?:CERTIFICATE\s+)?EXAMINATION)\b',
      ),
      type: FieldType.string,
    ),
    FieldConfig(
      fieldKey: 'year',
      displayLabel: 'Year',
      labelAnchors: const ['Examination of', 'EXAMINATION,', 'EXAMINATION -'],
      valueRegex: RegExp(
        r'EXAMINATION[,\s\-]+(?:of\s+)?(\d{4})',
        caseSensitive: false,
      ),
      type: FieldType.string,
    ),
    FieldConfig(
      fieldKey: 'registration_no',
      displayLabel: 'Registration No.',
      labelAnchors: const ['Registration No.', 'Registration No'],
      valueRegex: RegExp(
        r'Registration\s*No\.?\s*:?\s*([^\n]+)',
        caseSensitive: false,
      ),
      type: FieldType.string,
    ),
    FieldConfig(
      fieldKey: 'candidate_name',
      displayLabel: 'Candidate Name',
      labelAnchors: const ['certify that', 'Certify that'],
      valueRegex: RegExp(
        r'[Cc]ertify\s+that\s+([^\n]+)',
      ),
      type: FieldType.string,
    ),
    FieldConfig(
      fieldKey: 'fathers_name',
      displayLabel: "Father's Name",
      labelAnchors: const [
        'Son /Daughter of',
        'son/daughter of',
        'Son of',
        'Daughter of',
      ],
      valueRegex: RegExp(
        r'(?:Son\s*/?\s*Daughter|Son|Daughter)\s+of\s+([^\n]+)',
        caseSensitive: false,
      ),
      type: FieldType.string,
    ),
    FieldConfig(
      fieldKey: 'mothers_name',
      displayLabel: "Mother's Name",
      labelAnchors: const ['and '],
      valueRegex: RegExp(
        r'(?:^|\n)and\s+([^\n]+)',
        caseSensitive: false,
        multiLine: true,
      ),
      type: FieldType.string,
    ),
    FieldConfig(
      fieldKey: 'institution',
      displayLabel: 'Institution',
      labelAnchors: const [],
      valueRegex: RegExp(
        r'(?:^|\n)of\s+([^\n]*(?:School|College|Madrasah|Madrasa|University|Academy|Institute)[^\n]*)',
        caseSensitive: false,
        multiLine: true,
      ),
      type: FieldType.string,
    ),
    FieldConfig(
      fieldKey: 'roll_no',
      displayLabel: 'Roll No.',
      labelAnchors: const [],
      // "bearing Roll <place>" and "No. <digits>" sit on the same visual row
      // but OCR usually emits them as separate lines. Anchor on "bearing Roll",
      // then jump to the next line that *starts* with "No." (avoids
      // "Registration No." and "Serial No" which never start a line here).
      valueRegex: RegExp(
        r'bearing\s+Roll[\s\S]*?(?:^|\n)No\.\s+([\d ]+)',
        caseSensitive: false,
        multiLine: true,
      ),
      type: FieldType.digits,
    ),
    FieldConfig(
      fieldKey: 'group',
      displayLabel: 'Group',
      labelAnchors: const [],
      valueRegex: RegExp(
        r'\bin\s+([A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+)*)\s+group\b',
      ),
      type: FieldType.string,
    ),
    FieldConfig(
      fieldKey: 'gpa',
      displayLabel: 'G.P.A.',
      labelAnchors: const ['GPA', 'G.P.A.', 'G.P.A'],
      valueRegex: RegExp(
        r'G\.?\s*P\.?\s*A\.?\s*[:.]?\s*(\d+\.\s*\d{1,2})',
        caseSensitive: false,
      ),
      type: FieldType.string,
    ),
    FieldConfig(
      fieldKey: 'gpa_scale',
      displayLabel: 'GPA Scale',
      labelAnchors: const ['scale of', 'in the scale of'],
      valueRegex: RegExp(
        r'scale\s+of\s+(\d+\.\s*\d{1,2})',
        caseSensitive: false,
      ),
      type: FieldType.string,
    ),
  ],
);
