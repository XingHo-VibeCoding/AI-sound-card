/// 三维自评记录（流利度 / 准确度 / 完整度，1–5 分）。
///
/// 对应数据库表 `self_evaluation`，与录音 [Recording] 一对零或一。
class SelfEvaluation {
  const SelfEvaluation({
    this.id,
    required this.recordingId,
    required this.fluency,
    required this.accuracy,
    required this.completeness,
    this.note,
    required this.createdAt,
  });

  final int? id;
  final int recordingId;

  /// 流利度 1–5。
  final int fluency;

  /// 准确度 1–5。
  final int accuracy;

  /// 完整度 1–5。
  final int completeness;

  final String? note;
  final DateTime createdAt;

  SelfEvaluation copyWith({
    int? id,
    int? recordingId,
    int? fluency,
    int? accuracy,
    int? completeness,
    String? note,
    DateTime? createdAt,
  }) {
    return SelfEvaluation(
      id: id ?? this.id,
      recordingId: recordingId ?? this.recordingId,
      fluency: fluency ?? this.fluency,
      accuracy: accuracy ?? this.accuracy,
      completeness: completeness ?? this.completeness,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory SelfEvaluation.fromMap(Map<String, Object?> map) {
    return SelfEvaluation(
      id: map['id'] as int?,
      recordingId: map['recording_id'] as int? ?? 0,
      fluency: map['fluency'] as int? ?? 0,
      accuracy: map['accuracy'] as int? ?? 0,
      completeness: map['completeness'] as int? ?? 0,
      note: map['note'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int? ?? 0,
      ),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'recording_id': recordingId,
      'fluency': fluency,
      'accuracy': accuracy,
      'completeness': completeness,
      'note': note,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}
