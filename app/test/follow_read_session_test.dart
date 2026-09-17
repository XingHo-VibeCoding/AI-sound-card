import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recording_card_app/engine/follow_read/follow_read_session.dart';
import 'package:recording_card_app/models/recording.dart';
import 'package:recording_card_app/models/review_item.dart';
import 'package:recording_card_app/models/self_evaluation.dart';
import 'package:recording_card_app/models/sentence.dart';

/// 构造一个 PCM16 单声道 44.1kHz 的 WAV 字节流。
Uint8List _pcm16Wav(List<int> samples) {
  final int dataSize = samples.length * 2;
  final ByteData bd = ByteData(44 + dataSize);
  void ascii(int off, String s) {
    for (int i = 0; i < s.length; i++) {
      bd.setUint8(off + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bd.setUint32(4, 36 + dataSize, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bd.setUint32(16, 16, Endian.little);
  bd.setUint16(20, 1, Endian.little);
  bd.setUint16(22, 1, Endian.little);
  bd.setUint32(24, 44100, Endian.little);
  bd.setUint32(28, 88200, Endian.little);
  bd.setUint16(32, 2, Endian.little);
  bd.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bd.setUint32(40, dataSize, Endian.little);
  for (int i = 0; i < samples.length; i++) {
    bd.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return bd.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('follow_read_test');
    // 100ms 的 PCM16 单声道 44.1kHz WAV（4410 样本）
    File('${tmp.path}/rec.wav')
        .writeAsBytesSync(_pcm16Wav(List<int>.filled(4410, 3000)));
  });

  tearDownAll(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('attachRecording 进入 comparing 并抽取波形', () async {
    final FollowReadSession session =
        FollowReadSession(documentsDirPath: tmp.path);
    addTearDown(() async {
      try {
        await session.dispose();
      } catch (_) {}
    });

    final Recording rec = Recording(
      id: 42,
      filePath: 'rec.wav',
      createdAt: DateTime.now(),
    );
    await session.attachRecording(rec);
    expect(session.phase, FollowReadPhase.comparing);
    expect(session.myRecording?.id, 42);
    expect(session.mineWaveform?.isEmpty, isFalse);
  });

  test('saveEvaluation 关联录音 id 并进入 done', () async {
    int? receivedRecordingId;
    final FollowReadSession session = FollowReadSession(
      documentsDirPath: tmp.path,
      onSaveEvaluation: (SelfEvaluation e) async {
        receivedRecordingId = e.recordingId;
        return 99;
      },
    );
    addTearDown(() async {
      try {
        await session.dispose();
      } catch (_) {}
    });

    final Recording rec = Recording(
      id: 7,
      filePath: 'rec.wav',
      createdAt: DateTime.now(),
    );
    await session.attachRecording(rec);

    final int? id = await session.saveEvaluation(
      SelfEvaluation(
        recordingId: 0, // 由 saveEvaluation 覆盖为真实录音 id
        fluency: 4,
        accuracy: 3,
        completeness: 5,
        createdAt: DateTime.now(),
      ),
    );
    expect(receivedRecordingId, 7);
    expect(id, 99);
    expect(session.phase, FollowReadPhase.done);
  });

  test('markReview 写入复习池并进入 done', () async {
    ReviewItem? captured;
    final FollowReadSession session = FollowReadSession(
      documentsDirPath: tmp.path,
      onMarkReview: (ReviewItem item) async {
        captured = item;
        return 5;
      },
    );
    addTearDown(() async {
      try {
        await session.dispose();
      } catch (_) {}
    });

    final Recording rec = Recording(
      id: 8,
      filePath: 'rec.wav',
      createdAt: DateTime.now(),
    );
    await session.attachRecording(rec);

    final int? id = await session.markReview();
    expect(id, 5);
    expect(captured?.recordingId, 8);
    expect(captured?.type, ReviewType.error.name);
    expect(session.phase, FollowReadPhase.done);
  });

  test('reset 回到 idle 并清空录音引用', () async {
    final FollowReadSession session =
        FollowReadSession(documentsDirPath: tmp.path);
    addTearDown(() async {
      try {
        await session.dispose();
      } catch (_) {}
    });

    final Recording rec = Recording(
      id: 1,
      filePath: 'rec.wav',
      createdAt: DateTime.now(),
    );
    await session.attachRecording(rec);
    expect(session.phase, FollowReadPhase.comparing);

    session.reset();
    expect(session.phase, FollowReadPhase.idle);
    expect(session.myRecording, isNull);
  });

  test('onOriginalComplete 仅在 playingOriginal 态生效', () async {
    final FollowReadSession session =
        FollowReadSession(documentsDirPath: tmp.path);
    addTearDown(() async {
      try {
        await session.dispose();
      } catch (_) {}
    });

    // idle 态调用 → 状态不应被非法跳转
    session.onOriginalComplete();
    expect(session.phase, FollowReadPhase.idle);
  });

  test('start 无原声直接进入 recording 态且忽略重复 start', () async {
    final FollowReadSession session =
        FollowReadSession(documentsDirPath: tmp.path);
    addTearDown(() async {
      try {
        await session.dispose();
      } catch (_) {}
    });

    const Sentence s = Sentence(id: 1, text: 'hello', audioPath: '');
    await session.start(s);
    expect(session.phase, FollowReadPhase.recording);

    // recording 态下重复 start 应被忽略，不打断录音流程。
    await session.start(const Sentence(id: 2, text: 'world', audioPath: ''));
    expect(session.phase, FollowReadPhase.recording);
    expect(session.sentence?.id, 1);
  });

  test('startRecording/stopRecording 仅在 recording 态生效', () async {
    final FollowReadSession session =
        FollowReadSession(documentsDirPath: tmp.path);
    addTearDown(() async {
      try {
        await session.dispose();
      } catch (_) {}
    });

    // idle 态：startRecording 直接返回、stopRecording 返回 null，均不抛异常。
    await session.startRecording();
    expect(session.phase, FollowReadPhase.idle);
    expect(await session.stopRecording(), isNull);
    expect(session.phase, FollowReadPhase.idle);
  });
}
