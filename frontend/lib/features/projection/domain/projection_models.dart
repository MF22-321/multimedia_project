enum ProjectionTarget {
  androidAuto('android_auto', 'Android Auto'),
  carPlay('carplay', 'Apple CarPlay');

  const ProjectionTarget(this.wireName, this.label);

  final String wireName;
  final String label;

  static ProjectionTarget? fromWireName(Object? value) {
    for (final target in values) {
      if (target.wireName == value) return target;
    }
    return null;
  }
}

enum ProjectionTransport {
  wiredUsb('wired_usb'),
  wireless('wireless');

  const ProjectionTransport(this.wireName);

  final String wireName;

  static ProjectionTransport fromWireName(Object? value) {
    return values.firstWhere(
      (transport) => transport.wireName == value,
      orElse: () => ProjectionTransport.wiredUsb,
    );
  }
}

enum ProjectionConnectionState {
  idle,
  discovering,
  connecting,
  active,
  suspended,
  disconnected,
  error;

  static ProjectionConnectionState fromWireName(Object? value) {
    return values.firstWhere(
      (state) => state.name == value,
      orElse: () => ProjectionConnectionState.error,
    );
  }
}

class ProjectionStatus {
  const ProjectionStatus({
    required this.state,
    this.target,
    this.textureId,
    this.sdkAvailable = false,
    this.simulation = false,
    this.transport = ProjectionTransport.wiredUsb,
    this.usbPhoneDetected = false,
    this.usbAccessoryMode = false,
    this.usbDeviceName = '',
    this.usbVendorId = '',
    this.usbProductId = '',
    this.message = '',
  });

  const ProjectionStatus.idle()
    : state = ProjectionConnectionState.idle,
      target = null,
      textureId = null,
      sdkAvailable = false,
      simulation = false,
      transport = ProjectionTransport.wiredUsb,
      usbPhoneDetected = false,
      usbAccessoryMode = false,
      usbDeviceName = '',
      usbVendorId = '',
      usbProductId = '',
      message = '';

  final ProjectionConnectionState state;
  final ProjectionTarget? target;
  final int? textureId;
  final bool sdkAvailable;
  final bool simulation;
  final ProjectionTransport transport;
  final bool usbPhoneDetected;
  final bool usbAccessoryMode;
  final String usbDeviceName;
  final String usbVendorId;
  final String usbProductId;
  final String message;

  factory ProjectionStatus.fromMap(Map<Object?, Object?> map) {
    final rawTextureId = map['textureId'];
    final parsedTextureId = rawTextureId is num && rawTextureId >= 0
        ? rawTextureId.toInt()
        : null;

    return ProjectionStatus(
      state: ProjectionConnectionState.fromWireName(map['state']),
      target: ProjectionTarget.fromWireName(map['target']),
      textureId: parsedTextureId,
      sdkAvailable: map['sdkAvailable'] == true,
      simulation: map['simulation'] == true,
      transport: ProjectionTransport.fromWireName(map['transport']),
      usbPhoneDetected: map['usbPhoneDetected'] == true,
      usbAccessoryMode: map['usbAccessoryMode'] == true,
      usbDeviceName: map['usbDeviceName']?.toString() ?? '',
      usbVendorId: map['usbVendorId']?.toString() ?? '',
      usbProductId: map['usbProductId']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
    );
  }

  ProjectionStatus copyWith({
    ProjectionConnectionState? state,
    ProjectionTarget? target,
    int? textureId,
    bool clearTexture = false,
    bool? sdkAvailable,
    bool? simulation,
    ProjectionTransport? transport,
    bool? usbPhoneDetected,
    bool? usbAccessoryMode,
    String? usbDeviceName,
    String? usbVendorId,
    String? usbProductId,
    String? message,
  }) {
    return ProjectionStatus(
      state: state ?? this.state,
      target: target ?? this.target,
      textureId: clearTexture ? null : textureId ?? this.textureId,
      sdkAvailable: sdkAvailable ?? this.sdkAvailable,
      simulation: simulation ?? this.simulation,
      transport: transport ?? this.transport,
      usbPhoneDetected: usbPhoneDetected ?? this.usbPhoneDetected,
      usbAccessoryMode: usbAccessoryMode ?? this.usbAccessoryMode,
      usbDeviceName: usbDeviceName ?? this.usbDeviceName,
      usbVendorId: usbVendorId ?? this.usbVendorId,
      usbProductId: usbProductId ?? this.usbProductId,
      message: message ?? this.message,
    );
  }

  bool get isActive => state == ProjectionConnectionState.active;
  bool get canSuspend => isActive;
  bool get canResume => state == ProjectionConnectionState.suspended;
  bool get nativeReceiverReady => sdkAvailable && !simulation;
  bool get wiredAndroidAutoReady => nativeReceiverReady && usbPhoneDetected;
  String get usbIdentifier => usbVendorId.isEmpty || usbProductId.isEmpty
      ? ''
      : '$usbVendorId:$usbProductId';
  bool get canDisconnect =>
      state != ProjectionConnectionState.idle &&
      state != ProjectionConnectionState.disconnected;
}
