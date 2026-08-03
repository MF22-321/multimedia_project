enum AvatarState { idle, listening, thinking, answering }

extension AvatarStateX on AvatarState {
  static AvatarState fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'listening':
        return AvatarState.listening;
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
        return 'Idle';
      case AvatarState.listening:
        return 'Listening';
      case AvatarState.thinking:
        return 'Thinking';
      case AvatarState.answering:
        return 'Answering';
    }
  }

  bool get isVisible => this != AvatarState.idle;
}
