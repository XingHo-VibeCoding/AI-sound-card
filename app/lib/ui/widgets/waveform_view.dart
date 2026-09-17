import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/waveform_data.dart';

/// 单段波形视图（PCM 分桶峰值镜像绘制）。
///
/// 用 `CustomPainter` 绘制上下镜像波形，[progress] 0–1 用于高亮已播放部分。
class WaveformView extends StatelessWidget {
  const WaveformView({
    super.key,
    required this.data,
    this.progress = 0,
    this.color = AppColors.originalWave,
    this.playedColor,
    this.height = 120,
  });

  final WaveformData data;
  final double progress;
  final Color color;
  final Color? playedColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: data.isEmpty
          ? const Center(child: Text('暂无波形'))
          : CustomPaint(
              painter: _WaveformPainter(
                data: data,
                progress: progress,
                color: color,
                playedColor: playedColor,
              ),
              size: Size.infinite,
            ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.data,
    required this.progress,
    required this.color,
    this.playedColor,
  });

  final WaveformData data;
  final double progress;
  final Color color;
  final Color? playedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final List<double> peaks = data.peaks;
    if (peaks.isEmpty) return;

    final double midY = size.height / 2;
    final int n = peaks.length;
    final double stepX = size.width / n;
    final double playedX = size.width * progress.clamp(0.0, 1.0);

    final Paint paint = Paint()
      ..strokeWidth = stepX.clamp(1.0, 3.0)
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < n; i++) {
      final double x = i * stepX;
      final double half = peaks[i].clamp(0.0, 1.0) * (midY - 1);
      paint.color = (playedColor != null && x <= playedX)
          ? playedColor!
          : color;
      canvas.drawLine(
        Offset(x, midY - half),
        Offset(x, midY + half),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.playedColor != playedColor;
  }
}
