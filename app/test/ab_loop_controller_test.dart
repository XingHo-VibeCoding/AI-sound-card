import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:recording_card_app/engine/ab_loop/ab_loop_controller.dart';
import 'package:recording_card_app/engine/audio/audio_player_controller.dart';

/// 用子类替换底层 [AudioPlayerController] 的播放行为，避免依赖 just_audio
/// 平台通道。super 构造会实例化一个真实的 just_audio `AudioPlayer`，因此需要
/// 已初始化的 Flutter binding（`TestWidgetsFlutterBinding.ensureInitialized()`）。
///
/// 若运行环境连 `AudioPlayer()` 构造都会抛 MissingPluginException，请改用
/// `just_audio_platform_interface` 的 Mock 注入 `AudioPlayerController(player:)`。
class _FakePlayer extends AudioPlayerController {
  _FakePlayer() : super();

  final StreamController<int> _positions =
      StreamController<int>.broadcast(sync: true);
  final List<String> log = <String>[];
  int _duration = 10000;

  @override
  int get durationMs => _duration;

  @override
  Stream<int> get positionStream => _positions.stream;

  @override
  Future<void> seek(int ms) async {
    log.add('seek:$ms');
    _positions.add(ms);
  }

  @override
  Future<void> play() async {
    log.add('play');
  }

  @override
  Future<void> pause() async {
    log.add('pause');
  }

  void emit(int ms) => _positions.add(ms);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('未设 B 时区间无效且未武装', () {
    final _FakePlayer player = _FakePlayer();
    final AbLoopController loop = AbLoopController(player);
    loop.setPointA(1000);
    expect(loop.hasRange, isFalse);
    expect(loop.isActive, isFalse);
    loop.dispose();
  });

  test('设置 A/B 后区间生效并自动武装', () {
    final _FakePlayer player = _FakePlayer();
    final AbLoopController loop = AbLoopController(player);
    loop.setPointA(1000);
    loop.setPointB(2000);
    expect(loop.hasRange, isTrue);
    expect(loop.isActive, isTrue);
    loop.dispose();
  });

  test('B < A 时自动交换两点', () {
    final _FakePlayer player = _FakePlayer();
    final AbLoopController loop = AbLoopController(player);
    loop.setPointA(3000);
    loop.setPointB(1000);
    expect(loop.hasRange, isTrue);
    expect(loop.pointA, 1000);
    expect(loop.pointB, 3000);
    loop.dispose();
  });

  test('越过 B 点回跳到 A 点并继续播放', () {
    final _FakePlayer player = _FakePlayer();
    final AbLoopController loop = AbLoopController(player);
    loop.setPointA(1000);
    loop.setPointB(2000);
    player.emit(2500);
    expect(player.log, contains('seek:1000'));
    expect(player.log, contains('play'));
    loop.dispose();
  });

  test('repeatCount=0 无限循环', () {
    final _FakePlayer player = _FakePlayer();
    final AbLoopController loop = AbLoopController(player);
    loop.setPointA(1000);
    loop.setPointB(2000);
    loop.setRepeatCount(0);
    player.emit(2100);
    player.emit(2100);
    player.emit(2100);
    expect(loop.isActive, isTrue);
    expect(player.log.where((String e) => e == 'seek:1000').length, 3);
    loop.dispose();
  });

  test('有限 repeatCount 回跳 N 次后停止（N=2，共 3 次播放）', () {
    final _FakePlayer player = _FakePlayer();
    final AbLoopController loop = AbLoopController(player);
    loop.setPointA(1000);
    loop.setPointB(2000);
    loop.setRepeatCount(2);
    player.emit(2100); // 第 1 次越过 B → 回跳（剩余 1 次）
    expect(loop.isActive, isTrue);
    player.emit(2100); // 第 2 次越过 B → 回跳（剩余 0 次）
    expect(loop.isActive, isTrue);
    expect(player.log.where((String e) => e == 'seek:1000').length, 2);
    player.emit(2100); // 第 3 次越过 B → 额度耗尽，停止
    expect(loop.isActive, isFalse);
    expect(player.log.where((String e) => e == 'seek:1000').length, 2);
    loop.dispose();
  });

  test('clear 清除区间并停止循环', () {
    final _FakePlayer player = _FakePlayer();
    final AbLoopController loop = AbLoopController(player);
    loop.setPointA(1000);
    loop.setPointB(2000);
    loop.clear();
    expect(loop.hasRange, isFalse);
    expect(loop.isActive, isFalse);
    expect(loop.pointA, isNull);
    expect(loop.pointB, isNull);
    loop.dispose();
  });

  test('interval > 0 时先暂停再延迟回跳', () async {
    final _FakePlayer player = _FakePlayer();
    final AbLoopController loop = AbLoopController(player);
    loop.setPointA(1000);
    loop.setPointB(2000);
    loop.setInterval(20);
    player.emit(2100);
    expect(player.log, contains('pause'));
    expect(player.log, isNot(contains('seek:1000'))); // 尚未回跳
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(player.log, contains('seek:1000'));
    expect(player.log, contains('play'));
    loop.dispose();
  });
}
