import 'package:flutter/material.dart';

/// 全局配色常量。
class AppColors {
  AppColors._();

  /// 主色（青绿，代表"录音卡"品牌）。
  static const Color primary = Color(0xFF2E7D6B);

  /// 强调色（橙，用于录音/跟读等关键动作）。
  static const Color accent = Color(0xFFF57C00);

  /// 原声波形颜色（蓝）。
  static const Color originalWave = Color(0xFF4A90D9);

  /// 我的录音波形颜色（橙，半透明叠加）。
  static const Color mineWave = Color(0xFFF57C00);

  /// 错误 / 取消态颜色（红）。
  static const Color danger = Color(0xFFE53935);

  /// 静音/背景灰。
  static const Color surfaceMuted = Color(0xFFF1F3F4);
}

/// 应用主题。
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFFAFBFC),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1F2933),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      sliderTheme: const SliderThemeData(
        showValueIndicator: ShowValueIndicator.always,
      ),
    );
  }
}
