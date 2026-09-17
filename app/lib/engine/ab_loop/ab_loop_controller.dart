import 'dart:async';

import '../audio/audio_player_controller.dart';

/// AB 区间循环控制器。
///
/// 驱动 [AudioPlayerController]：当播放位置越过 B 点时回跳到 A 点，
/// 支持重复次数（回跳次数：N 次回跳 = N+1 次完整播放，0=无限循环）
/// 与两次循环间间隔。纯 Dart，无 UI 依赖。
class AbLoopController {
  AbLoopController(this._player);

  final AudioPlayerController _player;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  StreamSubscription<int>? _sub;

  int? _pointA;
  int? _pointB;
  int _repeatCount = 0;
  int _intervalMs = 0;
  int _remaining = -1;
  bool _active = false;

  int? get pointA => _pointA;
  int? get pointB => _pointB;
  int get repeatCount => _repeatCount;
  int get intervalMs => _intervalMs;

  /// 是否已建立有效 A/B 区间。
  bool get hasRange =>
      _pointA != null && _pointB != null && _pointB! > _pointA!;

  /// 循环是否处于"已武装"状态（播放到 B 点会回跳）。
  bool get isActive => _active;

  /// 状态变化流（A/B/重复次数/间隔变化时发射）。
  Stream<void> get changes => _changes.stream;

  void setPointA(int ms) {
    _pointA = ms.clamp(0, _player.durationMs);
    _normalize();
    _armIfReady();
    _emit();
  }

  void setPointB(int ms) {
    _pointB = ms.clamp(0, _player.durationMs);
    _normalize();
    _armIfReady();
    _emit();
  }

  void clear() {
    _pointA = null;
    _pointB = null;
    _stop();
    _emit();
  }

  void setRepeatCount(int n) {
    _repeatCount = n < 0 ? 0 : n;
    _remaining = _repeatCount == 0 ? -1 : _repeatCount;
    _emit();
  }

  void setInterval(int ms) {
    _intervalMs = ms < 0 ? 0 : ms;
    _emit();
  }

  void _normalize() {
    if (_pointA != null && _pointB != null && _pointB! < _pointA!) {
      final int t = _pointA!;
      _pointA = _pointB;
      _pointB = t;
    }
  }

  void _armIfReady() {
    if (!hasRange) return;
    _remaining = _repeatCount == 0 ? -1 : _repeatCount;
    if (_sub == null) {
      _sub = _player.positionStream.listen(_onPosition);
    }
    _active = true;
  }

  void _onPosition(int ms) {
    if (!_active || !hasRange) return;
    if (ms >= _pointB!) {
      // 0=无限循环；否则 _remaining 表示"剩余回跳次数"。
      // 先判定是否还有回跳额度，再回跳，保证 repeatCount=N 对应 N 次回跳
      //（即共 N+1 次完整播放）。
      if (_repeatCount > 0) {
        if (_remaining <= 0) {
          _stop();
          _emit();
          return;
        }
        _remaining--;
      }
      _loopOnce();
    }
  }

  void _loopOnce() {
    if (_intervalMs > 0) {
      _player.pause();
      Future<void>.delayed(Duration(milliseconds: _intervalMs), () {
        if (_active) {
          _player.seek(_pointA!);
          _player.play();
        }
      });
    } else {
      _player.seek(_pointA!);
      _player.play();
    }
  }

  void _stop() {
    _active = false;
    _sub?.cancel();
    _sub = null;
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void dispose() {
    _stop();
    _changes.close();
  }
}
