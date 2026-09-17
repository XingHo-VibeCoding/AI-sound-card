import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/follow_read/follow_read_session.dart';
import '../models/recording.dart';
import '../models/self_evaluation.dart';
import '../models/sentence.dart';
import '../models/waveform_data.dart';
import 'providers.dart';
import 'recorder_provider.dart';

/// 跟读对比状态。
class FollowReadState {
  const FollowReadState({
    this.phase = FollowReadPhase.idle,
    this.sentence,
    this.myRecording,
    this.originalWaveform,
    this.mineWaveform,
    this.busy = false,
  });

  final FollowReadPhase phase;
  final Sentence? sentence;
  final Recording? myRecording;
  final WaveformData? originalWaveform;
  final WaveformData? mineWaveform;
  final bool busy;

  FollowReadState copyWith({
    FollowReadPhase? phase,
    Sentence? sentence,
    Recording? myRecording,
    WaveformData? originalWaveform,
    WaveformData? mineWaveform,
    bool? busy,
  }) {
    return FollowReadState(
      phase: phase ?? this.phase,
      sentence: sentence ?? this.sentence,
      myRecording: myRecording ?? this.myRecording,
      originalWaveform: originalWaveform ?? this.originalWaveform,
      mineWaveform: mineWaveform ?? this.mineWaveform,
      busy: busy ?? this.busy,
    );
  }
}

/// 跟读对比 Provider：装配会话状态机并暴露状态。
class FollowReadNotifier extends Notifier<FollowReadState> {
  FollowReadSession? _session;
  StreamSubscription<FollowReadPhase>? _sub;

  @override
  FollowReadState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _session?.dispose();
    });
    return const FollowReadState();
  }

  Future<FollowReadSession> _ensureSession() async {
    final FollowReadSession? existing = _session;
    if (existing != null) return existing;

    final String docs = await ref.read(documentsDirPathProvider.future);
    final FollowReadSession session = FollowReadSession(
      documentsDirPath: docs,
      pcmReader: ref.read(pcmReaderProvider),
      waveformExtractor: ref.read(waveformExtractorProvider),
      recorder: await ref.read(audioRecorderProvider.future),
      onSaveEvaluation: (SelfEvaluation e) =>
          ref.read(evaluationRepositoryProvider).insert(e),
      onMarkReview: (item) => ref.read(reviewRepositoryProvider).insert(item),
    );
    _sub = session.phaseStream.listen((_) => _sync(session));
    _session = session;
    return session;
  }

  void _sync(FollowReadSession session) {
    state = FollowReadState(
      phase: session.phase,
      sentence: session.sentence,
      myRecording: session.myRecording,
      originalWaveform: session.originalWaveform,
      mineWaveform: session.mineWaveform,
    );
  }

  Future<void> start(Sentence sentence) async {
    final FollowReadSession session = await _ensureSession();
    await session.start(sentence);
    _sync(session);
  }

  Future<void> startRecording() async {
    await (await _ensureSession()).startRecording();
  }

  Future<Recording?> stopRecording() async {
    final FollowReadSession session = await _ensureSession();
    final Recording? rec = await session.stopRecording();
    _sync(session);
    return rec;
  }

  Future<void> attachRecording(Recording recording) async {
    final FollowReadSession session = await _ensureSession();
    await session.attachRecording(recording);
    _sync(session);
  }

  Future<void> playOriginal() async {
    await (await _ensureSession()).playOriginal();
  }

  Future<void> playMine() async {
    await (await _ensureSession()).playMine();
  }

  Future<int?> saveEvaluation(SelfEvaluation evaluation) async {
    final FollowReadSession session = await _ensureSession();
    final int? id = await session.saveEvaluation(evaluation);
    _sync(session);
    return id;
  }

  Future<int?> markReview() async {
    final FollowReadSession session = await _ensureSession();
    final int? id = await session.markReview();
    _sync(session);
    return id;
  }

  void reset() {
    _session?.reset();
    final FollowReadSession? session = _session;
    if (session != null) _sync(session);
  }
}

final followReadProvider = NotifierProvider<FollowReadNotifier, FollowReadState>(
  FollowReadNotifier.new,
);
