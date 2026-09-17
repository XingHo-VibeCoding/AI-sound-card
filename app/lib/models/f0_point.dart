import 'dart:convert';

/// 基频（F0）采样点。
///
/// M1 仅预留数据结构与采集接口，算法在 M5 实现。字段可能随 AI 团队对齐调整。
class F0Point {
  const F0Point({
    required this.timeMs,
    required this.freqHz,
    required this.confidence,
  });

  /// 时间位置（ms）。
  final double timeMs;

  /// 基频（Hz）。
  final double freqHz;

  /// 置信度（0–1）。
  final double confidence;

  factory F0Point.fromJson(Map<String, dynamic> json) {
    return F0Point(
      timeMs: (json['timeMs'] as num?)?.toDouble() ?? 0,
      freqHz: (json['freqHz'] as num?)?.toDouble() ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'timeMs': timeMs,
      'freqHz': freqHz,
      'confidence': confidence,
    };
  }

  /// 列表 -> JSON 字符串。
  static String listToJson(List<F0Point> points) {
    return jsonEncode(points.map((F0Point p) => p.toJson()).toList());
  }

  /// JSON 字符串 -> 列表（容错：失败返回空表）。
  static List<F0Point> listFromJson(String? json) {
    if (json == null || json.isEmpty) return <F0Point>[];
    try {
      final Object? decoded = jsonDecode(json);
      if (decoded is! List) return <F0Point>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(F0Point.fromJson)
          .toList();
    } catch (_) {
      return <F0Point>[];
    }
  }
}
