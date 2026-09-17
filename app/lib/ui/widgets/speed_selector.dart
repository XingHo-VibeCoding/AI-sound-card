import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/audio_constants.dart';
import '../../state/player_provider.dart';

/// 语速选择器（变速不变调档位，Android 走 Sonic）。
class SpeedSelector extends ConsumerWidget {
  const SpeedSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayerState state = ref.watch(playerProvider);
    final PlayerNotifier notifier = ref.read(playerProvider.notifier);

    return Wrap(
      spacing: 8,
      children: AudioConstants.speedLevels.map((double speed) {
        final bool selected = (state.speed - speed).abs() < 0.001;
        return ChoiceChip(
          label: Text('${speed}x'),
          selected: selected,
          onSelected: (_) => notifier.setSpeed(speed),
        );
      }).toList(),
    );
  }
}
