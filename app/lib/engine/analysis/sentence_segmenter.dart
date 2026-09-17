import 'dart:math' as math;
import 'dart:typed_data';

import '../../models/segment.dart';

/// 断句接口（M4 可无缝替换为 ASR 语义断句实现）。
abstract class Segmenter {
  List<Segment> segment(
    Float64List samples,
    int sampleRate,
    SegmentConfig config,
  );
}

/// 能量阈值静音检测断句（Dart 纯算法）。
///
/// 分帧（默认 20ms）计算 RMS，低于 [SegmentConfig.silenceDb] 判静音，
/// 连续静音超过 [SegmentConfig.minSilenceMs] 作为切点，
/// 句段时长短于 [SegmentConfig.minSegmentMs] 丢弃。
class SentenceSegmenter implements Segmenter {
  const SentenceSegmenter();

  @override
  List<Segment> segment(
    Float64List samples,
    int sampleRate,
    SegmentConfig config,
  ) {
    final int frameSize = ((sampleRate * config.frameMs) / 1000).round();
    if (frameSize <= 0 || samples.length < frameSize) return const <Segment>[];

    final double threshold = math.pow(10, config.silenceDb / 20).toDouble();
    final int frameCount = samples.length ~/ frameSize;

    final List<bool> silent = List<bool>.filled(frameCount, false);
    for (int f = 0; f < frameCount; f++) {
      final int start = f * frameSize;
      double sumSq = 0;
      for (int i = start; i < start + frameSize; i++) {
        final double v = samples[i];
        sumSq += v * v;
      }
      final double rms = math.sqrt(sumSq / frameSize);
      silent[f] = rms < threshold;
    }

    final int minSilenceFrames = (config.minSilenceMs / config.frameMs).ceil();
    final List<Segment> segments = <Segment>[];

    int? segStartFrame;
    int lastActiveFrame = -1;
    int silentRun = 0;

    for (int f = 0; f < frameCount; f++) {
      if (!silent[f]) {
        silentRun = 0;
        segStartFrame ??= f;
        lastActiveFrame = f;
      } else {
        silentRun++;
        if (segStartFrame != null && silentRun >= minSilenceFrames) {
          final int startMs = segStartFrame * config.frameMs;
          final int endMs = (lastActiveFrame + 1) * config.frameMs;
          if (endMs - startMs >= config.minSegmentMs) {
            segments.add(Segment(startMs: startMs, endMs: endMs));
          }
          segStartFrame = null;
          lastActiveFrame = -1;
        }
      }
    }

    // 收尾未闭合句段。
    if (segStartFrame != null) {
      final int startMs = segStartFrame * config.frameMs;
      final int endMs = (lastActiveFrame + 1) * config.frameMs;
      if (endMs - startMs >= config.minSegmentMs) {
        segments.add(Segment(startMs: startMs, endMs: endMs));
      }
    }

    return segments;
  }
}
