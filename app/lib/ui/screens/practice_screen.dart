import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/time_formatter.dart';
import '../../models/sentence.dart';
import '../../models/waveform_data.dart';
import '../../state/player_provider.dart';
import '../../state/providers.dart';
import '../../state/segment_provider.dart';
import '../../state/waveform_provider.dart';
import '../widgets/ab_loop_bar.dart';
import '../widgets/hold_to_talk_button.dart';
import '../widgets/playback_controls.dart';
import '../widgets/record_toggle_button.dart';
import '../widgets/segment_list.dart';
import '../widgets/speed_selector.dart';
import '../widgets/waveform_view.dart';

/// 复读机主页：录音 / 播放 / 断句 / 变速 / AB 复读。
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key, this.sentenceId});

  final int? sentenceId;

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  int? _loadedId;
  WaveformData _waveform = WaveformData.empty;

  Future<void> _load(Sentence sentence) async {
    if (sentence.audioPath == null) return;
    final String docs = await ref.read(documentsDirPathProvider.future);
    final String abs = resolveRecordingAbsolutePath(docs, sentence.audioPath!);
    await ref.read(playerProvider.notifier).load(abs);
    final WaveformData wf = ref
        .read(waveformServiceProvider)
        .extractFromFile(abs);
    if (!mounted) return;
    setState(() => _waveform = wf);
    await ref.read(segmentProvider.notifier).compute(abs);
  }

  @override
  Widget build(BuildContext context) {
    final int? sentenceId = widget.sentenceId;
    if (sentenceId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('复读机练习')),
        body: const Center(child: Text('缺少句子参数')),
      );
    }

    final PlayerState player = ref.watch(playerProvider);

    ref.listen(
      sentenceByIdProvider(sentenceId),
      (AsyncValue<Sentence?>? prev, AsyncValue<Sentence?> next) {
        final Sentence? s = next.value;
        if (s != null && s.id != _loadedId) {
          _loadedId = s.id;
          _load(s);
        }
      },
    );

    final AsyncValue<Sentence?> sentenceAsync =
        ref.watch(sentenceByIdProvider(sentenceId));

    final double progress =
        player.durationMs > 0 ? player.positionMs / player.durationMs : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(sentenceAsync.value?.text ?? '复读机练习'),
        actions: <Widget>[
          IconButton(
            tooltip: '跟读对比',
            icon: const Icon(Icons.compare_arrows),
            onPressed: () => context.push(
              '${AppRoutes.compare}?sentenceId=$sentenceId',
            ),
          ),
        ],
      ),
      body: sentenceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(child: Text('加载失败: $e')),
        data: (Sentence? sentence) =>
            _buildBody(context, sentence, player, progress),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: HoldToTalkButton(
                  sentenceId: sentenceId,
                  onRecorded: (_) => _onRecorded(),
                ),
              ),
              const SizedBox(width: 12),
              RecordToggleButton(
                sentenceId: sentenceId,
                onRecorded: (_) => _onRecorded(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    Sentence? sentence,
    PlayerState player,
    double progress,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (sentence != null) _SentenceHeader(sentence: sentence),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: WaveformView(
              data: _waveform,
              progress: progress,
              playedColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        PlaybackControls(),
        const SizedBox(height: 8),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('语速'),
        ),
        const SpeedSelector(),
        const Divider(height: 24),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('AB 复读'),
        ),
        const AbLoopBar(),
        const Divider(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('断句', style: Theme.of(context).textTheme.titleMedium),
        ),
        const SegmentList(),
      ],
    );
  }

  void _onRecorded() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('录音已保存')));
  }
}

class _SentenceHeader extends StatelessWidget {
  const _SentenceHeader({required this.sentence});

  final Sentence sentence;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              sentence.text,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (sentence.phonetic != null) Text(sentence.phonetic!),
            if (sentence.translation != null) Text(sentence.translation!),
            const SizedBox(height: 4),
            Text(
              '时长 ${TimeFormatter.msToHuman(sentence.durationMs)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
