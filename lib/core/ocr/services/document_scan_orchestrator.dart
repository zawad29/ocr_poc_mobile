import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import '../configs/document_type.dart';
import '../exceptions.dart';
import '../models/document_scan_result.dart';
import 'document_scan_service.dart';
import 'text_recognition_service.dart';
import 'entity_extraction_service.dart';
import 'generic_document_parser.dart';

class DocumentScanOrchestrator {
  final _scanService = DocumentScanService();
  final _textService = TextRecognitionService();
  final _entityService = EntityExtractionService();
  late final _parser = GenericDocumentParser(_entityService);

  /// Scans a document of [documentType] and returns the extracted fields.
  ///
  /// Returns `null` if the user cancelled the scanner UI.
  ///
  /// Throws [OcrUnsupportedDeviceException] if Google Play Services are
  /// missing or incompatible at runtime (e.g. the device API level is below
  /// the ML Kit minimum, or Play Services are disabled).
  ///
  /// All other failures (I/O, unexpected ML Kit errors) are rethrown as-is.
  Future<DocumentScanResult?> scan(DocumentType documentType) async {
    final config = configFor(documentType);
    debugPrint('>>> orchestrator.scan(${documentType.name})');

    final String imagePath;
    try {
      final path = await _scanService.scan();
      if (path == null) {
        debugPrint('>>> scan cancelled');
        return null;
      }
      imagePath = path;
    } on PlatformException catch (e) {
      throw OcrUnsupportedDeviceException(
        e.message ?? 'ML Kit Document Scanner is not available on this device (${e.code}).',
      );
    }

    debugPrint('>>> cropped image: $imagePath');

    _textService.initForScripts(config.scripts);
    final recognizedTexts = await _textService.recognize(imagePath);
    final imageSize = await _getImageSize(imagePath);

    final fields = await _parser.parse(
      recognizedTexts: recognizedTexts,
      config: config,
      imageSize: imageSize,
    );

    final extractionScore =
        fields.values.where((v) => v != null && v.isNotEmpty).length;
    debugPrint('>>> extraction $extractionScore/${config.fields.length}');

    return DocumentScanResult(
      documentType: documentType,
      fields: fields,
      extractionScore: extractionScore,
      totalFields: config.fields.length,
      imagePath: imagePath,
      rawOcrTexts: recognizedTexts,
    );
  }

  Future<Size> _getImageSize(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return Size(frame.image.width.toDouble(), frame.image.height.toDouble());
  }

  void dispose() {
    _textService.close();
    _entityService.close();
  }
}
