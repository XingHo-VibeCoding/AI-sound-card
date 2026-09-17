import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/review_item.dart';
import '../../models/sentence.dart';
import '../../state/providers.dart';
import '../../state/review_provider.dart';

/// 复习池页：按 nextReviewAt 升序展示标错/收藏条目，支持复习调度与删除。
class ReviewPoolScreen extends ConsumerStatefulWidget {
  const ReviewPoolScreen({super.key});

  @override
  ConsumerState<ReviewPoolScreen> createState() => _ReviewPoolScreenState();
}

class _ReviewPoolScreenState extends ConsumerState<ReviewPoolScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      ref.read(reviewProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ReviewState review = ref.watch(reviewProvider);
    final AsyncValue<List<Sentence>> sentences = ref.watch(sentencesProvider);

    final Map<int, String> textById = <int, String>{};
    sentences.whenData((List<Sentence> list) {
      for (final Sentence s in list) {
        if (s.id != null) textById[s.id!] = s.text;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('复习池')),
      body: review.loading
          ? const Center(child: CircularProgressIndicator())
          : review.items.isEmpty
              ? const Center(child: Text('复习池为空，去跟读对比页标错吧'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: review.items.length,
                  itemBuilder: (BuildContext context, int index) {
                    final ReviewItem item = review.items[index];
                    return _ReviewTile(
                      item: item,
                      sentenceText: item.sentenceId == null
                          ? null
                          : textById[item.sentenceId],
                    );
                  },
                ),
    );
  }
}

class _ReviewTile extends ConsumerWidget {
  const _ReviewTile({required this.item, this.sentenceText});

  final ReviewItem item;
  final String? sentenceText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReviewNotifier notifier = ref.read(reviewProvider.notifier);
    final String typeLabel = _typeLabel(item.type);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.flag),
        title: Text(sentenceText ?? typeLabel),
        subtitle: Text(
          '${typeLabel} · 已复习 ${item.repetitions} 次 · '
          '下次 ${item.nextReviewAt == null ? '现在' : DateFormat('MM-dd HH:mm').format(item.nextReviewAt!)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextButton(
              onPressed: () => notifier.review(item, remembered: true),
              child: const Text('会了'),
            ),
            TextButton(
              onPressed: () => notifier.review(item, remembered: false),
              child: const Text('又错了'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => notifier.remove(item.id!),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'favorite':
        return '收藏';
      case 'word':
        return '生词';
      case 'error':
      default:
        return '标错';
    }
  }
}
