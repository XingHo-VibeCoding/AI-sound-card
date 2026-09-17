/// 应用级常量：应用名、版本、数据库名、存储子目录、种子资源、路由表。
///
/// 所有跨文件共享的"名字"与"路径"统一在这里维护，避免散落魔法字符串。
class AppConstants {
  AppConstants._();

  static const String appName = '录音卡';
  static const String appVersion = '0.1.0';

  /// SQLite 数据库文件名（位于 sqflite 默认数据库目录）。
  static const String dbFileName = 'recording_card.db';

  /// 数据库 schema 版本，后续迁移在此递增。
  static const int dbVersion = 1;

  /// 音频文件在应用文档目录下的相对子目录，DB 仅存相对路径。
  static const String recordingsSubdir = 'recordings';

  /// 内置示例原声资源路径（打包进 assets 的 seed）。
  static const String seedAssetPath = 'assets/sample/sample_sentence.wav';

  /// 种子原声复制到文档目录后的文件名。
  static const String seedFileName = 'seed_sentence.wav';
}

/// 路由路径表。M1 共 5 个页面。
class AppRoutes {
  AppRoutes._();

  static const String home = '/home';
  static const String practice = '/practice';
  static const String compare = '/compare';
  static const String recordings = '/recordings';
  static const String review = '/review';
}
