import 'package:just_audio/just_audio.dart';

import '../../core/constants/audio_constants.dart';

/// 播放控制器（封装 `just_audio`）。
///
/// - Android 走 ExoPlayer + Sonic，`setSpeed` 变速不变调；
/// - iOS 基于 AVPlayer.rate 会变调，M1 仅保证可编译，不变调留待 M2。
///
/// 纯 Dart 控制器，无 UI 依赖，可脱离 Widget 单测。
class AudioPlayerController {
  AudioPlayerController({AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  /// 加载本地文件（绝对路径）。
  Future<void> load(String path) => _player.setFilePath(path);

  Future<void> play() => _player.play();

  Future<void> pause() => _player.pause();

  Future<void> seek(int ms) =>
      _player.seek(Duration(milliseconds: ms < 0 ? 0 : ms));

  /// 变速不变调，内部统一 clamp 到 [AudioConstants.minSpeed, maxSpeed]。
  Future<void> setSpeed(double speed) => _player.setSpeed(
    speed.clamp(AudioConstants.minSpeed, AudioConstants.maxSpeed),
  );

  /// 设置播放区间（A/B 复读或单句裁剪）。
  Future<void> setClip(int startMs, int endMs) {
    if (startMs < 0 || endMs <= startMs) {
      return _player.setClip();
    }
    return _player.setClip(
      start: Duration(milliseconds: startMs),
      end: Duration(milliseconds: endMs),
    );
  }

  /// 清除播放区间。
  Future<void> clearClip() => _player.setClip();

  /// 当前位置流（int 毫秒）。
  Stream<int> get positionStream =>
      _player.positionStream.map((Duration d) => d.inMilliseconds);

  Stream<bool> get playingStream => _player.playingStream;

  /// 播放完成流（进入 ProcessingState.completed 时发射）。
  Stream<void> get completedStream => _player.processingStateStream
      .where((ProcessingState s) => s == ProcessingState.completed)
      .map<void>((_) {});

  Stream<Duration?> get durationStream => _player.durationStream;

  int get durationMs => _player.duration?.inMilliseconds ?? 0;

  Duration? get duration => _player.duration;

  Future<void> dispose() => _player.dispose();
}
