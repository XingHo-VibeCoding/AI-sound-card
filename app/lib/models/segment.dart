import 'dart:convert';

/// 句段（断句结果的一段），时间单位为 int 毫秒。
class Segment {
  const Segment({required this.startMs, required this.endMs, this.text});

  final int startMs;
  final int endMs;
  final String? text;

  int get durationMs => endMs - startMs;

  Segment copyWith({int? startMs, int? endMs, String? text}) {
    return Segment(
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      text: text ?? this.text,
    );
  }

  factory Segment.fromJson(Map<String, dynamic> json) {
    return Segment(
      startMs: json['startMs'] as int? ?? 0,
      endMs: json['endMs'] as int? ?? 0,
      text: json['text'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'startMs': startMs, 'endMs': endMs, 'text': text};
  }

  /// 列表 -> JSON 字符串。
  static String listToJson(List<Segment> segments) {
    return jsonEncode(segments.map((Segment s) => s.toJson()).toList());
  }

  /// JSON 字符串 -> 列表（容错：解析失败返回空表，不抛异常）。
  static List<Segment> listFromJson(String? json) {
    if (json == null || json.isEmpty) return <Segment>[];
    try {
      final Object? decoded = jsonDecode(json);
      if (decoded is! List) return <Segment>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Segment.fromJson)
          .toList();
    } catch (_) {
      return <Segment>[];
    }
  }
}

/// 断句参数（静音检测阈值等），可由 UI 调整。
class SegmentConfig {
  const SegmentConfig({
    this.frameMs = 20,
    this.silenceDb = -40.0,
    this.minSilenceMs = 300,
    this.minSegmentMs = 500,
  });

  final int frameMs;
  final double silenceDb;
  final int minSilenceMs;
  final int minSegmentMs;
}
