import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../configs/document_parser_config.dart';
import '../models/document_scan_result.dart';

class ScanResultCard extends StatefulWidget {
  final DocumentScanResult result;
  final DocumentParserConfig config;
  final VoidCallback onRescan;
  final ValueChanged<Map<String, String?>> onConfirm;

  const ScanResultCard({
    required this.result,
    required this.config,
    required this.onRescan,
    required this.onConfirm,
    super.key,
  });

  @override
  State<ScanResultCard> createState() => _ScanResultCardState();
}

class _ScanResultCardState extends State<ScanResultCard> {
  late Map<String, String?> _fields;

  @override
  void initState() {
    super.initState();
    _fields = Map.of(widget.result.fields);
  }

  int get _score =>
      _fields.values.where((v) => v != null && v.isNotEmpty).length;

  double get _rate =>
      widget.config.fields.isEmpty ? 0 : _score / widget.config.fields.length;

  void _showRawOcr() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RawOcrSheet(rawOcrTexts: widget.result.rawOcrTexts),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFields = widget.config.fields.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (File(widget.result.imagePath).existsSync())
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(widget.result.imagePath),
              height: 140,
              fit: BoxFit.cover,
            ),
          ),
        const SizedBox(height: 12),
        if (hasFields)
          _ScoreBar(
            score: _score,
            total: widget.config.fields.length,
            rate: _rate,
          ),
        if (hasFields)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _showRawOcr,
              icon: const Icon(Icons.code, size: 18),
              label: const Text('View raw OCR'),
            ),
          ),
        Expanded(
          child: hasFields
              ? ListView.separated(
                  itemCount: widget.config.fields.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final field = widget.config.fields[i];
                    return _FieldRow(
                      label: field.displayLabel,
                      value: _fields[field.fieldKey],
                      onChanged: (v) => setState(() {
                        _fields[field.fieldKey] = v.isEmpty ? null : v;
                      }),
                    );
                  },
                )
              : ListView.builder(
                  itemCount: widget.result.rawOcrTexts.length,
                  itemBuilder: (_, i) => _RawOcrSection(
                    index: i + 1,
                    recognized: widget.result.rawOcrTexts[i],
                  ),
                ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAEEDA),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            hasFields
                ? 'Review fields before confirming'
                : 'Raw OCR captured — review above',
            style: const TextStyle(color: Color(0xFF8A5A00)),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onRescan,
                child: const Text('Rescan'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF185FA5),
                ),
                onPressed: () => widget.onConfirm(_fields),
                child: const Text('Confirm'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final int score;
  final int total;
  final double rate;
  const _ScoreBar({required this.score, required this.total, required this.rate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F2FB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text('$score / $total fields'),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: rate,
                minHeight: 8,
                backgroundColor: Colors.white,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF185FA5)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('${(rate * 100).round()}%'),
        ],
      ),
    );
  }
}

class _FieldRow extends StatefulWidget {
  final String label;
  final String? value;
  final ValueChanged<String> onChanged;
  const _FieldRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_FieldRow> createState() => _FieldRowState();
}

class _FieldRowState extends State<_FieldRow> {
  bool _editing = false;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(covariant _FieldRow old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_editing) {
      _ctrl.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    if (_editing) {
      widget.onChanged(_ctrl.text.trim());
    }
    setState(() => _editing = !_editing);
  }

  @override
  Widget build(BuildContext context) {
    final empty = widget.value == null || widget.value!.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 4),
                if (_editing)
                  TextField(
                    controller: _ctrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  )
                else
                  Text(
                    empty ? 'Not detected — tap to enter' : widget.value!,
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: empty ? FontStyle.italic : FontStyle.normal,
                      color: empty ? Colors.black45 : Colors.black87,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: _toggleEdit,
            child: Text(_editing ? 'Save' : 'Edit'),
          ),
        ],
      ),
    );
  }
}

class _RawOcrSheet extends StatelessWidget {
  final List<RecognizedText> rawOcrTexts;
  const _RawOcrSheet({required this.rawOcrTexts});

  void _copyAll(BuildContext context) {
    final combined = rawOcrTexts.map((r) => r.text).join('\n---\n');
    Clipboard.setData(ClipboardData(text: combined));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Raw OCR copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Raw OCR',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy all',
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyAll(context),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: rawOcrTexts.length,
                itemBuilder: (_, i) => _RawOcrSection(
                  index: i + 1,
                  recognized: rawOcrTexts[i],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RawOcrSection extends StatelessWidget {
  final int index;
  final RecognizedText recognized;
  const _RawOcrSection({required this.index, required this.recognized});

  @override
  Widget build(BuildContext context) {
    final lines = [
      for (final block in recognized.blocks) ...block.lines,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Script #$index  (${lines.length} lines)',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF185FA5),
              ),
            ),
          ),
          if (lines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '(no text detected)',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.black45,
                ),
              ),
            )
          else
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      line.text,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'bbox: '
                      'L${line.boundingBox.left.round()} '
                      'T${line.boundingBox.top.round()} '
                      'W${line.boundingBox.width.round()} '
                      'H${line.boundingBox.height.round()}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
          const Divider(height: 16),
        ],
      ),
    );
  }
}
