/// 时间/时长格式化工具。
///
/// 全工程统一约定：时长与位置一律使用 int 毫秒，仅在显示层转换为文本。
class TimeFormatter {
  TimeFormatter._();

  /// 毫秒 -> `mm:ss`（不足一分钟显示 `0:xx`）。
  static String msToClock(int ms) {
    final int totalSeconds = (ms / 1000).floor();
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// 毫秒 -> `mm:ss.d`（带 0.1 秒精度，适合短音频复读场景）。
  static String msToClockWithTenths(int ms) {
    final int tenths = ((ms % 1000) / 100).floor();
    return '${msToClock(ms)}.$tenths';
  }

  /// 毫秒 -> 人类可读描述（如 `12.3s` / `1:02`），用于列表展示。
  static String msToHuman(int ms) {
    if (ms < 1000) return '${ms}ms';
    if (ms < 60 * 1000) return '${(ms / 1000).toStringAsFixed(1)}s';
    return msToClock(ms);
  }
}
