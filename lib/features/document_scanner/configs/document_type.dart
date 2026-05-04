import 'document_parser_config.dart';
import 'educational_certificate_config.dart';
import 'nid_config.dart';
import 'plaintext_config.dart';

enum DocumentType {
  bangladeshNid,
  plainText,
  educationalCertificate,
}

extension DocumentTypeExtension on DocumentType {
  String get displayName {
    switch (this) {
      case DocumentType.bangladeshNid:
        return 'Bangladesh NID';
      case DocumentType.plainText:
        return 'Plain Text OCR';
      case DocumentType.educationalCertificate:
        return 'Educational Certificate';
    }
  }

  String get scanInstruction {
    switch (this) {
      case DocumentType.bangladeshNid:
        return 'Place the NID card flat and ensure all text is visible';
      case DocumentType.plainText:
        return 'Position the document so all text is visible and well-lit';
      case DocumentType.educationalCertificate:
        return 'Place the certificate flat with all printed text visible';
    }
  }
}

final Map<DocumentType, DocumentParserConfig> configRegistry = {
  DocumentType.bangladeshNid: nidConfig,
  DocumentType.plainText: plainTextConfig,
  DocumentType.educationalCertificate: educationalCertificateConfig,
};

DocumentParserConfig configFor(DocumentType type) {
  final config = configRegistry[type];
  if (config == null) {
    throw UnimplementedError('No parser config registered for $type');
  }
  return config;
}
