import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:record/record.dart' as record_pkg;

import '../../core/constants/app_constants.dart';
import '../../core/constants/audio_constants.dart';
import '../../core/error/app_exception.dart';
import '../../models/recording.dart';

/// 录音封装（基于 `record` 包，WAV PCM16 44.1kHz 单声道）。
///
/// 纯 Dart 控制器，无 UI 依赖。[recordingsDirectory] 为录音输出目录
/// （应用文档目录下的 `recordings/`），由 Provider 注入。
class AudioRecorder {
  AudioRecorder({required Directory recordingsDirectory})
      : _recordingsDirectory = recordingsDirectory;

  final Directory _recordingsDirectory;
  final record_pkg.AudioRecorder _recorder = record_pkg.AudioRecorder();

  bool _isRecording = false;
  String? _currentAbsolutePath;
  String _source = RecordingSource.practice;
  int? _sentenceId;
  int _startedAtMs = 0;

  StreamSubscription<record_pkg.Amplitude>? _ampSub;

  bool get isRecording => _isRecording;

  /// 最近一次录音的绝对路径（成功 stop 后有效）。
  String? get lastAbsolutePath => _currentAbsolutePath;

  /// 录音音量流，映射为 0–100 的整数（供电平条/耳返预留）。
  Stream<int> get amplitudeStream =>
      _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .map((record_pkg.Amplitude amp) => _amplitudeToPercent(amp.current));

  /// 开始录音。
  Future<void> start({
    String source = RecordingSource.practice,
    int? sentenceId,
  }) async {
    if (_isRecording) {
      throw const AudioEngineException('已在录音中');
    }
    if (!await _recordingsDirectory.exists()) {
      await _recordingsDirectory.create(recursive: true);
    }
    final String fileName =
        'rec_${DateTime.now().millisecondsSinceEpoch}.wav';
    final String absPath = p.join(_recordingsDirectory.path, fileName);
    _source = source;
    _sentenceId = sentenceId;
    _currentAbsolutePath = absPath;
    _startedAtMs = DateTime.now().millisecondsSinceEpoch;
    try {
      await _recorder.start(
        const record_pkg.RecordConfig(
          encoder: record_pkg.AudioEncoder.wav,
          sampleRate: AudioConstants.sampleRate,
          numChannels: AudioConstants.channels,
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ),
        path: absPath,
      );
      _isRecording = true;
    } catch (e) {
      _isRecording = false;
      throw AudioEngineException('开始录音失败', e);
    }
  }

  /// 停止录音，返回 [Recording]（相对路径 + 时长）。
  Future<Recording> stop() async {
    if (!_isRecording) {
      throw const AudioEngineException('当前未在录音');
    }
    try {
      await _recorder.stop();
    } catch (e) {
      throw AudioEngineException('停止录音失败', e);
    } finally {
      _isRecording = false;
    }
    final int durationMs = DateTime.now().millisecondsSinceEpoch - _startedAtMs;
    final String fileName = p.basename(_currentAbsolutePath ?? '');
    final String relPath = '${AppConstants.recordingsSubdir}/$fileName';
    return Recording(
      sentenceId: _sentenceId,
      filePath: relPath,
      durationMs: durationMs,
      sampleRate: AudioConstants.sampleRate,
      channels: AudioConstants.channels,
      source: _source,
      createdAt: DateTime.now(),
    );
  }

  /// 取消录音（丢弃当前录音文件）。
  Future<void> cancel() async {
    if (!_isRecording) return;
    try {
      await _recorder.cancel();
    } catch (_) {
      // 取消失败不阻断主流程。
    } finally {
      _isRecording = false;
    }
    await deleteLastFile();
  }

  /// 删除最近一次录音文件（用于 <1s 丢弃场景）。
  Future<void> deleteLastFile() async {
    final String? abs = _currentAbsolutePath;
    if (abs == null) return;
    try {
      final File file = File(abs);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // 文件删除失败不影响逻辑。
    }
  }

  Future<void> dispose() async {
    await _ampSub?.cancel();
    try {
      await _recorder.dispose();
    } catch (_) {
      // ignore
    }
  }

  static int _amplitudeToPercent(double dbFs) {
    // dBFS 约 -160..0，映射 -60..0 到 0..100。
    final double clamped = dbFs.clamp(-60.0, 0.0);
    return ((clamped + 60.0) / 60.0 * 100).round().clamp(0, 100);
  }
}
