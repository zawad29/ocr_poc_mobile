import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

class DocumentScanService {
  Future<String?> scan() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.filter,
        pageLimit: 1,
        isGalleryImport: true,
      ),
    );
    try {
      final result = await scanner.scanDocument();
      if (result.images.isEmpty) return null;
      return result.images.first;
    } finally {
      scanner.close();
    }
  }
}
