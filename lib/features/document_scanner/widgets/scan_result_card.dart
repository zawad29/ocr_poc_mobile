import 'dart:io';
import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
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
        _ScoreBar(
          score: _score,
          total: widget.config.fields.length,
          rate: _rate,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
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
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAEEDA),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Review fields before confirming',
            style: TextStyle(color: Color(0xFF8A5A00)),
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
