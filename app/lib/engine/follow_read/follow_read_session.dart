import 'dart:async';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../core/constants/audio_constants.dart';
import '../../core/error/app_exception.dart';
import '../../models/recording.dart';
import '../../models/review_item.dart';
import '../../models/self_evaluation.dart';
import '../../models/sentence.dart';
import '../../models/waveform_data.dart';
import '../analysis/waveform_extractor.dart';
import '../audio/audio_player_controller.dart';
import '../audio/audio_recorder.dart';
import '../audio/pcm_reader.dart';

/// 跟读对比阶段。
enum FollowReadPhase {
  idle,
  playingOriginal,
  recording,
  comparing,
  done,
}

/// 跟读对比会话状态机。
///
/// 状态流转：`Idle → PlayingOriginal → Recording → Comparing → Done`。
/// 原声播完自动切到录音态。持久化通过注入的回调完成，保持纯 Dart、
/// 无 UI 依赖、可单测。
class FollowReadSession {
  FollowReadSession({
    required String documentsDirPath,
    PcmReader pcmReader = const PcmReader(),
    WaveformExtractor waveformExtractor = const WaveformExtractor(),
    AudioRecorder? recorder,
    Future<int> Function(SelfEvaluation evaluation)? onSaveEvaluation,
    Future<int> Function(ReviewItem item)? onMarkReview,
  })  : _documentsDirPath = documentsDirPath,
        _pcmReader = pcmReader,
        _waveformExtractor = waveformExtractor,
        _recorder = recorder,
        _onSaveEvaluation = onSaveEvaluation,
        _onMarkReview = onMarkReview {
    _player.completedStream.listen((_) => _onPlayerCompleted());
  }

  final String _documentsDirPath;
  final PcmReader _pcmReader;
  final WaveformExtractor _waveformExtractor;
  final AudioRecorder? _recorder;
  final Future<int> Function(SelfEvaluation evaluation)? _onSaveEvaluation;
  final Future<int> Function(ReviewItem item)? _onMarkReview;

  final AudioPlayerController _player = AudioPlayerController();
  final StreamController<FollowReadPhase> _phaseController =
      StreamController<FollowReadPhase>.broadcast();

  FollowReadPhase _phase = FollowReadPhase.idle;
  bool _awaitOriginal = false;
  Sentence? _sentence;
  Recording? _myRecording;
  WaveformData? _originalWaveform;
  WaveformData? _mineWaveform;

  FollowReadPhase get phase => _phase;
  Sentence? get sentence => _sentence;
  Recording? get myRecording => _myRecording;
  WaveformData? get originalWaveform => _originalWaveform;
  WaveformData? get mineWaveform => _mineWaveform;

  Stream<FollowReadPhase> get phaseStream => _phaseController.stream;

  /// 开始跟读某句：加载并播放原声，进入播放原声态。
  Future<void> start(Sentence sentence) async {
    // 播放原声 / 录音中忽略重复 start，避免打断进行中的流程。
    if (_phase == FollowReadPhase.playingOriginal ||
        _phase == FollowReadPhase.recording) {
      return;
    }

    _sentence = sentence;
    _myRecording = null;
    _originalWaveform = null;
    _mineWaveform = null;
    _awaitOriginal = true;

    final String? audioPath = sentence.audioPath;
    if (audioPath != null && audioPath.isNotEmpty) {
      _originalWaveform = _extractWaveform(audioPath);
      _setPhase(FollowReadPhase.playingOriginal);
      await _player.load(_resolve(audioPath));
      await _player.setSpeed(AudioConstants.defaultSpeed);
      await _player.play();
    } else {
      // 无原声（正常数据不会出现）：跳过原声播放，直接进入录音态。
      _awaitOriginal = false;
      _setPhase(FollowReadPhase.recording);
    }
  }

  /// 原声播放完成回调：自动切到录音态。
  void onOriginalComplete() {
    if (_phase != FollowReadPhase.playingOriginal) return;
    _awaitOriginal = false;
    _setPhase(FollowReadPhase.recording);
  }

  /// 开始跟读录音（委托给注入的 [AudioRecorder]）。
  Future<void> startRecording() async {
    if (_phase != FollowReadPhase.recording) return;
    final AudioRecorder? recorder = _recorder;
    if (recorder == null) {
      throw const AudioEngineException('录音器未注入');
    }
    await recorder.start(source: RecordingSource.follow);
  }

  /// 停止录音并进入对比态，返回产生的录音。
  Future<Recording?> stopRecording() async {
    if (_phase != FollowReadPhase.recording) return null;
    final AudioRecorder? recorder = _recorder;
    if (recorder == null) {
      throw const AudioEngineException('录音器未注入');
    }
    final Recording recording = await recorder.stop();
    await attachRecording(recording);
    return recording;
  }

  /// 将已完成的录音挂载到会话（用于"按住说话"经 RecorderProvider 录制的路径）。
  Future<void> attachRecording(Recording recording) async {
    _myRecording = recording;
    _mineWaveform = _extractWaveform(recording.filePath);
    _awaitOriginal = false;
    _setPhase(FollowReadPhase.comparing);
  }

  /// 重新播放原声。
  Future<void> playOriginal() async {
    final Sentence? sentence = _sentence;
    if (sentence?.audioPath == null) return;
    await _player.load(_resolve(sentence!.audioPath!));
    await _player.seek(0);
    await _player.play();
  }

  /// 播放我的录音。
  Future<void> playMine() async {
    final Recording? recording = _myRecording;
    if (recording == null) return;
    await _player.load(_resolve(recording.filePath));
    await _player.seek(0);
    await _player.play();
  }

  /// 保存三维自评（自动关联当前录音 id）。
  Future<int?> saveEvaluation(SelfEvaluation evaluation) async {
    final Recording? recording = _myRecording;
    if (recording == null || recording.id == null) return null;
    final SelfEvaluation full = evaluation.copyWith(recordingId: recording.id!);
    final int? id = await _onSaveEvaluation?.call(full);
    if (id != null) _setPhase(FollowReadPhase.done);
    return id;
  }

  /// 标错 / 加入复习池。
  Future<int?> markReview() async {
    final ReviewItem item = ReviewItem(
      sentenceId: _sentence?.id,
      recordingId: _myRecording?.id,
      type: ReviewType.error.name,
      createdAt: DateTime.now(),
      nextReviewAt: DateTime.now(),
      intervalDays: 0,
      easeFactor: 2.5,
      repetitions: 0,
    );
    final int? id = await _onMarkReview?.call(item);
    if (id != null) _setPhase(FollowReadPhase.done);
    return id;
  }

  /// 重置回初始态。
  void reset() {
    _sentence = null;
    _myRecording = null;
    _originalWaveform = null;
    _mineWaveform = null;
    _awaitOriginal = false;
    _setPhase(FollowReadPhase.idle);
  }

  void _onPlayerCompleted() {
    if (_awaitOriginal && _phase == FollowReadPhase.playingOriginal) {
      onOriginalComplete();
    }
  }

  void _setPhase(FollowReadPhase phase) {
    if (_phase == phase) return;
    _phase = phase;
    if (!_phaseController.isClosed) _phaseController.add(phase);
  }

  String _resolve(String relativePath) => p.join(_documentsDirPath, relativePath);

  WaveformData _extractWaveform(String relativePath) {
    try {
      final String abs = _resolve(relativePath);
      final int sampleRate = _pcmReader.readHeader(abs).sampleRate;
      final Float64List samples = _pcmReader.readMono(abs);
      return _waveformExtractor.extract(samples, sampleRate);
    } catch (_) {
      return WaveformData.empty;
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
    if (!_phaseController.isClosed) await _phaseController.close();
  }
}
