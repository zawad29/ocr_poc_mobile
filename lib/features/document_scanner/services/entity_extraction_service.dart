import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';

class EntityExtractionService {
  final _extractor = EntityExtractor(
    language: EntityExtractorLanguage.english,
  );

  Future<String?> extractDate(String text) async {
    if (text.trim().isEmpty) return null;
    try {
      final annotations = await _extractor.annotateText(text);
      for (final annotation in annotations) {
        for (final entity in annotation.entities) {
          if (entity.type == EntityType.dateTime) {
            return annotation.text;
          }
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> close() => _extractor.close();
}
