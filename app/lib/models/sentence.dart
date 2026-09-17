/// 句子（示例原声句 / 课程句子）。
///
/// 对应数据库表 `sentence`。[audioPath] 存储相对路径（相对应用文档目录）。
class Sentence {
  const Sentence({
    this.id,
    this.lessonId,
    required this.text,
    this.phonetic,
    this.translation,
    this.audioPath,
    this.durationMs = 0,
  });

  final int? id;
  final int? lessonId;
  final String text;
  final String? phonetic;
  final String? translation;

  /// 相对路径，如 `recordings/seed_sentence.wav`。
  final String? audioPath;

  /// 原声时长（ms）。
  final int durationMs;

  Sentence copyWith({
    int? id,
    int? lessonId,
    String? text,
    String? phonetic,
    String? translation,
    String? audioPath,
    int? durationMs,
  }) {
    return Sentence(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      text: text ?? this.text,
      phonetic: phonetic ?? this.phonetic,
      translation: translation ?? this.translation,
      audioPath: audioPath ?? this.audioPath,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  /// 数据库行 -> 模型。
  factory Sentence.fromMap(Map<String, Object?> map) {
    return Sentence(
      id: map['id'] as int?,
      lessonId: map['lesson_id'] as int?,
      text: map['text'] as String? ?? '',
      phonetic: map['phonetic'] as String?,
      translation: map['translation'] as String?,
      audioPath: map['audio_path'] as String?,
      durationMs: map['duration_ms'] as int? ?? 0,
    );
  }

  /// 模型 -> 数据库行。
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'lesson_id': lessonId,
      'text': text,
      'phonetic': phonetic,
      'translation': translation,
      'audio_path': audioPath,
      'duration_ms': durationMs,
    };
  }

  factory Sentence.fromJson(Map<String, dynamic> json) {
    return Sentence(
      id: json['id'] as int?,
      lessonId: json['lessonId'] as int?,
      text: json['text'] as String? ?? '',
      phonetic: json['phonetic'] as String?,
      translation: json['translation'] as String?,
      audioPath: json['audioPath'] as String?,
      durationMs: json['durationMs'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'lessonId': lessonId,
      'text': text,
      'phonetic': phonetic,
      'translation': translation,
      'audioPath': audioPath,
      'durationMs': durationMs,
    };
  }
}
