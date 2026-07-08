import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/backend_config.dart';
import 'package:frontend/core/services/faceid_api.dart';

void main() {
  group('Face Recognition contract', () {
    test('camera endpoints use configured backend', () {
      expect(FaceIdApi.cameraWs, '${BackendConfig.wsBase}/ws/camera');
      expect(
        FaceIdApi.cameraPreviewWs,
        '${BackendConfig.wsBase}/ws/camera?width=480&fps=12&quality=65',
      );
    });

    test('optional camera parameters are encoded correctly', () {
      expect(
        FaceIdApi.cameraWsWith(width: 320, quality: 70),
        '${BackendConfig.wsBase}/ws/camera?width=320&quality=70',
      );
      expect(FaceIdApi.cameraWsWith(), FaceIdApi.cameraWs);
    });
  });
}
