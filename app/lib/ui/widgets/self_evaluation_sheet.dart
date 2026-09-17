import 'package:flutter/material.dart';

import '../../models/self_evaluation.dart';

/// 三维自评弹层（流利度 / 准确度 / 完整度，1–5 分 + 备注）。
class SelfEvaluationSheet extends StatefulWidget {
  const SelfEvaluationSheet({super.key, required this.onSave});

  final void Function(SelfEvaluation evaluation) onSave;

  @override
  State<SelfEvaluationSheet> createState() => _SelfEvaluationSheetState();
}

class _SelfEvaluationSheetState extends State<SelfEvaluationSheet> {
  int _fluency = 3;
  int _accuracy = 3;
  int _completeness = 3;
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('自我评估', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          _ScoreSlider(label: '流利度', value: _fluency, onChanged: (v) => setState(() => _fluency = v)),
          _ScoreSlider(label: '准确度', value: _accuracy, onChanged: (v) => setState(() => _accuracy = v)),
          _ScoreSlider(label: '完整度', value: _completeness, onChanged: (v) => setState(() => _completeness = v)),
          TextField(
            controller: _noteController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '备注（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                widget.onSave(
                  SelfEvaluation(
                    recordingId: 0, // 由保存方覆盖为实际录音 id
                    fluency: _fluency,
                    accuracy: _accuracy,
                    completeness: _completeness,
                    note: _noteController.text.trim().isEmpty
                        ? null
                        : _noteController.text.trim(),
                    createdAt: DateTime.now(),
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text('保存评估'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreSlider extends StatelessWidget {
  const _ScoreSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(width: 64, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '$value',
            onChanged: (double v) => onChanged(v.round()),
          ),
        ),
        SizedBox(width: 24, child: Text('$value')),
      ],
    );
  }
}
