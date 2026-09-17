import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../../core/constants/app_constants.dart';
import '../../models/sentence.dart';
import '../repositories/sentence_repository.dart';

/// 内置示例数据种子。
///
/// 首次启动时插入 >=1 条示例 [Sentence]，并将打包的示例原声
/// （assets/sample/sample_sentence.wav）复制到文档目录 `recordings/`，
/// DB 中只记录相对路径。
class SampleSeed {
  SampleSeed._();

  static Future<void> ensureSeeded({
    required SentenceRepository sentenceRepository,
    required Directory documentsDir,
  }) async {
    final List<Sentence> existing = await sentenceRepository.list();
    if (existing.isNotEmpty) return;

    final Directory recordingsDir = Directory(
      p.join(documentsDir.path, AppConstants.recordingsSubdir),
    );
    await recordingsDir.create(recursive: true);

    final File target = File(p.join(recordingsDir.path, AppConstants.seedFileName));
    if (!await target.exists()) {
      final ByteData data = await rootBundle.load(AppConstants.seedAssetPath);
      final Uint8List bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await target.writeAsBytes(bytes, flush: true);
    }

    final int durationMs = _wavDurationMs(await target.readAsBytes());

    final Sentence sentence = Sentence(
      text: 'People',
      phonetic: '/ˈpiːp(ə)l/',
      translation: '人们；人民',
      audioPath: '${AppConstants.recordingsSubdir}/${AppConstants.seedFileName}',
      durationMs: durationMs,
    );
    await sentenceRepository.insert(sentence);
  }

  /// 从内存中的 WAV 字节解析时长（PCM16 单声道，44.1kHz）。
  ///
  /// 自包含实现，避免 data 层反向依赖 engine 层。解析失败回退为已知种子时长。
  static int _wavDurationMs(Uint8List bytes) {
    try {
      if (bytes.length < 44) return 5355;
      final ByteData data = ByteData.sublistView(bytes);
      final int channels = data.getUint16(22, Endian.little);
      final int sampleRate = data.getUint32(24, Endian.little);
      final int bitsPerSample = data.getUint16(34, Endian.little);
      // 遍历查找 data chunk 大小。
      int offset = 12;
      int dataSize = 0;
      while (offset + 8 <= bytes.length) {
        final String id = String.fromCharCodes(
          bytes.sublist(offset, offset + 4),
        );
        final int size = data.getUint32(offset + 4, Endian.little);
        if (id == 'data') {
          dataSize = size;
          break;
        }
        offset += 8 + size + (size & 1);
      }
      final int bytesPerSample = bitsPerSample ~/ 8;
      final int numFrames =
          (channels * bytesPerSample) == 0
              ? 0
              : dataSize ~/ (channels * bytesPerSample);
      if (sampleRate == 0) return 5355;
      return (numFrames * 1000 / sampleRate).round();
    } catch (_) {
      // 解析失败回退为已知种子时长（5355ms），保证首启不因种子音频损坏而中断。
      return 5355;
    }
  }
}
