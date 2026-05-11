/// Public surface of the on-device OCR library.
///
/// Host apps should import only this file:
///
///   import 'package:HOST/PATH/ocr/ocr.dart';
///
/// Everything not exported here (internal services, per-document configs,
/// the raw registry map) is an implementation detail and may change.
library;

export 'exceptions.dart';
export 'configs/document_type.dart' show DocumentType, DocumentTypeExtension, configFor;
export 'configs/document_parser_config.dart' show DocumentParserConfig, FieldConfig, FieldType;
export 'models/document_scan_result.dart';
export 'services/document_scan_orchestrator.dart' show DocumentScanOrchestrator;
