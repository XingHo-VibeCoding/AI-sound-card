import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// 应用入口。
///
/// 先确保 Flutter 引擎绑定完成（供 path_provider / sqflite / just_audio 等
/// 插件在 main 阶段安全调用），再挂载 [ProviderScope] 提供全局依赖。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: App()));
}
