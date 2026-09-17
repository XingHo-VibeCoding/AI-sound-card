import 'dart:convert';

/// 波形数据（PCM 分桶压缩后的峰值 + RMS）。
///
/// [peaks] 每桶绝对峰值（0–1），[rms] 每桶均方根能量（0–1），
/// 二者长度相等，均等于 [bucketCount]。
class WaveformData {
  const WaveformData({
    required this.peaks,
    required this.rms,
    required this.sampleRate,
    required this.durationMs,
    required this.bucketCount,
  });

  final List<double> peaks;
  final List<double> rms;
  final int sampleRate;
  final int durationMs;
  final int bucketCount;

  static const WaveformData empty = WaveformData(
    peaks: <double>[],
    rms: <double>[],
    sampleRate: 0,
    durationMs: 0,
    bucketCount: 0,
  );

  bool get isEmpty => peaks.isEmpty;

  factory WaveformData.fromJson(Map<String, dynamic> json) {
    return WaveformData(
      peaks: _toDoubleList(json['peaks']),
      rms: _toDoubleList(json['rms']),
      sampleRate: json['sampleRate'] as int? ?? 0,
      durationMs: json['durationMs'] as int? ?? 0,
      bucketCount: json['bucketCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'peaks': peaks,
      'rms': rms,
      'sampleRate': sampleRate,
      'durationMs': durationMs,
      'bucketCount': bucketCount,
    };
  }

  /// 序列化为 JSON 字符串。
  String toJsonString() => jsonEncode(toJson());

  /// 从 JSON 字符串反序列化（容错：失败返回 empty）。
  static WaveformData fromJsonString(String? json) {
    if (json == null || json.isEmpty) return WaveformData.empty;
    try {
      final Object? decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return WaveformData.empty;
      return WaveformData.fromJson(decoded);
    } catch (_) {
      return WaveformData.empty;
    }
  }

  static List<double> _toDoubleList(Object? value) {
    if (value is! List) return <double>[];
    return value.map((Object? e) => (e as num).toDouble()).toList();
  }
}
