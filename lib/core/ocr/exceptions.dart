class OcrUnsupportedDeviceException implements Exception {
  final String message;

  const OcrUnsupportedDeviceException([
    this.message = 'This device does not meet the minimum requirements for OCR.',
  ]);

  @override
  String toString() => 'OcrUnsupportedDeviceException: $message';
}
