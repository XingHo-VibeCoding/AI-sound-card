import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/audio_constants.dart';
import '../engine/analysis/waveform_extractor.dart';
import '../engine/audio/pcm_reader.dart';
import '../models/waveform_data.dart';
import 'providers.dart';

/// 波形服务：读取 WAV PCM 并抽取波形。
///
/// 抽取结果序列化为 JSON 缓存在 `Recording.waveformJson`，二次打开秒开。
class WaveformService {
  WaveformService(this._pcmReader, this._extractor);

  final PcmReader _pcmReader;
  final WaveformExtractor _extractor;

  /// 从绝对路径读取并抽取波形（同步，1 分钟音频耗时尚可，M2 再迁 compute）。
  WaveformData extractFromFile(
    String absolutePath, {
    int bucketCount = AudioConstants.defaultBucketCount,
  }) {
    final int sampleRate = _pcmReader.readHeader(absolutePath).sampleRate;
    final Float64List samples = _pcmReader.readMono(absolutePath);
    return _extractor.extract(samples, sampleRate, bucketCount: bucketCount);
  }

  /// 从已缓存的 waveformJson 恢复；无缓存或解析失败返回 empty。
  WaveformData fromCache(String? waveformJson) {
    return WaveformData.fromJsonString(waveformJson);
  }
}

final waveformServiceProvider = Provider<WaveformService>((ref) {
  return WaveformService(
    ref.watch(pcmReaderProvider),
    ref.watch(waveformExtractorProvider),
  );
});
