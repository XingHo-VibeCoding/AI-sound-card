import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/review_item.dart';
import 'providers.dart';

/// 复习池状态。
class ReviewState {
  const ReviewState({this.items = const <ReviewItem>[], this.loading = false});

  final List<ReviewItem> items;
  final bool loading;

  ReviewState copyWith({List<ReviewItem>? items, bool? loading}) {
    return ReviewState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
    );
  }
}

/// 复习池 Provider：加载/标记/复习调度/删除。
class ReviewNotifier extends Notifier<ReviewState> {
  @override
  ReviewState build() => const ReviewState();

  Future<void> load() async {
    state = state.copyWith(loading: true);
    final List<ReviewItem> all = await ref
        .read(reviewRepositoryProvider)
        .listAll();
    state = ReviewState(items: all);
  }

  /// 加入复习池（标错 / 收藏）。
  Future<int> markReview({
    int? sentenceId,
    int? recordingId,
    ReviewType type = ReviewType.error,
  }) async {
    final DateTime now = DateTime.now();
    final int id = await ref.read(reviewRepositoryProvider).insert(
      ReviewItem(
        sentenceId: sentenceId,
        recordingId: recordingId,
        type: type.name,
        createdAt: now,
        nextReviewAt: now,
        intervalDays: 0,
        easeFactor: 2.5,
        repetitions: 0,
      ),
    );
    await load();
    return id;
  }

  /// 复习结果调度（简化的间隔重复）。
  Future<void> review(ReviewItem item, {required bool remembered}) async {
    final DateTime now = DateTime.now();
    ReviewItem next;
    if (remembered) {
      final int interval = item.intervalDays == 0
          ? 1
          : math.max(1, (item.intervalDays * item.easeFactor).round());
      next = item.copyWith(
        intervalDays: interval,
        repetitions: item.repetitions + 1,
        easeFactor: (item.easeFactor + 0.1).clamp(1.3, 3.0).toDouble(),
        nextReviewAt: now.add(Duration(days: interval)),
      );
    } else {
      next = item.copyWith(
        intervalDays: 0,
        repetitions: item.repetitions + 1,
        nextReviewAt: now,
      );
    }
    await ref.read(reviewRepositoryProvider).update(next);
    await load();
  }

  Future<void> remove(int id) async {
    await ref.read(reviewRepositoryProvider).delete(id);
    await load();
  }
}

final reviewProvider = NotifierProvider<ReviewNotifier, ReviewState>(
  ReviewNotifier.new,
);
