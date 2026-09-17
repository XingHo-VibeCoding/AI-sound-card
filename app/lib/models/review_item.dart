/// 复习池条目。
///
/// [type] 为 `favorite | error | word`。基于简化的间隔重复策略：
/// 每次"会了"按 easeFactor 放大复习间隔，"又错了"则重置。
class ReviewItem {
  const ReviewItem({
    this.id,
    this.sentenceId,
    this.recordingId,
    required this.type,
    required this.createdAt,
    this.nextReviewAt,
    this.intervalDays = 0,
    this.easeFactor = 2.5,
    this.repetitions = 0,
  });

  final int? id;
  final int? sentenceId;
  final int? recordingId;
  final String type;
  final DateTime createdAt;

  /// 下次复习时间；null 视为"立即可复习"。
  final DateTime? nextReviewAt;

  /// 当前复习间隔（天）。
  final int intervalDays;

  /// 难度系数（>1 表示记忆越牢固，间隔增长越快）。
  final double easeFactor;

  /// 已复习次数。
  final int repetitions;

  /// 是否到期。
  bool isDue(DateTime now) =>
      nextReviewAt == null || !nextReviewAt!.isAfter(now);

  ReviewItem copyWith({
    int? id,
    int? sentenceId,
    int? recordingId,
    String? type,
    DateTime? createdAt,
    DateTime? nextReviewAt,
    int? intervalDays,
    double? easeFactor,
    int? repetitions,
  }) {
    return ReviewItem(
      id: id ?? this.id,
      sentenceId: sentenceId ?? this.sentenceId,
      recordingId: recordingId ?? this.recordingId,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      intervalDays: intervalDays ?? this.intervalDays,
      easeFactor: easeFactor ?? this.easeFactor,
      repetitions: repetitions ?? this.repetitions,
    );
  }

  factory ReviewItem.fromMap(Map<String, Object?> map) {
    final int? nextAt = map['next_review_at'] as int?;
    return ReviewItem(
      id: map['id'] as int?,
      sentenceId: map['sentence_id'] as int?,
      recordingId: map['recording_id'] as int?,
      type: map['type'] as String? ?? ReviewType.error.name,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int? ?? 0,
      ),
      nextReviewAt: nextAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(nextAt),
      intervalDays: map['interval_days'] as int? ?? 0,
      easeFactor: (map['ease_factor'] as num?)?.toDouble() ?? 2.5,
      repetitions: map['repetitions'] as int? ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'sentence_id': sentenceId,
      'recording_id': recordingId,
      'type': type,
      'created_at': createdAt.millisecondsSinceEpoch,
      'next_review_at': nextReviewAt?.millisecondsSinceEpoch,
      'interval_days': intervalDays,
      'ease_factor': easeFactor,
      'repetitions': repetitions,
    };
  }
}

/// 复习条目类型。
enum ReviewType {
  favorite,
  error,
  word,
}
