import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recording_card_app/engine/analysis/waveform_extractor.dart';
import 'package:recording_card_app/models/waveform_data.dart';

void main() {
  const WaveformExtractor extractor = WaveformExtractor();

  group('WaveformExtractor 边界', () {
    test('空输入返回 empty', () {
      final WaveformData wf = extractor.extract(Float64List(0), 44100);
      expect(wf.isEmpty, isTrue);
      expect(wf.bucketCount, 0);
      expect(wf.durationMs, 0);
    });

    test('sampleRate <= 0 返回 empty', () {
      final WaveformData wf =
          extractor.extract(Float64List.fromList(<double>[0.5]), 0);
      expect(wf.isEmpty, isTrue);
    });

    test('bucketCount 大于样本数时收敛到样本数', () {
      final Float64List s = Float64List.fromList(<double>[0.1, 0.2, 0.3]);
      final WaveformData wf = extractor.extract(s, 44100, bucketCount: 1000);
      expect(wf.bucketCount, 3);
      expect(wf.peaks, hasLength(3));
    });

    test('bucketCount <= 0 收敛到 1', () {
      final Float64List s = Float64List.fromList(<double>[0.1, 0.2, 0.3]);
      final WaveformData wf = extractor.extract(s, 44100, bucketCount: 0);
      expect(wf.bucketCount, 1);
      expect(wf.peaks, hasLength(1));
      expect(wf.peaks[0], closeTo(0.3, 1e-9)); // 最大绝对值
    });
  });

  group('WaveformExtractor 计算正确性', () {
    test('分桶峰值与 RMS 计算正确', () {
      final Float64List s =
          Float64List.fromList(<double>[0.0, 0.5, -1.0, 0.25]);
      final WaveformData wf = extractor.extract(s, 1000, bucketCount: 2);
      expect(wf.peaks, hasLength(2));
      expect(wf.rms, hasLength(2));
      expect(wf.peaks[0], closeTo(0.5, 1e-9));
      expect(wf.peaks[1], closeTo(1.0, 1e-9));
      expect(wf.rms[0], closeTo(math.sqrt(0.25 / 2), 1e-9)); // sqrt(0.125)
      expect(wf.rms[1], closeTo(math.sqrt(1.0625 / 2), 1e-9));
      expect(wf.durationMs, 4); // 4 样本 @1000Hz = 4ms
    });

    test('全零样本 peaks 与 rms 均为 0', () {
      final Float64List s = Float64List(100);
      final WaveformData wf = extractor.extract(s, 44100, bucketCount: 10);
      for (final double v in wf.peaks) {
        expect(v, 0);
      }
      for (final double v in wf.rms) {
        expect(v, 0);
      }
    });

    test('durationMs 按样本数/采样率取整', () {
      final Float64List s = Float64List(44100);
      final WaveformData wf = extractor.extract(s, 44100, bucketCount: 10);
      expect(wf.durationMs, 1000);
    });
  });
}
