import 'package:flutter/material.dart';
import '../configs/document_type.dart';
import 'document_scanner_screen.dart';

const _primary = Color(0xFF185FA5);

class DocumentTypeSelectionScreen extends StatefulWidget {
  const DocumentTypeSelectionScreen({super.key});

  @override
  State<DocumentTypeSelectionScreen> createState() =>
      _DocumentTypeSelectionScreenState();
}

class _DocumentTypeSelectionScreenState
    extends State<DocumentTypeSelectionScreen> {
  DocumentType? _selected;

  void _onContinue() {
    if (_selected == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentScannerScreen(documentType: _selected!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final types = DocumentType.values;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan document'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Select a document type',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: types.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final type = types[i];
                    final available = configRegistry.containsKey(type);
                    return _TypeCard(
                      type: type,
                      available: available,
                      selected: _selected == type,
                      onTap: available
                          ? () => setState(() => _selected = type)
                          : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _selected == null ? null : _onContinue,
                child: const Text('Continue →'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final DocumentType type;
  final bool available;
  final bool selected;
  final VoidCallback? onTap;

  const _TypeCard({
    required this.type,
    required this.available,
    required this.selected,
    required this.onTap,
  });

  IconData get _icon {
    switch (type) {
      case DocumentType.bangladeshNid:
        return Icons.badge_outlined;
      case DocumentType.plainText:
        return Icons.text_snippet_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? _primary : Colors.black12;
    final borderWidth = selected ? 2.0 : 0.5;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: borderWidth),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(_icon, size: 32, color: available ? _primary : Colors.black38),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: available ? Colors.black87 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    type.scanInstruction,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!available)
              const _Badge(label: 'Soon', muted: true)
            else if (selected)
              const _Badge(label: 'Selected', muted: false),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final bool muted;
  const _Badge({required this.label, required this.muted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: muted ? Colors.black12 : _primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: muted ? Colors.black54 : Colors.white,
        ),
      ),
    );
  }
}
