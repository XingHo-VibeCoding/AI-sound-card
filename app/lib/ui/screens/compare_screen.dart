import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../engine/follow_read/follow_read_session.dart';
import '../../models/recording.dart';
import '../../models/self_evaluation.dart';
import '../../models/sentence.dart';
import '../../models/waveform_data.dart';
import '../../state/follow_read_provider.dart';
import '../../state/providers.dart';
import '../widgets/hold_to_talk_button.dart';
import '../widgets/self_evaluation_sheet.dart';
import '../widgets/waveform_comparison_view.dart';

/// 跟读对比页：原声 → 跟读录音 → 波形重叠 → 三维自评 → 复习池。
class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key, this.sentenceId});

  final int? sentenceId;

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  int? _startedId;

  @override
  Widget build(BuildContext context) {
    final int? sentenceId = widget.sentenceId;
    if (sentenceId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('跟读对比')),
        body: const Center(child: Text('缺少句子参数')),
      );
    }

    final FollowReadState fr = ref.watch(followReadProvider);

    ref.listen(
      sentenceByIdProvider(sentenceId),
      (AsyncValue<Sentence?>? prev, AsyncValue<Sentence?> next) {
        final Sentence? s = next.value;
        if (s != null && s.id != _startedId) {
          _startedId = s.id;
          ref.read(followReadProvider.notifier).start(s);
        }
      },
    );

    return Scaffold(
      appBar: AppBar(title: Text(fr.sentence?.text ?? '跟读对比')),
      body: _buildBody(context, fr),
    );
  }

  Widget _buildBody(BuildContext context, FollowReadState fr) {
    switch (fr.phase) {
      case FollowReadPhase.idle:
        return const Center(child: CircularProgressIndicator());
      case FollowReadPhase.playingOriginal:
        return _CenteredHint(
          icon: Icons.volume_up,
          title: '正在播放原声…',
          subtitle: fr.sentence?.text ?? '',
        );
      case FollowReadPhase.recording:
        return Column(
          children: <Widget>[
            Expanded(
              child: _CenteredHint(
                icon: Icons.mic,
                title: '请跟读',
                subtitle: fr.sentence?.text ?? '',
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: HoldToTalkButton(
                source: RecordingSource.follow,
                sentenceId: widget.sentenceId,
                label: '按住跟读',
                onRecorded: (Recording rec) {
                  ref.read(followReadProvider.notifier).attachRecording(rec);
                },
              ),
            ),
          ],
        );
      case FollowReadPhase.comparing:
        return _ComparingView(fr: fr);
      case FollowReadPhase.done:
        return _DoneView(
          onRetry: () {
            final Sentence? s = fr.sentence;
            if (s != null) {
              ref.read(followReadProvider.notifier).start(s);
            }
          },
        );
    }
  }
}

class _ComparingView extends ConsumerWidget {
  const _ComparingView({required this.fr});

  final FollowReadState fr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        WaveformComparisonView(
          original: fr.originalWaveform ?? WaveformData.empty,
          mine: fr.mineWaveform ?? WaveformData.empty,
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.volume_up),
                label: const Text('播放原声'),
                onPressed: () =>
                    ref.read(followReadProvider.notifier).playOriginal(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                ),
                icon: const Icon(Icons.record_voice_over),
                label: const Text('播放我的'),
                onPressed: () =>
                    ref.read(followReadProvider.notifier).playMine(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.rate_review),
          label: const Text('三维自评'),
          onPressed: () => _showEvaluation(context, ref),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.flag),
          label: const Text('标错 · 加入复习池'),
          onPressed: () async {
            final int? id = await ref
                .read(followReadProvider.notifier)
                .markReview();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(id != null ? '已加入复习池' : '未找到录音')),
              );
            }
          },
        ),
      ],
    );
  }

  void _showEvaluation(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return SelfEvaluationSheet(
          onSave: (SelfEvaluation evaluation) async {
            final int? id = await ref
                .read(followReadProvider.notifier)
                .saveEvaluation(evaluation);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(id != null ? '评估已保存' : '保存失败')),
              );
            }
          },
        );
      },
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.check_circle, size: 64, color: AppColors.primary),
          const SizedBox(height: 12),
          const Text('本次跟读已完成'),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('再来一次')),
        ],
      ),
    );
  }
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 56, color: AppColors.accent),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
