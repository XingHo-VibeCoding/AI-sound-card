import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recording_card_app/engine/analysis/sentence_segmenter.dart';
import 'package:recording_card_app/models/segment.dart';

/// 构造由若干「定长片段」拼接的信号。
///
/// [ms] 为每个片段的时长（毫秒），[amps] 为对应片段的恒定幅度。
/// 恒定 DC 信号的 RMS 即其幅度，便于精确控制静音/有声判定。
Float64List _signal(int sampleRate, List<int> ms, List<double> amps) {
  int total = 0;
  for (final int m in ms) {
    total += (sampleRate * m / 1000).round();
  }
  final Float64List out = Float64List(total);
  int idx = 0;
  for (int s = 0; s < ms.length; s++) {
    final int n = (sampleRate * ms[s] / 1000).round();
    for (int i = 0; i < n; i++) {
      out[idx++] = amps[s];
    }
  }
  return out;
}

void main() {
  const int sr = 44100;
  const SentenceSegmenter segmenter = SentenceSegmenter();
  // frameMs=20 / silenceDb=-40 / minSilenceMs=300 / minSegmentMs=500
  const SegmentConfig config = SegmentConfig();

  group('SentenceSegmenter 边界与异常输入', () {
    test('空输入返回空列表', () {
      expect(segmenter.segment(Float64List(0), sr, config), isEmpty);
    });

    test('样本数小于一帧时返回空列表', () {
      expect(segmenter.segment(Float64List(100), sr, config), isEmpty);
    });

    test('全静音返回空列表', () {
      expect(segmenter.segment(Float64List(sr), sr, config), isEmpty);
    });

    test('低于 -40dBFS 阈值的弱信号被判为静音', () {
      // 幅度 0.005 < 阈值 10^(-40/20)=0.01 → 静音
      final Float64List s = Float64List(sr);
      for (int i = 0; i < s.length; i++) {
        s[i] = 0.005;
      }
      expect(segmenter.segment(s, sr, config), isEmpty);
    });
  });

  group('SentenceSegmenter 正常切句', () {
    test('连续语音切出单个句段并去除首尾静音', () {
      final Float64List s =
          _signal(sr, <int>[300, 1000, 300], <double>[0.0, 0.5, 0.0]);
      final List<Segment> segs = segmenter.segment(s, sr, config);
      expect(segs, hasLength(1));
      expect(segs[0].startMs, 300);
      expect(segs[0].endMs, 1300);
    });

    test('超过 300ms 静音处切分成两个句段', () {
      final Float64List s =
          _signal(sr, <int>[600, 400, 600], <double>[0.5, 0.0, 0.5]);
      final List<Segment> segs = segmenter.segment(s, sr, config);
      expect(segs, hasLength(2));
      expect(segs[0].startMs, 0);
      expect(segs[0].endMs, 600);
      expect(segs[1].startMs, 1000);
      expect(segs[1].endMs, 1600);
    });

    test('短于 500ms 的句段被过滤', () {
      final Float64List s =
          _signal(sr, <int>[300, 400, 800], <double>[0.5, 0.0, 0.5]);
      final List<Segment> segs = segmenter.segment(s, sr, config);
      expect(segs, hasLength(1));
      expect(segs[0].startMs, 700);
      expect(segs[0].endMs, 1500);
    });

    test('采样率非 44100 时仍按毫秒正确切分', () {
      const int sr8k = 8000;
      final Float64List s =
          _signal(sr8k, <int>[600, 400, 600], <double>[0.5, 0.0, 0.5]);
      final List<Segment> segs = segmenter.segment(s, sr8k, config);
      expect(segs, hasLength(2));
      expect(segs[0].startMs, 0);
      expect(segs[0].endMs, 600);
      expect(segs[1].startMs, 1000);
      expect(segs[1].endMs, 1600);
    });

    test('帧长除不尽时丢弃尾部不足一帧的样本', () {
      // 30000 样本 @44100 → 34 帧（34*882=29988），余 12 样本被丢弃
      final Float64List s = Float64List(30000);
      for (int i = 0; i < s.length; i++) {
        s[i] = 0.5;
      }
      final List<Segment> segs = segmenter.segment(s, sr, config);
      expect(segs, hasLength(1));
      expect(segs[0].startMs, 0);
      expect(segs[0].endMs, 680); // 34 帧 * 20ms
    });
  });
}
