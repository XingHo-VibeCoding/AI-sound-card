import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/time_formatter.dart';
import '../../models/sentence.dart';
import '../../state/providers.dart';

/// 首页：示例句子列表 + 录音列表 / 复习池入口。
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Sentence>> sentences = ref.watch(sentencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      body: sentences.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(child: Text('加载失败: $e')),
        data: (List<Sentence> list) => ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text('示例句子', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final Sentence s in list) _SentenceCard(sentence: s),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _NavCard(
                    icon: Icons.library_music,
                    title: '录音列表',
                    subtitle: '查看历史录音',
                    onTap: () => context.push(AppRoutes.recordings),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NavCard(
                    icon: Icons.flag,
                    title: '复习池',
                    subtitle: '标错/收藏复习',
                    onTap: () => context.push(AppRoutes.review),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SentenceCard extends StatelessWidget {
  const _SentenceCard({required this.sentence});

  final Sentence sentence;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(sentence.text),
        subtitle: Text(
          [
            if (sentence.phonetic != null) sentence.phonetic!,
            if (sentence.translation != null) sentence.translation!,
            TimeFormatter.msToHuman(sentence.durationMs),
          ].join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              tooltip: '复读机练习',
              icon: const Icon(Icons.headphones),
              onPressed: () => context.push(
                '${AppRoutes.practice}?sentenceId=${sentence.id}',
              ),
            ),
            IconButton(
              tooltip: '跟读对比',
              icon: const Icon(Icons.compare_arrows),
              onPressed: () => context.push(
                '${AppRoutes.compare}?sentenceId=${sentence.id}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 32),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
