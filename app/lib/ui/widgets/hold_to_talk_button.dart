import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_formatter.dart';
import '../../models/recording.dart';
import '../../state/recorder_provider.dart';

/// 按住说话按钮（`Listener` 原始指针事件 + 状态机）。
///
/// 按下即录、上滑取消、松开保存，`<1s` 丢弃在 RecorderProvider 层完成。
class HoldToTalkButton extends ConsumerStatefulWidget {
  const HoldToTalkButton({
    super.key,
    this.source = RecordingSource.practice,
    this.sentenceId,
    this.onRecorded,
    this.label = '按住说话',
  });

  final String source;
  final int? sentenceId;

  /// 录音保存成功后回调（携带落库后的 Recording）。
  final void Function(Recording recording)? onRecorded;
  final String label;

  @override
  ConsumerState<HoldToTalkButton> createState() => _HoldToTalkButtonState();
}

class _HoldToTalkButtonState extends ConsumerState<HoldToTalkButton> {
  static const double _cancelThreshold = 48.0;

  bool _pointerDown = false;
  bool _outOfBounds = false;

  void _handleDown(PointerDownEvent event) {
    _pointerDown = true;
    _outOfBounds = false;
    _start();
  }

  Future<void> _start() async {
    try {
      await ref.read(recorderProvider.notifier).startHoldToTalk(
            source: widget.source,
            sentenceId: widget.sentenceId,
          );
    } catch (_) {
      if (mounted) _showMessage('无法开始录音，请检查麦克风权限');
    }
  }

  void _handleMove(PointerMoveEvent event) {
    if (!_pointerDown) return;
    final Size? size = context.size;
    if (size == null) return;
    final Offset p = event.localPosition;
    final bool outside = p.dx < -_cancelThreshold ||
        p.dx > size.width + _cancelThreshold ||
        p.dy < -_cancelThreshold ||
        p.dy > size.height + _cancelThreshold;
    if (outside) {
      _outOfBounds = true;
      ref.read(recorderProvider.notifier).markWillCancel();
    } else if (_outOfBounds) {
      _outOfBounds = false;
      ref.read(recorderProvider.notifier).clearWillCancel();
    }
  }

  Future<void> _handleUp(PointerUpEvent event) async {
    if (!_pointerDown) return;
    _pointerDown = false;
    if (_outOfBounds) {
      _outOfBounds = false;
      await ref.read(recorderProvider.notifier).cancelHoldToTalk();
      return;
    }
    final Recording? rec = await ref
        .read(recorderProvider.notifier)
        .stopHoldToTalk();
    if (rec != null) {
      widget.onRecorded?.call(rec);
    }
  }

  void _handleCancel(PointerCancelEvent event) {
    if (!_pointerDown) return;
    _pointerDown = false;
    _outOfBounds = false;
    ref.read(recorderProvider.notifier).cancelHoldToTalk();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final RecorderState state = ref.watch(recorderProvider);

    // 一次性提示（如"录音太短，已丢弃"）。
    ref.listen(recorderProvider, (RecorderState? prev, RecorderState next) {
      if (next.messageSeq != prev?.messageSeq && next.message != null) {
        _showMessage(next.message!);
      }
    });

    final bool recording =
        _pointerDown && state.phase != RecorderPhase.idle;
    final bool willCancel = recording && _outOfBounds;

    Color background = AppColors.accent;
    String label = widget.label;
    if (willCancel) {
      background = AppColors.danger;
      label = '松开取消';
    } else if (recording) {
      background = AppColors.accent.withOpacity(0.85);
      label =
          '${TimeFormatter.msToClockWithTenths(state.elapsedMs)} · 松开结束';
    }

    return Listener(
      onPointerDown: _handleDown,
      onPointerMove: _handleMove,
      onPointerUp: _handleUp,
      onPointerCancel: _handleCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
