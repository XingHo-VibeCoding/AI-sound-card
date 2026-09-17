import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/time_formatter.dart';
import '../../state/player_provider.dart';

/// AB 区间复读条：设置 A/B 点、清除、重复次数与循环间隔。
class AbLoopBar extends ConsumerWidget {
  const AbLoopBar({super.key});

  static const List<int> _repeatOptions = <int>[1, 2, 3, 5, 0]; // 0=无限

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayerState state = ref.watch(playerProvider);
    final PlayerNotifier notifier = ref.read(playerProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            OutlinedButton(
              onPressed: () => notifier.setLoopPointA(state.positionMs),
              child: Text(
                state.loopPointA == null
                    ? '设置 A'
                    : 'A ${TimeFormatter.msToClockWithTenths(state.loopPointA!)}',
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => notifier.setLoopPointB(state.positionMs),
              child: Text(
                state.loopPointB == null
                    ? '设置 B'
                    : 'B ${TimeFormatter.msToClockWithTenths(state.loopPointB!)}',
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: '清除 AB',
              onPressed:
                  state.loopPointA == null && state.loopPointB == null
                      ? null
                      : notifier.clearAbLoop,
              icon: const Icon(Icons.clear),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            const Text('重复次数'),
            const SizedBox(width: 8),
            for (final int option in _repeatOptions)
              ChoiceChip(
                label: Text(option == 0 ? '∞' : '$option'),
                selected: state.repeatCount == option,
                onSelected: (_) => notifier.setRepeatCount(option),
              ),
          ],
        ),
        Row(
          children: <Widget>[
            const Text('循环间隔'),
            IconButton(
              onPressed: state.intervalMs <= 0
                  ? null
                  : () => notifier.setInterval(state.intervalMs - 500),
              icon: const Icon(Icons.remove),
            ),
            Text('${(state.intervalMs / 1000).toStringAsFixed(1)}s'),
            IconButton(
              onPressed: () => notifier.setInterval(state.intervalMs + 500),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}
