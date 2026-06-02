enum AvatarState {
  idle,
  thinking,
  answering,
}

extension AvatarStateX on AvatarState {
  static AvatarState fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'thinking':
        return AvatarState.thinking;
      case 'answering':
        return AvatarState.answering;
      case 'idle':
      default:
        return AvatarState.idle;
    }
  }

  String get label {
    switch (this) {
      case AvatarState.idle:
        return 'Listening';
      case AvatarState.thinking:
        return 'Thinking';
      case AvatarState.answering:
        return 'Answering';
    }
  }

  bool get isVisible => this != AvatarState.idle;
}
