import '../../models/review_item.dart';
import '../database/app_database.dart';

/// 复习池仓库。
class ReviewRepository {
  ReviewRepository(this._db);

  final AppDatabase _db;

  Future<int> insert(ReviewItem item) {
    return _db.db.insert('review_item', item.toMap());
  }

  Future<void> update(ReviewItem item) async {
    if (item.id == null) return;
    await _db.db.update(
      'review_item',
      item.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[item.id],
    );
  }

  Future<void> delete(int id) async {
    await _db.db.delete(
      'review_item',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// 全部条目（按 nextReviewAt 升序，null 视为最早）。
  Future<List<ReviewItem>> listAll() async {
    final List<Map<String, Object?>> rows = await _db.db.query(
      'review_item',
      orderBy: 'next_review_at IS NULL DESC, next_review_at ASC',
    );
    return rows.map(ReviewItem.fromMap).toList();
  }

  /// 到期条目（nextReviewAt 为空或 <= now）。
  Future<List<ReviewItem>> due([DateTime? now]) async {
    final DateTime ref = now ?? DateTime.now();
    final int nowMs = ref.millisecondsSinceEpoch;
    final List<Map<String, Object?>> rows = await _db.db.query(
      'review_item',
      where: 'next_review_at IS NULL OR next_review_at <= ?',
      whereArgs: <Object?>[nowMs],
      orderBy: 'next_review_at IS NULL DESC, next_review_at ASC',
    );
    return rows.map(ReviewItem.fromMap).toList();
  }
}
