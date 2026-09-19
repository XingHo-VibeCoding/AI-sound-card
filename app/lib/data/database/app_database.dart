import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../core/error/app_exception.dart';
import 'db_helper.dart';

/// 建库 / 建表 / 版本迁移。
///
/// 4 张表：sentence / recording / self_evaluation / review_item，
/// 含外键与索引。建表语句使用 `IF NOT EXISTS`，可重复初始化不报错。
class AppDatabase {
  AppDatabase(this._helper);

  final DbHelper _helper;
  Database? _db;

  bool get isInitialized => _db != null;

  /// 已打开的数据库连接（初始化前访问抛错）。
  Database get db {
    final Database? current = _db;
    if (current == null) {
      throw StateError('AppDatabase 尚未初始化，请先调用 init()');
    }
    return current;
  }

  Future<void> init() async {
    final Database db = await _helper.open();
    await _createSchema(db);
    _db = db;
  }

  Future<void> close() => _helper.close();

  Future<void> _createSchema(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sentence (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          lesson_id INTEGER,
          text TEXT NOT NULL,
          phonetic TEXT,
          translation TEXT,
          audio_path TEXT,
          duration_ms INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS recording (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sentence_id INTEGER,
          file_path TEXT NOT NULL,
          duration_ms INTEGER NOT NULL DEFAULT 0,
          sample_rate INTEGER NOT NULL DEFAULT 44100,
          channels INTEGER NOT NULL DEFAULT 1,
          source TEXT NOT NULL DEFAULT 'practice',
          created_at INTEGER NOT NULL,
          waveform_json TEXT,
          segment_json TEXT,
          f0_json TEXT,
          FOREIGN KEY (sentence_id) REFERENCES sentence (id) ON DELETE SET NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_recording_sentence '
        'ON recording (sentence_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_recording_created '
        'ON recording (created_at)',
      );

      await db.execute('''
        CREATE TABLE IF NOT EXISTS self_evaluation (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          recording_id INTEGER NOT NULL,
          fluency INTEGER NOT NULL,
          accuracy INTEGER NOT NULL,
          completeness INTEGER NOT NULL,
          note TEXT,
          created_at INTEGER NOT NULL,
          FOREIGN KEY (recording_id) REFERENCES recording (id) ON DELETE CASCADE
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_eval_recording '
        'ON self_evaluation (recording_id)',
      );

      await db.execute('''
        CREATE TABLE IF NOT EXISTS review_item (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sentence_id INTEGER,
          recording_id INTEGER,
          type TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          next_review_at INTEGER,
          interval_days INTEGER NOT NULL DEFAULT 0,
          ease_factor REAL NOT NULL DEFAULT 2.5,
          repetitions INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (sentence_id) REFERENCES sentence (id) ON DELETE SET NULL,
          FOREIGN KEY (recording_id) REFERENCES recording (id) ON DELETE SET NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_review_next ON review_item (next_review_at)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_review_type ON review_item (type)',
      );
    } catch (e) {
      throw DatabaseException('初始化数据库表失败', e);
    }
  }
}
