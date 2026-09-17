import 'dart:typed_data';

import '../../models/f0_point.dart';

/// 基频（F0）提取接口。
///
/// M1 仅定义数据结构与接口占位，算法（YIN/自相关）在 M5 实现。
abstract class F0Extractor {
  Future<List<F0Point>> extract(Float64List samples, int sampleRate);
}

/// M1 占位实现：返回空表，保证调用不崩溃、不阻塞主流程。
///
/// M5 接入真实算法时只需实现 [F0Extractor] 并替换注入即可。
class PlaceholderF0Extractor implements F0Extractor {
  const PlaceholderF0Extractor();

  @override
  Future<List<F0Point>> extract(Float64List samples, int sampleRate) async {
    return const <F0Point>[];
  }
}
