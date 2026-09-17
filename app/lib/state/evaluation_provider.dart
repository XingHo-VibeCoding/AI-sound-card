import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/self_evaluation.dart';
import 'providers.dart';

/// 自评状态。
class EvaluationState {
  const EvaluationState({
    this.evaluations = const <SelfEvaluation>[],
    this.loading = false,
  });

  final List<SelfEvaluation> evaluations;
  final bool loading;

  EvaluationState copyWith({List<SelfEvaluation>? evaluations, bool? loading}) {
    return EvaluationState(
      evaluations: evaluations ?? this.evaluations,
      loading: loading ?? this.loading,
    );
  }
}

/// 自评 Provider：加载某录音的自评 / 保存自评。
class EvaluationNotifier extends Notifier<EvaluationState> {
  @override
  EvaluationState build() => const EvaluationState();

  Future<void> loadForRecording(int recordingId) async {
    state = state.copyWith(loading: true);
    final List<SelfEvaluation> list = await ref
        .read(evaluationRepositoryProvider)
        .byRecording(recordingId);
    state = EvaluationState(evaluations: list);
  }

  /// 加载全部自评（录音列表页聚合展示）。
  Future<void> loadAll() async {
    state = state.copyWith(loading: true);
    final List<SelfEvaluation> list = await ref
        .read(evaluationRepositoryProvider)
        .listAll();
    state = EvaluationState(evaluations: list);
  }

  Future<int> save(SelfEvaluation evaluation) async {
    final int id = await ref
        .read(evaluationRepositoryProvider)
        .insert(evaluation);
    await loadForRecording(evaluation.recordingId);
    return id;
  }

  /// 返回某录音的最新一次自评（无则 null）。
  SelfEvaluation? latestOf(int recordingId) {
    for (final SelfEvaluation e in state.evaluations) {
      if (e.recordingId == recordingId) return e;
    }
    return null;
  }
}

final evaluationProvider = NotifierProvider<EvaluationNotifier, EvaluationState>(
  EvaluationNotifier.new,
);
