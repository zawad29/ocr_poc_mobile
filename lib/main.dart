import 'package:flutter/material.dart';
import 'features/document_scanner/screens/document_type_selection_screen.dart';

void main() {
  runApp(const OcrApp());
}

class OcrApp extends StatelessWidget {
  const OcrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Document Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF185FA5)),
        useMaterial3: true,
      ),
      home: const DocumentTypeSelectionScreen(),
    );
  }
}
