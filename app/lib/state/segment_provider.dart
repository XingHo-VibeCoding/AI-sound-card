import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/analysis/sentence_segmenter.dart';
import '../engine/audio/pcm_reader.dart';
import '../models/recording.dart';
import '../models/segment.dart';
import 'providers.dart';

/// 断句状态。
class SegmentState {
  const SegmentState({this.segments = const <Segment>[], this.loading = false});

  final List<Segment> segments;
  final bool loading;

  SegmentState copyWith({List<Segment>? segments, bool? loading}) {
    return SegmentState(
      segments: segments ?? this.segments,
      loading: loading ?? this.loading,
    );
  }
}

/// 断句 Provider：计算断句、加载缓存、手动微调并回写 `Recording.segmentJson`。
class SegmentNotifier extends Notifier<SegmentState> {
  Recording? _current;

  PcmReader get _pcmReader => ref.read(pcmReaderProvider);
  SentenceSegmenter get _segmenter => ref.read(sentenceSegmenterProvider);

  @override
  SegmentState build() {
    return const SegmentState();
  }

  /// 为某录音加载断句：优先读缓存 segmentJson，否则重新计算。
  Future<void> loadForRecording(Recording rec, String absolutePath) async {
    _current = rec;
    final String? cached = rec.segmentJson;
    if (cached != null && cached.isNotEmpty) {
      final List<Segment> segs = Segment.listFromJson(cached);
      if (segs.isNotEmpty) {
        state = SegmentState(segments: segs);
        return;
      }
    }
    await compute(absolutePath);
  }

  /// 对绝对路径音频执行静音检测断句。
  Future<void> compute(String absolutePath) async {
    state = state.copyWith(loading: true);
    try {
      final int sampleRate = _pcmReader.readHeader(absolutePath).sampleRate;
      final Float64List samples = _pcmReader.readMono(absolutePath);
      final List<Segment> segs = _segmenter.segment(
        samples,
        sampleRate,
        const SegmentConfig(),
      );
      state = SegmentState(segments: segs);
      await _persist();
    } catch (_) {
      state = const SegmentState();
    }
  }

  /// 手动微调某句段边界。
  Future<void> updateSegment(int index, Segment segment) async {
    final List<Segment> next = List<Segment>.of(state.segments);
    if (index < 0 || index >= next.length) return;
    next[index] = segment;
    state = state.copyWith(segments: next);
    await _persist();
  }

  Future<void> _persist() async {
    final Recording? rec = _current;
    if (rec == null || rec.id == null) return;
    final String json = Segment.listToJson(state.segments);
    await ref
        .read(recordingRepositoryProvider)
        .update(rec.copyWith(segmentJson: json));
  }

  void reset() {
    _current = null;
    state = const SegmentState();
  }
}

final segmentProvider = NotifierProvider<SegmentNotifier, SegmentState>(
  SegmentNotifier.new,
);
