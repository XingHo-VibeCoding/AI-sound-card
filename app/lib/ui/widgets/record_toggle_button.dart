import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/recording.dart';
import '../../state/recorder_provider.dart';

/// 普通录音按钮（tap 开始 / tap 停止），与"按住说话"共用同一 RecorderProvider。
class RecordToggleButton extends ConsumerWidget {
  const RecordToggleButton({
    super.key,
    this.source = RecordingSource.practice,
    this.sentenceId,
    this.onRecorded,
  });

  final String source;
  final int? sentenceId;
  final void Function(Recording recording)? onRecorded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RecorderState state = ref.watch(recorderProvider);
    final RecorderNotifier notifier = ref.read(recorderProvider.notifier);
    final bool recording = state.phase == RecorderPhase.recording;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: recording ? AppColors.danger : AppColors.primary,
          ),
          onPressed: state.isBusy
              ? null
              : () async {
                  if (recording) {
                    final Recording? rec = await notifier.stopToggle();
                    if (rec != null) onRecorded?.call(rec);
                  } else {
                    try {
                      await notifier.startToggle(
                        source: source,
                        sentenceId: sentenceId,
                      );
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('无法开始录音，请检查麦克风权限')),
                        );
                      }
                    }
                  }
                },
          icon: Icon(recording ? Icons.stop : Icons.mic),
          label: Text(recording ? '停止' : '录音'),
        ),
      ],
    );
  }
}
