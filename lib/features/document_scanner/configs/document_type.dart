import 'document_parser_config.dart';
import 'nid_config.dart';

enum DocumentType {
  bangladeshNid,
}

extension DocumentTypeExtension on DocumentType {
  String get displayName {
    switch (this) {
      case DocumentType.bangladeshNid:
        return 'Bangladesh NID';
    }
  }

  String get scanInstruction {
    switch (this) {
      case DocumentType.bangladeshNid:
        return 'Place the NID card flat and ensure all text is visible';
    }
  }
}

final Map<DocumentType, DocumentParserConfig> configRegistry = {
  DocumentType.bangladeshNid: nidConfig,
};

DocumentParserConfig configFor(DocumentType type) {
  final config = configRegistry[type];
  if (config == null) {
    throw UnimplementedError('No parser config registered for $type');
  }
  return config;
}
