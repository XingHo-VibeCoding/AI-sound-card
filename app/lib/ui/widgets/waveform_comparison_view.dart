import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/waveform_data.dart';
import 'waveform_view.dart';

/// 原声 / 录音重叠对比视图。
///
/// 原声为底（蓝），录音为顶（橙，半透明叠加），各自归一化到视口宽度，
/// 用于直观对比跟读与原文的节奏/响度差异。
class WaveformComparisonView extends StatelessWidget {
  const WaveformComparisonView({
    super.key,
    required this.original,
    required this.mine,
    this.height = 160,
  });

  final WaveformData original;
  final WaveformData mine;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: WaveformView(
                  data: original,
                  color: AppColors.originalWave,
                  height: height,
                ),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0.55,
                  child: WaveformView(
                    data: mine,
                    color: AppColors.mineWave,
                    height: height,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const <Widget>[
            _LegendDot(color: AppColors.originalWave, label: '原声'),
            SizedBox(width: 16),
            _LegendDot(color: AppColors.mineWave, label: '我的录音'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
