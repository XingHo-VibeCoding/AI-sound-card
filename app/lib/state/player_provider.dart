import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/audio_constants.dart';
import '../engine/ab_loop/ab_loop_controller.dart';
import '../engine/audio/audio_player_controller.dart';

/// 播放状态。
class PlayerState {
  const PlayerState({
    this.isLoaded = false,
    this.isPlaying = false,
    this.positionMs = 0,
    this.durationMs = 0,
    this.speed = AudioConstants.defaultSpeed,
    this.clipStartMs,
    this.clipEndMs,
    this.loopPointA,
    this.loopPointB,
    this.repeatCount = AudioConstants.abLoopDefaultRepeatCount,
    this.intervalMs = AudioConstants.abLoopDefaultIntervalMs,
    this.loopActive = false,
    this.currentPath,
  });

  final bool isLoaded;
  final bool isPlaying;
  final int positionMs;
  final int durationMs;
  final double speed;
  final int? clipStartMs;
  final int? clipEndMs;
  final int? loopPointA;
  final int? loopPointB;
  final int repeatCount;
  final int intervalMs;
  final bool loopActive;
  final String? currentPath;

  PlayerState copyWith({
    bool? isLoaded,
    bool? isPlaying,
    int? positionMs,
    int? durationMs,
    double? speed,
    Object? clipStartMs = _unset,
    Object? clipEndMs = _unset,
    Object? loopPointA = _unset,
    Object? loopPointB = _unset,
    int? repeatCount,
    int? intervalMs,
    bool? loopActive,
    Object? currentPath = _unset,
  }) {
    return PlayerState(
      isLoaded: isLoaded ?? this.isLoaded,
      isPlaying: isPlaying ?? this.isPlaying,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      speed: speed ?? this.speed,
      clipStartMs: identical(clipStartMs, _unset)
          ? this.clipStartMs
          : clipStartMs as int?,
      clipEndMs: identical(clipEndMs, _unset)
          ? this.clipEndMs
          : clipEndMs as int?,
      loopPointA: identical(loopPointA, _unset)
          ? this.loopPointA
          : loopPointA as int?,
      loopPointB: identical(loopPointB, _unset)
          ? this.loopPointB
          : loopPointB as int?,
      repeatCount: repeatCount ?? this.repeatCount,
      intervalMs: intervalMs ?? this.intervalMs,
      loopActive: loopActive ?? this.loopActive,
      currentPath: identical(currentPath, _unset)
          ? this.currentPath
          : currentPath as String?,
    );
  }

  static const Object _unset = Object();
}

/// 全局唯一播放控制器（练习页播放/变速/AB 复读共用）。
final audioPlayerControllerProvider = Provider<AudioPlayerController>((ref) {
  final AudioPlayerController controller = AudioPlayerController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// AB 复读控制器（驱动 [audioPlayerControllerProvider]）。
final abLoopControllerProvider = Provider<AbLoopController>((ref) {
  final AbLoopController loop = AbLoopController(
    ref.watch(audioPlayerControllerProvider),
  );
  ref.onDispose(loop.dispose);
  return loop;
});

/// 播放 Provider：装配播放器与 AB 循环，暴露状态流与操作。
class PlayerNotifier extends Notifier<PlayerState> {
  final List<StreamSubscription<dynamic>> _subs = <StreamSubscription<dynamic>>[];

  AudioPlayerController get _player => ref.read(audioPlayerControllerProvider);
  AbLoopController get _loop => ref.read(abLoopControllerProvider);

  @override
  PlayerState build() {
    _subs.add(_player.positionStream.listen((int ms) {
      state = state.copyWith(
        positionMs: ms,
        durationMs: state.durationMs > 0
            ? state.durationMs
            : _player.durationMs,
      );
    }));
    _subs.add(_player.playingStream.listen((bool playing) {
      state = state.copyWith(isPlaying: playing);
    }));
    _subs.add(_player.durationStream.listen((Duration? d) {
      if (d != null) state = state.copyWith(durationMs: d.inMilliseconds);
    }));
    _subs.add(_loop.changes.listen((_) {
      state = state.copyWith(
        loopPointA: _loop.pointA,
        loopPointB: _loop.pointB,
        repeatCount: _loop.repeatCount,
        intervalMs: _loop.intervalMs,
        loopActive: _loop.isActive,
      );
    }));
    ref.onDispose(() {
      for (final StreamSubscription<dynamic> s in _subs) {
        s.cancel();
      }
    });
    return const PlayerState();
  }

  /// 加载本地文件（绝对路径）。
  Future<void> load(String absolutePath) async {
    await _player.load(absolutePath);
    state = state.copyWith(
      isLoaded: true,
      currentPath: absolutePath,
      durationMs: _player.durationMs,
      positionMs: 0,
    );
  }

  Future<void> play() async {
    await _player.play();
    state = state.copyWith(isPlaying: true);
  }

  Future<void> pause() async {
    await _player.pause();
    state = state.copyWith(isPlaying: false);
  }

  Future<void> togglePlay() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(int ms) async {
    final int target = ms.clamp(0, state.durationMs);
    await _player.seek(target);
    state = state.copyWith(positionMs: target);
  }

  Future<void> setSpeed(double speed) async {
    final double clamped = speed.clamp(
      AudioConstants.minSpeed,
      AudioConstants.maxSpeed,
    );
    await _player.setSpeed(clamped);
    state = state.copyWith(speed: clamped);
  }

  Future<void> setClip(int startMs, int endMs) async {
    await _player.setClip(startMs, endMs);
    state = state.copyWith(clipStartMs: startMs, clipEndMs: endMs);
  }

  Future<void> clearClip() async {
    await _player.clearClip();
    state = state.copyWith(clipStartMs: null, clipEndMs: null);
  }

  void setLoopPointA(int ms) => _loop.setPointA(ms);

  void setLoopPointB(int ms) => _loop.setPointB(ms);

  void clearAbLoop() => _loop.clear();

  void setRepeatCount(int n) => _loop.setRepeatCount(n);

  void setInterval(int ms) => _loop.setInterval(ms);
}

final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);
