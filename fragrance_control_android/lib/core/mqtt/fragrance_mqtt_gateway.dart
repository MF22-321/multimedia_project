abstract interface class FragranceMqttGateway {
  Stream<Map<String, dynamic>> get stateStream;
  Stream<bool> get connectionStream;
  bool get isConnected;

  Future<bool> connect();
  Future<bool> publishState(Map<String, dynamic> state);
  Future<void> dispose();
}
