/// 统一异常类型。
///
/// 业务/引擎/存储各层均抛出 [AppException] 子类，UI 层据此给出用户可读提示。
sealed class AppException implements Exception {
  const AppException(this.message, [this.cause]);

  /// 用户可读错误描述。
  final String message;

  /// 原始异常（可选）。
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message ($cause)';
}

/// 麦克风权限被拒绝。
class PermissionDeniedException extends AppException {
  const PermissionDeniedException([super.message = '需要麦克风权限才能录音，请在系统设置中开启']);
}

/// 录音时长过短（在 Provider 层被丢弃）。
class RecordingTooShortException extends AppException {
  const RecordingTooShortException([super.message = '录音太短，已丢弃']);
}

/// 音频引擎（录音/播放）异常。
class AudioEngineException extends AppException {
  const AudioEngineException(super.message, [super.cause]);
}

/// 无效或损坏的音频文件。
class InvalidAudioFileException extends AppException {
  const InvalidAudioFileException(super.message, [super.cause]);
}

/// 文件系统/存储异常。
class StorageException extends AppException {
  const StorageException(super.message, [super.cause]);
}

/// 数据库异常。
class DatabaseException extends AppException {
  const DatabaseException(super.message, [super.cause]);
}
