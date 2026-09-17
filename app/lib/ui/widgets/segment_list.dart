import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/time_formatter.dart';
import '../../models/segment.dart';
import '../../state/player_provider.dart';
import '../../state/segment_provider.dart';

/// 断句列表：展示句段、点击播放、手动微调边界。
class SegmentList extends ConsumerWidget {
  const SegmentList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SegmentState segState = ref.watch(segmentProvider);
    final PlayerState playerState = ref.watch(playerProvider);

    if (segState.loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (segState.segments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('未检测到句段（可尝试降低阈值或调整静音参数）')),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < segState.segments.length; i++)
          _SegmentTile(
            index: i,
            segment: segState.segments[i],
            durationMs: playerState.durationMs,
          ),
      ],
    );
  }
}

class _SegmentTile extends ConsumerWidget {
  const _SegmentTile({
    required this.index,
    required this.segment,
    required this.durationMs,
  });

  final int index;
  final Segment segment;
  final int durationMs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayerNotifier player = ref.read(playerProvider.notifier);
    final SegmentNotifier segNotifier = ref.read(segmentProvider.notifier);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(radius: 14, child: Text('${index + 1}')),
        title: Text(
          '${TimeFormatter.msToClockWithTenths(segment.startMs)} - '
          '${TimeFormatter.msToClockWithTenths(segment.endMs)}',
        ),
        subtitle: Text(
          segment.text ?? '时长 ${TimeFormatter.msToHuman(segment.durationMs)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              tooltip: '播放此句',
              icon: const Icon(Icons.play_arrow),
              onPressed: () async {
                await player.seek(segment.startMs);
                await player.play();
              },
            ),
            IconButton(
              tooltip: '微调边界',
              icon: const Icon(Icons.tune),
              onPressed: () => _showEditSheet(context, ref, segNotifier),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(
    BuildContext context,
    WidgetRef ref,
    SegmentNotifier segNotifier,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        return _SegmentEditSheet(
          segment: segment,
          durationMs: durationMs,
          onSave: (Segment updated) => segNotifier.updateSegment(index, updated),
        );
      },
    );
  }
}

class _SegmentEditSheet extends StatefulWidget {
  const _SegmentEditSheet({
    required this.segment,
    required this.durationMs,
    required this.onSave,
  });

  final Segment segment;
  final int durationMs;
  final void Function(Segment) onSave;

  @override
  State<_SegmentEditSheet> createState() => _SegmentEditSheetState();
}

class _SegmentEditSheetState extends State<_SegmentEditSheet> {
  late double _start;
  late double _end;

  @override
  void initState() {
    super.initState();
    _start = widget.segment.startMs.toDouble();
    _end = widget.segment.endMs.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final double max = widget.durationMs > 0 ? widget.durationMs.toDouble() : 1.0;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '微调句段边界',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Text('起点 ${TimeFormatter.msToClockWithTenths(_start.round())}'),
              Expanded(
                child: Slider(
                  value: _start.clamp(0.0, max),
                  max: max,
                  onChanged: (double v) {
                    setState(() => _start = v.clamp(0, _end - 100).toDouble());
                  },
                ),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              Text('终点 ${TimeFormatter.msToClockWithTenths(_end.round())}'),
              Expanded(
                child: Slider(
                  value: _end.clamp(0.0, max),
                  max: max,
                  onChanged: (double v) {
                    setState(() => _end = v.clamp(_start + 100, max).toDouble());
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  widget.onSave(
                    Segment(
                      startMs: _start.round(),
                      endMs: _end.round(),
                      text: widget.segment.text,
                    ),
                  );
                  Navigator.pop(context);
                },
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
