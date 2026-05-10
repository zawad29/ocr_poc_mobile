import 'package:flutter/material.dart';
import 'package:ocr_app/core/ocr/ocr.dart';
import '../widgets/scan_result_card.dart';

class DocumentScannerScreen extends StatefulWidget {
  final DocumentType documentType;
  const DocumentScannerScreen({required this.documentType, super.key});

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  final _orchestrator = DocumentScanOrchestrator();
  DocumentScanResult? _result;
  bool _loading = false;
  String? _error;

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _orchestrator.scan(widget.documentType);
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _orchestrator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = configFor(widget.documentType);
    return PopScope(
      canPop: !_loading,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.documentType.displayName)),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Builder(
              builder: (_) {
                if (_loading) return const _LoadingIndicator();
                if (_error != null) {
                  return _ErrorView(error: _error!, onRetry: _scan);
                }
                if (_result != null) {
                  return ScanResultCard(
                    result: _result!,
                    config: config,
                    onRescan: _scan,
                    onConfirm: (fields) => Navigator.of(context).pop(fields),
                  );
                }
                return _ScanPrompt(
                  instruction: widget.documentType.scanInstruction,
                  onScan: _scan,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanPrompt extends StatelessWidget {
  final String instruction;
  final VoidCallback onScan;
  const _ScanPrompt({required this.instruction, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Container(
          height: 220,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF185FA5), width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text('Align card here', style: TextStyle(color: Color(0xFF185FA5))),
          ),
        ),
        const SizedBox(height: 24),
        Text(instruction, textAlign: TextAlign.center),
        const Spacer(),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF185FA5),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: onScan,
          icon: const Icon(Icons.camera_alt),
          label: const Text('Scan'),
        ),
      ],
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF185FA5)),
          SizedBox(height: 16),
          Text('Reading text...'),
          SizedBox(height: 4),
          Text('This may take a few seconds',
              style: TextStyle(color: Colors.black54, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
        const SizedBox(height: 12),
        Text(error, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
