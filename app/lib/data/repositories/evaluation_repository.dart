import '../../models/self_evaluation.dart';
import '../database/app_database.dart';

/// 自评仓库。
class EvaluationRepository {
  EvaluationRepository(this._db);

  final AppDatabase _db;

  Future<int> insert(SelfEvaluation evaluation) {
    return _db.db.insert('self_evaluation', evaluation.toMap());
  }

  /// 某录音的所有自评记录（按时间正序）。
  Future<List<SelfEvaluation>> byRecording(int recordingId) async {
    final List<Map<String, Object?>> rows = await _db.db.query(
      'self_evaluation',
      where: 'recording_id = ?',
      whereArgs: <Object?>[recordingId],
      orderBy: 'created_at ASC',
    );
    return rows.map(SelfEvaluation.fromMap).toList();
  }

  /// 全部自评记录（列表页聚合展示）。
  Future<List<SelfEvaluation>> listAll() async {
    final List<Map<String, Object?>> rows = await _db.db.query(
      'self_evaluation',
      orderBy: 'created_at DESC',
    );
    return rows.map(SelfEvaluation.fromMap).toList();
  }
}
