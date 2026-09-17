/// 音频相关常量：录音格式、变速档位、波形分桶、断句参数、AB 复读默认值。
///
/// 约定：采样率/声道/位深为 M1 统一录音格式（WAV PCM16 44.1kHz 单声道）。
class AudioConstants {
  AudioConstants._();

  /// 采样率（Hz）。
  static const int sampleRate = 44100;

  /// 声道数（单声道）。
  static const int channels = 1;

  /// 位深（PCM16）。
  static const int bitsPerSample = 16;

  /// 变速不变调范围下限。
  static const double minSpeed = 0.5;

  /// 变速不变调范围上限。
  static const double maxSpeed = 2.0;

  /// 语速档位（唯一维护点），UI 与引擎均从此读取。
  static const List<double> speedLevels = <double>[
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

  /// 默认语速。
  static const double defaultSpeed = 1.0;

  /// 录音最短有效时长（ms），低于此值的录音在 RecorderProvider 层丢弃。
  static const int minValidDurationMs = 1000;

  /// 波形抽取默认分桶数。
  static const int defaultBucketCount = 800;

  /// 波形抽取分桶数下限 / 上限。
  static const int minBucketCount = 200;
  static const int maxBucketCount = 2000;

  // ---- 断句默认参数 ----

  /// 分帧长度（ms）。
  static const int segmentFrameMs = 20;

  /// 静音判定阈值（dBFS），低于此值视为静音帧。
  static const double segmentSilenceDb = -40.0;

  /// 连续静音超过该时长（ms）视为切句点。
  static const int segmentMinSilenceMs = 300;

  /// 句段最短保留时长（ms），过短片段丢弃。
  static const int segmentMinSegmentMs = 500;

  // ---- AB 复读默认参数 ----

  /// 重复次数默认值，0 表示无限循环。
  static const int abLoopDefaultRepeatCount = 0;

  /// 两次循环之间的间隔默认值（ms）。
  static const int abLoopDefaultIntervalMs = 0;
}
