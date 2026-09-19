import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../core/constants/app_constants.dart';
import '../../core/error/app_exception.dart';

/// SQLite 连接单例 + 通用查询辅助。
///
/// 只负责"连接管理"，schema 的建表/迁移逻辑见 [AppDatabase]。
class DbHelper {
  DbHelper._();

  static final DbHelper instance = DbHelper._();

  Database? _db;

  /// 获取（必要时打开）数据库连接。
  Future<Database> open() async {
    final Database? existing = _db;
    if (existing != null && existing.isOpen) return existing;
    try {
      final String dir = await getDatabasesPath();
      final String path = p.join(dir, AppConstants.dbFileName);
      final Database db = await openDatabase(
        path,
        version: AppConstants.dbVersion,
        onConfigure: (Database db) async {
          // 启用外键约束（SQLite 默认关闭）。
          await db.execute('PRAGMA foreign_keys = ON');
        },
      );
      _db = db;
      return db;
    } catch (e) {
      throw DatabaseException('打开数据库失败', e);
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// 通用插入，返回自增主键。
  Future<int> insert(String table, Map<String, Object?> values) async {
    final Database db = await open();
    return db.insert(table, values, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 通用批量插入。
  Future<void> insertAll(
    String table,
    List<Map<String, Object?>> values,
  ) async {
    final Database db = await open();
    final Batch batch = db.batch();
    for (final Map<String, Object?> row in values) {
      batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// 通用更新。
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final Database db = await open();
    return db.update(table, values, where: where, whereArgs: whereArgs);
  }

  /// 通用删除。
  Future<int> delete(
    String table, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final Database db = await open();
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  /// 通用查询。
  Future<List<Map<String, Object?>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final Database db = await open();
    return db.query(
      table,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }
}
