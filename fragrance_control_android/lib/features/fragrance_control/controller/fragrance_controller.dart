import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/mqtt/fragrance_mqtt_gateway.dart';
import '../../../core/mqtt/fragrance_mqtt_service.dart';
import '../model/fragrance_state.dart';

enum FragranceConnectionStatus {
  connecting,
  disconnected,
  waitingForDevice,
  deviceOnline,
  deviceOffline,
}

enum FragranceSyncStatus {
  idle,
  sending,
  synchronized,
  failed,
}

class FragranceController extends ChangeNotifier {
  FragranceController({FragranceMqttGateway? mqttService})
      : _mqttService = mqttService ?? FragranceMqttService();

  static const acknowledgementTimeout = Duration(seconds: 5);

  final FragranceMqttGateway _mqttService;

  FragranceState _state = const FragranceState();
  FragranceConnectionStatus _connectionStatus =
      FragranceConnectionStatus.disconnected;
  FragranceSyncStatus _syncStatus = FragranceSyncStatus.idle;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<Map<String, dynamic>>? _stateSubscription;
  Timer? _acknowledgementTimer;
  int _commandRevision = 0;

  FragranceState get state => _state;
  FragranceConnectionStatus get connectionStatus => _connectionStatus;
  FragranceSyncStatus get syncStatus => _syncStatus;

  Future<void> initialize() async {
    _setConnectionStatus(FragranceConnectionStatus.connecting);

    _connectionSubscription = _mqttService.connectionStream.listen(
      (connected) {
        _setConnectionStatus(
          connected
              ? FragranceConnectionStatus.waitingForDevice
              : FragranceConnectionStatus.disconnected,
        );
      },
    );

    _stateSubscription = _mqttService.stateStream.listen(_handleDeviceState);

    final connected = await _mqttService.connect();
    if (!connected) {
      _setConnectionStatus(FragranceConnectionStatus.disconnected);
    }
  }

  void toggleMainPower() {
    final turnOn = !_state.mainPower;
    _changeAndPublish(
      _state.copyWith(
        mainPower: turnOn,
        coffeeEnabled:
            turnOn ? (_state.coffeeEnabled || !_hasActiveScent) : false,
        lavenderEnabled: turnOn ? _state.lavenderEnabled : false,
        hasPendingChanges: true,
      ),
    );
  }

  void toggleCoffee() {
    final enabled = !_state.coffeeEnabled;
    final lavenderEnabled = _state.lavenderEnabled;
    _changeAndPublish(
      _state.copyWith(
        coffeeEnabled: enabled,
        mainPower: enabled || lavenderEnabled,
        hasPendingChanges: true,
      ),
    );
  }

  void toggleLavender() {
    final enabled = !_state.lavenderEnabled;
    final coffeeEnabled = _state.coffeeEnabled;
    _changeAndPublish(
      _state.copyWith(
        lavenderEnabled: enabled,
        mainPower: enabled || coffeeEnabled,
        hasPendingChanges: true,
      ),
    );
  }

  void setCoffeeSpeed(int level) {
    _changeAndPublish(
      _state.copyWith(
        coffeeSpeed: level.clamp(1, 3),
        hasPendingChanges: true,
      ),
    );
  }

  void setLavenderSpeed(int level) {
    _changeAndPublish(
      _state.copyWith(
        lavenderSpeed: level.clamp(1, 3),
        hasPendingChanges: true,
      ),
    );
  }

  void toggleAutoMode() {
    _changeAndPublish(
      _state.copyWith(
        autoMode: !_state.autoMode,
        hasPendingChanges: true,
      ),
    );
  }

  void setAutoInterval(AutoInterval interval) {
    _changeAndPublish(
      _state.copyWith(
        autoInterval: interval,
        hasPendingChanges: true,
      ),
    );
  }

  Future<bool> applyChanges() {
    final revision = ++_commandRevision;
    _setSyncStatus(FragranceSyncStatus.sending);
    return _publishRevision(_state, revision);
  }

  bool get _hasActiveScent => _state.coffeeEnabled || _state.lavenderEnabled;

  void _changeAndPublish(FragranceState nextState) {
    _state = nextState;
    _syncStatus = FragranceSyncStatus.sending;
    final revision = ++_commandRevision;
    notifyListeners();
    unawaited(_publishRevision(nextState, revision));
  }

  Future<bool> _publishRevision(
    FragranceState desiredState,
    int revision,
  ) async {
    final published = await _mqttService.publishState(desiredState.toMqtt());
    if (revision != _commandRevision) return published;

    if (!published) {
      _setSyncStatus(FragranceSyncStatus.failed);
      return false;
    }

    if (!_state.hasPendingChanges) return true;
    _acknowledgementTimer?.cancel();
    _acknowledgementTimer = Timer(acknowledgementTimeout, () {
      if (revision == _commandRevision && _state.hasPendingChanges) {
        _setSyncStatus(FragranceSyncStatus.failed);
      }
    });
    return true;
  }

  void _handleDeviceState(Map<String, dynamic> data) {
    if (data['online'] is bool) {
      _setConnectionStatus(
        data['online'] as bool
            ? FragranceConnectionStatus.deviceOnline
            : FragranceConnectionStatus.deviceOffline,
      );
    } else {
      _setConnectionStatus(FragranceConnectionStatus.deviceOnline);
    }

    final containsControlState = data.containsKey('mainPower') ||
        data.containsKey('motor1') ||
        data.containsKey('motor2');
    if (!containsControlState) return;

    final remoteState = FragranceState.fromMqtt(data, fallback: _state);
    if (_state.hasPendingChanges) {
      if (!_controlStateMatches(remoteState, _state)) {
        return;
      }

      _acknowledgementTimer?.cancel();
      _state = remoteState.copyWith(hasPendingChanges: false);
      _syncStatus = FragranceSyncStatus.synchronized;
      notifyListeners();
      return;
    }

    _state = remoteState;
    _syncStatus = FragranceSyncStatus.synchronized;
    notifyListeners();
  }

  bool _controlStateMatches(
    FragranceState remote,
    FragranceState desired,
  ) {
    final coffeeSpeedMatches =
        !desired.coffeeEnabled || remote.coffeeSpeed == desired.coffeeSpeed;
    final lavenderSpeedMatches = !desired.lavenderEnabled ||
        remote.lavenderSpeed == desired.lavenderSpeed;

    return remote.mainPower == desired.mainPower &&
        remote.autoMode == desired.autoMode &&
        remote.autoInterval == desired.autoInterval &&
        remote.coffeeEnabled == desired.coffeeEnabled &&
        remote.lavenderEnabled == desired.lavenderEnabled &&
        coffeeSpeedMatches &&
        lavenderSpeedMatches;
  }

  void _setConnectionStatus(FragranceConnectionStatus status) {
    if (_connectionStatus == status) return;
    _connectionStatus = status;
    notifyListeners();
  }

  void _setSyncStatus(FragranceSyncStatus status) {
    if (_syncStatus == status) return;
    _syncStatus = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _acknowledgementTimer?.cancel();
    unawaited(_connectionSubscription?.cancel());
    unawaited(_stateSubscription?.cancel());
    unawaited(_mqttService.dispose());
    super.dispose();
  }
}
