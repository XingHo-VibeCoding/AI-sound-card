import '../../models/recording.dart';
import '../database/app_database.dart';

/// 录音仓库。
class RecordingRepository {
  RecordingRepository(this._db);

  final AppDatabase _db;

  Future<int> insert(Recording recording) {
    return _db.db.insert('recording', recording.toMap());
  }

  Future<List<Recording>> list() async {
    final List<Map<String, Object?>> rows = await _db.db.query(
      'recording',
      orderBy: 'created_at DESC',
    );
    return rows.map(Recording.fromMap).toList();
  }

  /// 按句子查询录音（用于进入某句练习时的历史录音）。
  Future<List<Recording>> listBySentence(int sentenceId) async {
    final List<Map<String, Object?>> rows = await _db.db.query(
      'recording',
      where: 'sentence_id = ?',
      whereArgs: <Object?>[sentenceId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Recording.fromMap).toList();
  }

  Future<Recording?> getById(int id) async {
    final List<Map<String, Object?>> rows = await _db.db.query(
      'recording',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Recording.fromMap(rows.first);
  }

  Future<void> update(Recording recording) async {
    if (recording.id == null) return;
    await _db.db.update(
      'recording',
      recording.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[recording.id],
    );
  }

  Future<void> delete(int id) async {
    await _db.db.delete(
      'recording',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }
}
