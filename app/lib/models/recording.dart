/// 录音记录。
///
/// 音频文件存应用文档目录 `recordings/`，DB 仅存相对路径 [filePath]。
/// 波形/断句/基频均序列化为 JSON 字符串存入对应 `*Json` 字段（可空）。
class Recording {
  const Recording({
    this.id,
    this.sentenceId,
    required this.filePath,
    this.durationMs = 0,
    this.sampleRate = 44100,
    this.channels = 1,
    this.source = RecordingSource.practice,
    required this.createdAt,
    this.waveformJson,
    this.segmentJson,
    this.f0Json,
  });

  final int? id;
  final int? sentenceId;

  /// 相对路径，如 `recordings/rec_1690000000000.wav`。
  final String filePath;
  final int durationMs;
  final int sampleRate;
  final int channels;

  /// 来源：seed / practice / follow。
  final String source;
  final DateTime createdAt;

  final String? waveformJson;
  final String? segmentJson;
  final String? f0Json;

  Recording copyWith({
    Object? id = _unset,
    Object? sentenceId = _unset,
    String? filePath,
    int? durationMs,
    int? sampleRate,
    int? channels,
    String? source,
    DateTime? createdAt,
    Object? waveformJson = _unset,
    Object? segmentJson = _unset,
    Object? f0Json = _unset,
  }) {
    return Recording(
      id: identical(id, _unset) ? this.id : id as int?,
      sentenceId:
          identical(sentenceId, _unset) ? this.sentenceId : sentenceId as int?,
      filePath: filePath ?? this.filePath,
      durationMs: durationMs ?? this.durationMs,
      sampleRate: sampleRate ?? this.sampleRate,
      channels: channels ?? this.channels,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      waveformJson: identical(waveformJson, _unset)
          ? this.waveformJson
          : waveformJson as String?,
      segmentJson: identical(segmentJson, _unset)
          ? this.segmentJson
          : segmentJson as String?,
      f0Json: identical(f0Json, _unset) ? this.f0Json : f0Json as String?,
    );
  }

  static const Object _unset = Object();

  factory Recording.fromMap(Map<String, Object?> map) {
    return Recording(
      id: map['id'] as int?,
      sentenceId: map['sentence_id'] as int?,
      filePath: map['file_path'] as String? ?? '',
      durationMs: map['duration_ms'] as int? ?? 0,
      sampleRate: map['sample_rate'] as int? ?? 44100,
      channels: map['channels'] as int? ?? 1,
      source: map['source'] as String? ?? RecordingSource.practice,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int? ?? 0,
      ),
      waveformJson: map['waveform_json'] as String?,
      segmentJson: map['segment_json'] as String?,
      f0Json: map['f0_json'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'sentence_id': sentenceId,
      'file_path': filePath,
      'duration_ms': durationMs,
      'sample_rate': sampleRate,
      'channels': channels,
      'source': source,
      'created_at': createdAt.millisecondsSinceEpoch,
      'waveform_json': waveformJson,
      'segment_json': segmentJson,
      'f0_json': f0Json,
    };
  }
}

/// 录音来源常量。
class RecordingSource {
  RecordingSource._();

  static const String seed = 'seed';
  static const String practice = 'practice';
  static const String follow = 'follow';
}
