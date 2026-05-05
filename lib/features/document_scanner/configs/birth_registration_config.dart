import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'document_parser_config.dart';
import 'document_type.dart';

/// Bangladesh Birth Registration Record Verification parser configuration.
/// Document is strongly columnar (3-col top table, 4-col bottom table) so
/// fields rely on (yZone, xZone) spatial extraction rather than label anchors.
/// Y/X bounds are estimates — calibrate against real scans via debug bbox logs.
const birthRegistrationConfig = DocumentParserConfig(
  documentType: DocumentType.birthRegistrationCertificate,
  photoXBoundary: 0.0,
  yAnchor: 'REGISTERED',
  yAnchorExpected: 0.395,
  yAnchorBottom: "FATHER'S",
  yAnchorBottomExpected: 0.580,
  scripts: [
    TextRecognitionScript.devanagiri,
    TextRecognitionScript.latin,
  ],
  fields: [
    // Top table — row 2 (DATE OF BIRTH | BIRTH REGISTRATION NUMBER | SEX)
    FieldConfig(
      fieldKey: 'dob',
      displayLabel: 'Date of Birth',
      labelAnchors: [],
      yZone: (0.335, 0.365),
      xZone: (0.05, 0.35),
      type: FieldType.date,
      useEntityExtraction: true,
    ),
    FieldConfig(
      fieldKey: 'birth_registration_number',
      displayLabel: 'Birth Registration Number',
      labelAnchors: [],
      yZone: (0.335, 0.365),
      xZone: (0.35, 0.65),
      type: FieldType.digits,
    ),
    FieldConfig(
      fieldKey: 'sex',
      displayLabel: 'Sex',
      labelAnchors: [],
      yZone: (0.335, 0.365),
      xZone: (0.65, 0.95),
      type: FieldType.string,
    ),
    // Bottom table — Bengali value column (best-effort; ML Kit lacks Bengali)
    FieldConfig(
      fieldKey: 'name_bn',
      displayLabel: 'নাম',
      labelAnchors: [],
      yZone: (0.37, 0.42),
      xZone: (0.20, 0.36),
      type: FieldType.string,
    ),
    // Bottom table — English value column
    FieldConfig(
      fieldKey: 'name_en',
      displayLabel: 'Registered Person Name',
      labelAnchors: [],
      yZone: (0.37, 0.42),
      xZone: (0.52, 0.78),
      type: FieldType.string,
    ),
    FieldConfig(
      fieldKey: 'place_of_birth',
      displayLabel: 'Place of Birth',
      labelAnchors: [],
      yZone: (0.42, 0.46),
      xZone: (0.52, 0.78),
      type: FieldType.string,
    ),
    FieldConfig(
      fieldKey: 'mother_name',
      displayLabel: "Mother's Name",
      labelAnchors: [],
      yZone: (0.46, 0.51),
      xZone: (0.52, 0.78),
      type: FieldType.string,
    ),
    FieldConfig(
      fieldKey: 'mother_nationality',
      displayLabel: "Mother's Nationality",
      labelAnchors: [],
      yZone: (0.51, 0.55),
      xZone: (0.52, 0.78),
      type: FieldType.string,
    ),
    FieldConfig(
      fieldKey: 'father_name',
      displayLabel: "Father's Name",
      labelAnchors: [],
      yZone: (0.55, 0.61),
      xZone: (0.52, 0.78),
      type: FieldType.string,
    ),
    FieldConfig(
      fieldKey: 'father_nationality',
      displayLabel: "Father's Nationality",
      labelAnchors: [],
      yZone: (0.61, 0.65),
      xZone: (0.52, 0.78),
      type: FieldType.string,
    ),
  ],
);
