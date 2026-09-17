import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/time_formatter.dart';
import '../../models/recording.dart';
import '../../models/self_evaluation.dart';
import '../../state/evaluation_provider.dart';
import '../../state/player_provider.dart';
import '../../state/providers.dart';

/// 录音列表页：展示历史录音、来源、时长与最新自评分数，点击播放。
class RecordingListScreen extends ConsumerStatefulWidget {
  const RecordingListScreen({super.key});

  @override
  ConsumerState<RecordingListScreen> createState() => _RecordingListScreenState();
}

class _RecordingListScreenState extends ConsumerState<RecordingListScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      ref.read(evaluationProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Recording>> recordings = ref.watch(recordingsProvider);
    final List<SelfEvaluation> evaluations = ref
        .watch(evaluationProvider)
        .evaluations;

    return Scaffold(
      appBar: AppBar(title: const Text('录音列表')),
      body: recordings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(child: Text('加载失败: $e')),
        data: (List<Recording> list) {
          if (list.isEmpty) {
            return const Center(child: Text('暂无录音，去练习页录一段吧'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: list.length,
            itemBuilder: (BuildContext context, int index) {
              final Recording r = list[index];
              final SelfEvaluation? eval = _latestEval(evaluations, r.id);
              return _RecordingTile(recording: r, evaluation: eval);
            },
          );
        },
      ),
    );
  }

  SelfEvaluation? _latestEval(List<SelfEvaluation> evals, int? recordingId) {
    if (recordingId == null) return null;
    for (final SelfEvaluation e in evals) {
      if (e.recordingId == recordingId) return e;
    }
    return null;
  }
}

class _RecordingTile extends ConsumerWidget {
  const _RecordingTile({required this.recording, this.evaluation});

  final Recording recording;
  final SelfEvaluation? evaluation;

  static const Map<String, String> _sourceLabels = <String, String>{
    'seed': '示例',
    'practice': '练习',
    'follow': '跟读',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayerState player = ref.watch(playerProvider);
    final bool isThisPlaying =
        player.isPlaying && player.currentPath?.contains(recording.filePath) == true;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(_sourceLabels[recording.source] ?? '录'),
        ),
        title: Text(TimeFormatter.msToClockWithTenths(recording.durationMs)),
        subtitle: Text(
          [
            DateFormat('MM-dd HH:mm').format(recording.createdAt),
            if (evaluation != null)
              '自评 流${evaluation!.fluency}/准${evaluation!.accuracy}/完${evaluation!.completeness}',
          ].join(' · '),
        ),
        trailing: IconButton(
          icon: Icon(isThisPlaying ? Icons.stop : Icons.play_arrow),
          onPressed: () => _togglePlay(context, ref),
        ),
      ),
    );
  }

  Future<void> _togglePlay(BuildContext context, WidgetRef ref) async {
    final PlayerNotifier notifier = ref.read(playerProvider.notifier);
    final PlayerState player = ref.read(playerProvider);
    final bool isThisPlaying =
        player.isPlaying && player.currentPath?.contains(recording.filePath) == true;

    if (isThisPlaying) {
      await notifier.pause();
      return;
    }
    final String docs = await ref.read(documentsDirPathProvider.future);
    final String abs = resolveRecordingAbsolutePath(docs, recording.filePath);
    await notifier.load(abs);
    await notifier.play();
  }
}
