import '../../models/sentence.dart';
import '../database/app_database.dart';

/// 句子仓库。
class SentenceRepository {
  SentenceRepository(this._db);

  final AppDatabase _db;

  Future<int> insert(Sentence sentence) {
    return _db.db.insert('sentence', sentence.toMap());
  }

  /// 种子数据批量写入。
  Future<void> seed(List<Sentence> sentences) async {
    for (final Sentence s in sentences) {
      await insert(s);
    }
  }

  Future<List<Sentence>> list() async {
    final List<Map<String, Object?>> rows = await _db.db.query(
      'sentence',
      orderBy: 'id ASC',
    );
    return rows.map(Sentence.fromMap).toList();
  }

  Future<Sentence?> getById(int id) async {
    final List<Map<String, Object?>> rows = await _db.db.query(
      'sentence',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Sentence.fromMap(rows.first);
  }

  Future<void> update(Sentence sentence) async {
    if (sentence.id == null) return;
    await _db.db.update(
      'sentence',
      sentence.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[sentence.id],
    );
  }

  Future<void> delete(int id) async {
    await _db.db.delete('sentence', where: 'id = ?', whereArgs: <Object?>[id]);
  }
}
