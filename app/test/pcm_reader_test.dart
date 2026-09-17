import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recording_card_app/core/error/app_exception.dart';
import 'package:recording_card_app/engine/audio/pcm_reader.dart';

/// 构造一个 RIFF WAV 字节流（只支持未压缩 PCM / IEEE float）。
Uint8List _riffWav({
  required int audioFormat,
  required int bitsPerSample,
  required int sampleRate,
  required int channels,
  required Uint8List data,
}) {
  final int blockAlign = channels * (bitsPerSample ~/ 8);
  final int byteRate = sampleRate * blockAlign;
  const int fmtSize = 16;
  final int dataSize = data.length;
  final int riffSize = 4 + (8 + fmtSize) + (8 + dataSize);
  final ByteData bd = ByteData(8 + riffSize);

  void ascii(int off, String s) {
    for (int i = 0; i < s.length; i++) {
      bd.setUint8(off + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bd.setUint32(4, riffSize, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bd.setUint32(16, fmtSize, Endian.little);
  bd.setUint16(20, audioFormat, Endian.little);
  bd.setUint16(22, channels, Endian.little);
  bd.setUint32(24, sampleRate, Endian.little);
  bd.setUint32(28, byteRate, Endian.little);
  bd.setUint16(32, blockAlign, Endian.little);
  bd.setUint16(34, bitsPerSample, Endian.little);
  ascii(36, 'data');
  bd.setUint32(40, dataSize, Endian.little);
  final Uint8List out = bd.buffer.asUint8List();
  out.setRange(44, 44 + data.length, data);
  return out;
}

Uint8List _pcm16(List<int> samples, {int channels = 1, int sampleRate = 44100}) {
  final ByteData data = ByteData(samples.length * 2);
  for (int i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  return _riffWav(
    audioFormat: 1,
    bitsPerSample: 16,
    sampleRate: sampleRate,
    channels: channels,
    data: data.buffer.asUint8List(),
  );
}

Uint8List _pcm8(List<int> samples, {int sampleRate = 44100}) {
  return _riffWav(
    audioFormat: 1,
    bitsPerSample: 8,
    sampleRate: sampleRate,
    channels: 1,
    data: Uint8List.fromList(samples),
  );
}

Uint8List _pcm24(List<int> samples, {int sampleRate = 44100}) {
  final ByteData data = ByteData(samples.length * 3);
  for (int i = 0; i < samples.length; i++) {
    final int v = samples[i];
    data.setUint8(i * 3, v & 0xFF);
    data.setUint8(i * 3 + 1, (v >> 8) & 0xFF);
    data.setUint8(i * 3 + 2, (v >> 16) & 0xFF);
  }
  return _riffWav(
    audioFormat: 1,
    bitsPerSample: 24,
    sampleRate: sampleRate,
    channels: 1,
    data: data.buffer.asUint8List(),
  );
}

Uint8List _float32(List<double> samples, {int sampleRate = 44100}) {
  final ByteData data = ByteData(samples.length * 4);
  for (int i = 0; i < samples.length; i++) {
    data.setFloat32(i * 4, samples[i], Endian.little);
  }
  return _riffWav(
    audioFormat: 3,
    bitsPerSample: 32,
    sampleRate: sampleRate,
    channels: 1,
    data: data.buffer.asUint8List(),
  );
}

/// 构造一个 RIFX（大端）PCM16 单声道 WAV，用于验证大端字节序解码。
Uint8List _rifxPcm16(List<int> samples, {int sampleRate = 44100}) {
  final int dataSize = samples.length * 2;
  final int riffSize = 4 + (8 + 16) + (8 + dataSize);
  final ByteData bd = ByteData(8 + riffSize);
  void ascii(int off, String s) {
    for (int i = 0; i < s.length; i++) {
      bd.setUint8(off + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFX');
  bd.setUint32(4, riffSize, Endian.big);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bd.setUint32(16, 16, Endian.big);
  bd.setUint16(20, 1, Endian.big); // PCM
  bd.setUint16(22, 1, Endian.big); // mono
  bd.setUint32(24, sampleRate, Endian.big);
  bd.setUint32(28, sampleRate * 2, Endian.big); // byteRate
  bd.setUint16(32, 2, Endian.big); // blockAlign
  bd.setUint16(34, 16, Endian.big); // bitsPerSample
  ascii(36, 'data');
  bd.setUint32(40, dataSize, Endian.big);
  for (int i = 0; i < samples.length; i++) {
    bd.setInt16(44 + i * 2, samples[i], Endian.big);
  }
  return bd.buffer.asUint8List();
}

/// 只有 fmt 块、没有 data 块的 WAV（用于损坏文件测试）。
Uint8List _wavFmtOnly() {
  final ByteData bd = ByteData(36);
  void ascii(int off, String s) {
    for (int i = 0; i < s.length; i++) {
      bd.setUint8(off + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bd.setUint32(4, 28, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bd.setUint32(16, 16, Endian.little);
  bd.setUint16(20, 1, Endian.little);
  bd.setUint16(22, 1, Endian.little);
  bd.setUint32(24, 44100, Endian.little);
  bd.setUint32(28, 88200, Endian.little);
  bd.setUint16(32, 2, Endian.little);
  bd.setUint16(34, 16, Endian.little);
  return bd.buffer.asUint8List();
}

void main() {
  const PcmReader reader = PcmReader();
  late Directory tmp;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('pcm_reader_test');
  });

  tearDownAll(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  String write(String name, Uint8List bytes) {
    final String path = '${tmp.path}/$name';
    File(path).writeAsBytesSync(bytes);
    return path;
  }

  group('PcmReader.readHeader', () {
    test('解析 PCM16 头信息', () {
      final String path =
          write('a.wav', _pcm16(<int>[0, 16384, -32768, 32767]));
      final WavHeader h = reader.readHeader(path);
      expect(h.audioFormat, 1);
      expect(h.sampleRate, 44100);
      expect(h.channels, 1);
      expect(h.bitsPerSample, 16);
      expect(h.numFrames, 4);
      expect(h.dataSize, 8);
    });

    test('durationMs 计算正确', () {
      final String path = write('g.wav', _pcm16(List<int>.filled(44100, 0)));
      final WavHeader h = reader.readHeader(path);
      expect(h.numFrames, 44100);
      expect(h.durationMs, 1000);
    });
  });

  group('PcmReader.readMono 位深解码', () {
    test('PCM16 归一化到 [-1,1]', () {
      final String path =
          write('b.wav', _pcm16(<int>[0, 16384, -32768, 32767]));
      final Float64List mono = reader.readMono(path);
      expect(mono, hasLength(4));
      expect(mono[0], closeTo(0.0, 1e-9));
      expect(mono[1], closeTo(0.5, 1e-9));
      expect(mono[2], closeTo(-1.0, 1e-9));
      expect(mono[3], closeTo(32767 / 32768.0, 1e-9));
    });

    test('PCM8 无符号偏移 128', () {
      final String path = write('c.wav', _pcm8(<int>[128, 255, 0, 64]));
      final Float64List mono = reader.readMono(path);
      expect(mono, hasLength(4));
      expect(mono[0], closeTo(0.0, 1e-9));
      expect(mono[1], closeTo(127 / 128.0, 1e-9));
      expect(mono[2], closeTo(-1.0, 1e-9));
      expect(mono[3], closeTo((64 - 128) / 128.0, 1e-9));
    });

    test('PCM24 符号扩展正确', () {
      final String path =
          write('d.wav', _pcm24(<int>[8388607, -8388608, 0, 4194304]));
      final Float64List mono = reader.readMono(path);
      expect(mono, hasLength(4));
      expect(mono[0], closeTo(8388607 / 8388608.0, 1e-7));
      expect(mono[1], closeTo(-1.0, 1e-7));
      expect(mono[2], closeTo(0.0, 1e-7));
      expect(mono[3], closeTo(0.5, 1e-7));
    });

    test('float32 直接返回并 clamp 到 [-1,1]', () {
      final String path =
          write('e.wav', _float32(<double>[0.5, -1.5, 0.0, 2.0]));
      final Float64List mono = reader.readMono(path);
      expect(mono, hasLength(4));
      expect(mono[0], closeTo(0.5, 1e-6));
      expect(mono[1], closeTo(-1.0, 1e-6));
      expect(mono[2], closeTo(0.0, 1e-6));
      expect(mono[3], closeTo(1.0, 1e-6));
    });

    test('多声道降混为均值', () {
      final String path = write(
        'f.wav',
        _pcm16(<int>[1000, 2000, -1000, -2000], channels: 2),
      );
      final Float64List mono = reader.readMono(path);
      expect(mono, hasLength(2));
      expect(mono[0], closeTo(1500 / 32768.0, 1e-9));
      expect(mono[1], closeTo(-1500 / 32768.0, 1e-9));
    });

    test('RIFX 大端 PCM16 正确解码', () {
      final String path =
          write('rifx.wav', _rifxPcm16(<int>[0, 16384, -32768, 32767]));
      final WavHeader h = reader.readHeader(path);
      expect(h.bigEndian, isTrue);
      expect(h.sampleRate, 44100);
      expect(h.numFrames, 4);

      final Float64List mono = reader.readMono(path);
      expect(mono, hasLength(4));
      expect(mono[0], closeTo(0.0, 1e-9));
      expect(mono[1], closeTo(0.5, 1e-9));
      expect(mono[2], closeTo(-1.0, 1e-9));
      expect(mono[3], closeTo(32767 / 32768.0, 1e-9));
    });
  });

  group('PcmReader 损坏文件容错', () {
    test('文件不存在抛 InvalidAudioFileException', () {
      expect(
        () => reader.readHeader('${tmp.path}/nope.wav'),
        throwsA(isA<InvalidAudioFileException>()),
      );
    });

    test('文件过小抛异常', () {
      final String path = write('bad1.wav', Uint8List.fromList(<int>[1, 2, 3]));
      expect(
        () => reader.readHeader(path),
        throwsA(isA<InvalidAudioFileException>()),
      );
    });

    test('缺少 RIFF 标识抛异常', () {
      final String path = write(
        'bad2.wav',
        Uint8List.fromList(<int>[
          0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
        ]),
      );
      expect(
        () => reader.readHeader(path),
        throwsA(isA<InvalidAudioFileException>()),
      );
    });

    test('缺少 data 块抛异常', () {
      final String path = write('bad3.wav', _wavFmtOnly());
      expect(
        () => reader.readHeader(path),
        throwsA(isA<InvalidAudioFileException>()),
      );
    });
  });
}
