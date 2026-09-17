import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/constants/audio_constants.dart';
import '../core/error/app_exception.dart';
import '../engine/audio/audio_recorder.dart';
import '../models/recording.dart';
import '../models/waveform_data.dart';
import 'providers.dart';
import 'waveform_provider.dart';

/// 录音交互阶段。
enum RecorderPhase { idle, recording, willCancel }

/// 录音状态。
class RecorderState {
  const RecorderState({
    this.phase = RecorderPhase.idle,
    this.elapsedMs = 0,
    this.amplitude = 0,
    this.lastRecording,
    this.message,
    this.messageSeq = 0,
    this.isBusy = false,
  });

  final RecorderPhase phase;
  final int elapsedMs;
  final int amplitude;
  final Recording? lastRecording;

  /// 一次性提示（如"录音太短，已丢弃"），配合 [messageSeq] 触发 SnackBar。
  final String? message;
  final int messageSeq;
  final bool isBusy;

  RecorderState copyWith({
    RecorderPhase? phase,
    int? elapsedMs,
    int? amplitude,
    Recording? lastRecording,
    String? message,
    int? messageSeq,
    bool? isBusy,
  }) {
    return RecorderState(
      phase: phase ?? this.phase,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      amplitude: amplitude ?? this.amplitude,
      lastRecording: lastRecording ?? this.lastRecording,
      message: message ?? this.message,
      messageSeq: messageSeq ?? this.messageSeq,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

/// 全局唯一录音器（按住说话与点击切换共用）。
///
/// 录音输出目录需异步获取，故用 [FutureProvider]；消费方统一
/// `await ...future` 后再使用 [AudioRecorder]。
final audioRecorderProvider = FutureProvider<AudioRecorder>((ref) async {
  final Directory dir = await ref.watch(recordingsDirectoryProvider.future);
  final AudioRecorder recorder = AudioRecorder(recordingsDirectory: dir);
  ref.onDispose(recorder.dispose);
  return recorder;
});

/// 录音交互 Provider。
///
/// 职责：申请权限、开始/停止/取消、`<1s` 丢弃（仅此一处做校验）、
/// 落库、异步抽取并回写波形。
class RecorderNotifier extends Notifier<RecorderState> {
  StreamSubscription<int>? _ampSub;
  Timer? _ticker;

  Future<AudioRecorder> get _recorder => ref.read(audioRecorderProvider.future);

  @override
  RecorderState build() {
    ref.onDispose(() {
      _ampSub?.cancel();
      _ticker?.cancel();
    });
    return const RecorderState();
  }

  /// 申请麦克风权限，返回是否已授权。
  Future<bool> ensurePermission() async {
    final PermissionStatus status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> _start({
    String source = RecordingSource.practice,
    int? sentenceId,
  }) async {
    final bool ok = await ensurePermission();
    if (!ok) throw const PermissionDeniedException();
    final AudioRecorder recorder = await _recorder;
    await recorder.start(source: source, sentenceId: sentenceId);
    state = const RecorderState(phase: RecorderPhase.recording);
    _startTicker(recorder);
  }

  Future<void> startHoldToTalk({
    String source = RecordingSource.practice,
    int? sentenceId,
  }) {
    return _start(source: source, sentenceId: sentenceId);
  }

  Future<void> startToggle({
    String source = RecordingSource.practice,
    int? sentenceId,
  }) {
    return _start(source: source, sentenceId: sentenceId);
  }

  /// 上滑取消态。
  void markWillCancel() {
    if (state.phase == RecorderPhase.recording) {
      state = state.copyWith(phase: RecorderPhase.willCancel);
    }
  }

  /// 滑回按钮内，恢复录音态。
  void clearWillCancel() {
    if (state.phase == RecorderPhase.willCancel) {
      state = state.copyWith(phase: RecorderPhase.recording);
    }
  }

  Future<Recording?> stopHoldToTalk() => _stop();
  Future<Recording?> stopToggle() => _stop();

  Future<Recording?> _stop() async {
    _stopTicker();
    final RecorderPhase phase = state.phase;
    if (phase != RecorderPhase.recording &&
        phase != RecorderPhase.willCancel) {
      return null;
    }
    state = state.copyWith(isBusy: true);
    try {
      final AudioRecorder recorder = await _recorder;
      final Recording rec = await recorder.stop();
      if (rec.durationMs < AudioConstants.minValidDurationMs) {
        await recorder.deleteLastFile();
        state = RecorderState(
          message: '录音太短，已丢弃',
          messageSeq: state.messageSeq + 1,
        );
        return null;
      }
      final int id = await ref.read(recordingRepositoryProvider).insert(rec);
      final Recording saved = rec.copyWith(id: id);
      state = RecorderState(lastRecording: saved);
      unawaited(_extractAndPersistWaveform(saved, recorder));
      return saved;
    } catch (_) {
      state = RecorderState(
        message: '录音失败，请重试',
        messageSeq: state.messageSeq + 1,
      );
      return null;
    }
  }

  Future<void> cancelHoldToTalk() => _cancel();
  Future<void> cancelToggle() => _cancel();

  Future<void> _cancel() async {
    _stopTicker();
    final AudioRecorder recorder = await _recorder;
    await recorder.cancel();
    state = const RecorderState();
  }

  void _startTicker(AudioRecorder recorder) {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (state.phase == RecorderPhase.recording) {
        state = state.copyWith(elapsedMs: state.elapsedMs + 100);
      }
    });
    _ampSub?.cancel();
    _ampSub = recorder.amplitudeStream.listen((int v) {
      if (state.phase == RecorderPhase.recording) {
        state = state.copyWith(amplitude: v);
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _ampSub?.cancel();
    _ampSub = null;
  }

  Future<void> _extractAndPersistWaveform(
    Recording rec,
    AudioRecorder recorder,
  ) async {
    try {
      final String? abs = recorder.lastAbsolutePath;
      if (abs == null) return;
      final WaveformData wf = ref
          .read(waveformServiceProvider)
          .extractFromFile(abs);
      final Recording updated = rec.copyWith(waveformJson: wf.toJsonString());
      await ref.read(recordingRepositoryProvider).update(updated);
    } catch (_) {
      // 波形抽取失败不阻断录音主流程。
    }
  }
}

final recorderProvider = NotifierProvider<RecorderNotifier, RecorderState>(
  RecorderNotifier.new,
);
