import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants/app_constants.dart';
import '../data/database/app_database.dart';
import '../data/database/db_helper.dart';
import '../data/repositories/evaluation_repository.dart';
import '../data/repositories/recording_repository.dart';
import '../data/repositories/review_repository.dart';
import '../data/repositories/sentence_repository.dart';
import '../data/seed/sample_seed.dart';
import '../engine/analysis/f0_extractor.dart';
import '../engine/analysis/sentence_segmenter.dart';
import '../engine/analysis/waveform_extractor.dart';
import '../engine/audio/pcm_reader.dart';
import '../models/recording.dart';
import '../models/sentence.dart';

// ---------------------------------------------------------------------------
// 数据库与仓库
// ---------------------------------------------------------------------------

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final AppDatabase db = AppDatabase(DbHelper.instance);
  ref.onDispose(db.close);
  return db;
});

/// 已初始化的数据库连接（await 此 provider 即完成建库建表）。
final databaseProvider = FutureProvider<Database>((ref) async {
  final AppDatabase appDb = ref.watch(appDatabaseProvider);
  await appDb.init();
  return appDb.db;
});

final sentenceRepositoryProvider = Provider<SentenceRepository>((ref) {
  return SentenceRepository(ref.watch(appDatabaseProvider));
});

final recordingRepositoryProvider = Provider<RecordingRepository>((ref) {
  return RecordingRepository(ref.watch(appDatabaseProvider));
});

final evaluationRepositoryProvider = Provider<EvaluationRepository>((ref) {
  return EvaluationRepository(ref.watch(appDatabaseProvider));
});

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(ref.watch(appDatabaseProvider));
});

// ---------------------------------------------------------------------------
// 文件系统
// ---------------------------------------------------------------------------

/// 应用文档目录路径（String）。
final documentsDirPathProvider = FutureProvider<String>((ref) async {
  final Directory dir = await getApplicationDocumentsDirectory();
  return dir.path;
});

/// 录音输出目录（惰性创建）。
final recordingsDirectoryProvider = FutureProvider<Directory>((ref) async {
  final Directory docs = await getApplicationDocumentsDirectory();
  final Directory dir = Directory(
    p.join(docs.path, AppConstants.recordingsSubdir),
  );
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
});

/// 相对路径 -> 绝对路径（相对应用文档目录）。
String resolveRecordingAbsolutePath(String documentsDirPath, String relativePath) {
  return p.join(documentsDirPath, relativePath);
}

// ---------------------------------------------------------------------------
// 种子数据
// ---------------------------------------------------------------------------

/// 首次启动写入示例句子并复制示例原声。
final seedProvider = FutureProvider<void>((ref) async {
  final SentenceRepository repo = ref.watch(sentenceRepositoryProvider);
  final Directory docs = await getApplicationDocumentsDirectory();
  await SampleSeed.ensureSeeded(sentenceRepository: repo, documentsDir: docs);
});

// ---------------------------------------------------------------------------
// 引擎级无状态组件
// ---------------------------------------------------------------------------

final pcmReaderProvider = Provider<PcmReader>((ref) => const PcmReader());

final waveformExtractorProvider = Provider<WaveformExtractor>(
  (ref) => const WaveformExtractor(),
);

final sentenceSegmenterProvider = Provider<SentenceSegmenter>(
  (ref) => const SentenceSegmenter(),
);

final f0ExtractorProvider = Provider<F0Extractor>(
  (ref) => const PlaceholderF0Extractor(),
);

// ---------------------------------------------------------------------------
// 只读数据 Provider（供列表 / 详情页面消费）
// ---------------------------------------------------------------------------

/// 全部句子（首次访问会先完成种子初始化）。
final sentencesProvider = FutureProvider<List<Sentence>>((ref) async {
  await ref.watch(seedProvider.future);
  return ref.watch(sentenceRepositoryProvider).list();
});

/// 按 id 查询句子。
final sentenceByIdProvider = FutureProvider.family<Sentence?, int>((
  ref,
  int id,
) async {
  await ref.watch(seedProvider.future);
  return ref.watch(sentenceRepositoryProvider).getById(id);
});

/// 全部录音。
final recordingsProvider = FutureProvider<List<Recording>>((ref) async {
  return ref.watch(recordingRepositoryProvider).list();
});

/// 按句子查询录音。
final recordingsBySentenceProvider =
    FutureProvider.family<List<Recording>, int>((ref, int sentenceId) async {
      return ref.watch(recordingRepositoryProvider).listBySentence(sentenceId);
    });
