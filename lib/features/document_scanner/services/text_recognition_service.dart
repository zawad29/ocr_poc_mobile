import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class TextRecognitionService {
  final Map<TextRecognitionScript, TextRecognizer> _recognizers = {};

  void initForScripts(List<TextRecognitionScript> scripts) {
    close();
    for (final script in scripts) {
      _recognizers[script] = TextRecognizer(script: script);
    }
  }

  Future<List<RecognizedText>> recognize(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final results = <RecognizedText>[];
    for (final entry in _recognizers.entries) {
      final recognized = await entry.value.processImage(input);
      results.add(recognized);
      debugPrint('========== RAW OCR [${entry.key.name}] ==========');
      debugPrint(recognized.text);
      debugPrint('---- blocks=${recognized.blocks.length} ----');
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          debugPrint(
              '  line "${line.text}" rect=${line.boundingBox.left.toStringAsFixed(0)},${line.boundingBox.top.toStringAsFixed(0)} ${line.boundingBox.width.toStringAsFixed(0)}x${line.boundingBox.height.toStringAsFixed(0)}');
        }
      }
      debugPrint('=====================================');
    }
    return results;
  }

  void close() {
    for (final r in _recognizers.values) {
      r.close();
    }
    _recognizers.clear();
  }
}
