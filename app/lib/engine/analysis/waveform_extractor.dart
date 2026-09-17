import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/constants/audio_constants.dart';
import '../../models/waveform_data.dart';

/// 波形抽取器（PCM 分桶峰值压缩，纯 Dart）。
///
/// 将百万级采样点压缩为 [bucketCount]（默认 800）桶，每桶取
/// 绝对峰值（min/max 镜像）与 RMS（可选填充），归一化到 0–1。
/// 同步实现，1 分钟音频（~260 万样本）耗时远低于 1s。
class WaveformExtractor {
  const WaveformExtractor();

  WaveformData extract(
    Float64List samples,
    int sampleRate, {
    int bucketCount = AudioConstants.defaultBucketCount,
  }) {
    final int n = samples.length;
    if (n == 0 || sampleRate <= 0) {
      return const WaveformData(
        peaks: <double>[],
        rms: <double>[],
        sampleRate: 0,
        durationMs: 0,
        bucketCount: 0,
      );
    }

    final int actualBuckets = bucketCount
        .clamp(1, n)
        .toInt();
    final List<double> peaks = List<double>.filled(actualBuckets, 0);
    final List<double> rms = List<double>.filled(actualBuckets, 0);
    final double bucketSize = n / actualBuckets;

    for (int b = 0; b < actualBuckets; b++) {
      final int start = (b * bucketSize).floor();
      int end = ((b + 1) * bucketSize).floor();
      if (end <= start) end = start + 1;
      if (end > n) end = n;
      double peak = 0;
      double sumSq = 0;
      for (int i = start; i < end; i++) {
        final double v = samples[i];
        final double abs = v.abs();
        if (abs > peak) peak = abs;
        sumSq += v * v;
      }
      final int count = end - start;
      peaks[b] = peak;
      rms[b] = count == 0 ? 0 : math.sqrt(sumSq / count);
    }

    final int durationMs = (n * 1000 / sampleRate).round();
    return WaveformData(
      peaks: peaks,
      rms: rms,
      sampleRate: sampleRate,
      durationMs: durationMs,
      bucketCount: actualBuckets,
    );
  }
}
