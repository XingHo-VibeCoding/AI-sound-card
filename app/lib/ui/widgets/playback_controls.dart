import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/time_formatter.dart';
import '../../state/player_provider.dart';

/// 播放控制条：播放/暂停 + 进度滑块 + 时间显示。
class PlaybackControls extends ConsumerWidget {
  const PlaybackControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayerState state = ref.watch(playerProvider);
    final PlayerNotifier notifier = ref.read(playerProvider.notifier);

    final double maxMs = state.durationMs > 0
        ? state.durationMs.toDouble()
        : 1.0;
    final double value = state.positionMs.clamp(0, state.durationMs).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Slider(
          value: value.clamp(0.0, maxMs),
          max: maxMs,
          onChanged: state.durationMs <= 0
              ? null
              : (double v) => notifier.seek(v.round()),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              Text(
                TimeFormatter.msToClockWithTenths(state.positionMs),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              IconButton(
                iconSize: 40,
                onPressed: state.isLoaded ? notifier.togglePlay : null,
                icon: Icon(
                  state.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                ),
              ),
              const Spacer(),
              Text(
                TimeFormatter.msToClockWithTenths(state.durationMs),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
