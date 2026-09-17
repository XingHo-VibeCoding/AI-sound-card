import 'dart:io';
import 'dart:typed_data';

import '../../core/error/app_exception.dart';

/// WAV 文件头信息。
class WavHeader {
  const WavHeader({
    required this.audioFormat,
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
    required this.dataSize,
    required this.dataOffset,
    required this.numFrames,
    this.bigEndian = false,
  });

  /// 1=PCM，3=IEEE float。
  final int audioFormat;
  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  final int dataSize;
  final int dataOffset;
  final int numFrames;

  /// 是否 RIFX 大端字节序。
  final bool bigEndian;

  int get bytesPerSample => (bitsPerSample / 8).ceil();

  int get durationMs =>
      sampleRate == 0 ? 0 : (numFrames * 1000 ~/ sampleRate);
}

/// WAV PCM 解析器（纯 Dart，无 UI 依赖，可单测）。
///
/// 支持 PCM16/PCM24/PCM8 与 32bit float，多声道自动降混为单声道，
/// 输出归一化到 [-1, 1] 的 [Float64List]，供波形/断句/F0 直接消费。
/// 同时兼容 RIFF（小端）与 RIFX（大端）字节序。
class PcmReader {
  const PcmReader();

  WavHeader readHeader(String path) {
    final Uint8List bytes = _readBytes(path);
    return _parseHeader(bytes);
  }

  /// 读取并降混为单声道归一化样本。
  Float64List readMono(String path) {
    final Uint8List bytes = _readBytes(path);
    final WavHeader header = _parseHeader(bytes);
    return _decodeMono(bytes, header);
  }

  static Uint8List _readBytes(String path) {
    final File file = File(path);
    if (!file.existsSync()) {
      throw InvalidAudioFileException('音频文件不存在: $path');
    }
    return file.readAsBytesSync();
  }

  static WavHeader _parseHeader(Uint8List bytes) {
    if (bytes.length < 12) {
      throw const InvalidAudioFileException('文件过小，不是合法 WAV');
    }
    final String riff = String.fromCharCodes(bytes.sublist(0, 4));
    final String wave = String.fromCharCodes(bytes.sublist(8, 12));
    if (riff != 'RIFF' && riff != 'RIFX') {
      throw const InvalidAudioFileException('缺少 RIFF 标识');
    }
    if (wave != 'WAVE') {
      throw const InvalidAudioFileException('缺少 WAVE 标识');
    }

    final Endian endian = riff == 'RIFX' ? Endian.big : Endian.little;

    final ByteData data = ByteData.sublistView(bytes);
    int audioFormat = 0;
    int sampleRate = 0;
    int channels = 0;
    int bitsPerSample = 0;
    int dataSize = 0;
    int dataOffset = -1;

    int offset = 12;
    while (offset + 8 <= bytes.length) {
      final String id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final int size = data.getUint32(offset + 4, endian);
      final int chunkStart = offset + 8;
      if (id == 'fmt ') {
        // fmt 块至少需要 16 字节有效数据，防止越界读取。
        if (size < 16 || chunkStart + 16 > bytes.length) {
          throw const InvalidAudioFileException('fmt 块不完整');
        }
        audioFormat = data.getUint16(chunkStart, endian);
        channels = data.getUint16(chunkStart + 2, endian);
        sampleRate = data.getUint32(chunkStart + 4, endian);
        bitsPerSample = data.getUint16(chunkStart + 14, endian);
      } else if (id == 'data') {
        dataSize = size;
        dataOffset = chunkStart;
        break;
      }
      // 子块按 2 字节对齐。
      offset = chunkStart + size + (size & 1);
    }

    if (dataOffset < 0) {
      throw const InvalidAudioFileException('缺少 data 块');
    }
    if (sampleRate <= 0 || channels <= 0 || bitsPerSample <= 0) {
      throw const InvalidAudioFileException('WAV 头信息非法');
    }

    // 防御：data 块声明长度可能超过文件实际可用字节，按实际长度截断。
    final int available = bytes.length - dataOffset;
    if (dataSize > available) dataSize = available;

    final int bytesPerSample = bitsPerSample ~/ 8;
    final int numFrames =
        (channels * bytesPerSample) == 0
            ? 0
            : dataSize ~/ (channels * bytesPerSample);

    return WavHeader(
      audioFormat: audioFormat,
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
      dataSize: dataSize,
      dataOffset: dataOffset,
      numFrames: numFrames,
      bigEndian: riff == 'RIFX',
    );
  }

  static Float64List _decodeMono(Uint8List bytes, WavHeader header) {
    final int frames = header.numFrames;
    final Float64List out = Float64List(frames);
    final ByteData data = ByteData.sublistView(
      bytes,
      header.dataOffset,
      header.dataOffset + header.dataSize,
    );
    final int channels = header.channels;
    final Endian endian = header.bigEndian ? Endian.big : Endian.little;

    for (int i = 0; i < frames; i++) {
      double sum = 0;
      for (int ch = 0; ch < channels; ch++) {
        final int sampleIndex = i * channels + ch;
        sum += _readSample(data, header, sampleIndex, endian);
      }
      out[i] = sum / channels;
    }
    return out;
  }

  static double _readSample(
    ByteData data,
    WavHeader header,
    int index,
    Endian endian,
  ) {
    if (header.audioFormat == 3 && header.bitsPerSample == 32) {
      return data.getFloat32(index * 4, endian).clamp(-1.0, 1.0).toDouble();
    }
    switch (header.bitsPerSample) {
      case 8:
        return (data.getUint8(index) - 128) / 128.0;
      case 16:
        return data.getInt16(index * 2, endian) / 32768.0;
      case 24:
        final int b0 = data.getUint8(index * 3);
        final int b1 = data.getUint8(index * 3 + 1);
        final int b2 = data.getUint8(index * 3 + 2);
        int value;
        if (endian == Endian.big) {
          value = (b0 << 16) | (b1 << 8) | b2;
        } else {
          value = (b2 << 16) | (b1 << 8) | b0;
        }
        if (value & 0x800000 != 0) value -= 0x1000000;
        return value / 8388608.0;
      case 32:
        return data.getInt32(index * 4, endian) / 2147483648.0;
      default:
        throw InvalidAudioFileException('不支持的位深: ${header.bitsPerSample}');
    }
  }
}
