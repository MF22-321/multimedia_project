import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class Vehicle3DMesh {
  const Vehicle3DMesh({
    required this.positions,
    required this.normals,
    required this.colors,
    required this.surfaces,
  });

  final Float32List positions;
  final Float32List normals;
  final Uint32List colors;
  final Uint32List surfaces;

  int get vertexCount => colors.length;
  int get triangleCount => vertexCount ~/ 3;

  static Future<Vehicle3DMesh> fromAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    if (data.lengthInBytes < 16) {
      throw const FormatException('Vehicle mesh header is incomplete');
    }
    final magic = ascii.decode(data.buffer.asUint8List(data.offsetInBytes, 8));
    if (magic != 'SDTMESH2') {
      throw const FormatException('Vehicle mesh signature is invalid');
    }
    final version = data.getUint32(8, Endian.little);
    if (version != 2) {
      throw FormatException('Unsupported vehicle mesh version: $version');
    }
    final vertexCount = data.getUint32(12, Endian.little);
    if (vertexCount == 0 || vertexCount % 3 != 0 || vertexCount > 500000) {
      throw FormatException('Invalid vehicle vertex count: $vertexCount');
    }
    final positionOffset = data.offsetInBytes + 16;
    final normalOffset = positionOffset + vertexCount * 3 * 4;
    final colorOffset = normalOffset + vertexCount * 3 * 4;
    final surfaceOffset = colorOffset + vertexCount * 4;
    final expectedLength = 16 + vertexCount * 8 * 4;
    if (data.lengthInBytes != expectedLength) {
      throw FormatException(
        'Vehicle mesh length mismatch: ${data.lengthInBytes} != '
        '$expectedLength',
      );
    }
    return Vehicle3DMesh(
      positions: Float32List.view(data.buffer, positionOffset, vertexCount * 3),
      normals: Float32List.view(data.buffer, normalOffset, vertexCount * 3),
      colors: Uint32List.view(data.buffer, colorOffset, vertexCount),
      surfaces: Uint32List.view(data.buffer, surfaceOffset, vertexCount),
    );
  }
}

class Vehicle3DMeshRepository {
  Vehicle3DMeshRepository._();

  static final Map<String, Future<Vehicle3DMesh>> _assets = {};

  static Future<Vehicle3DMesh> load(String assetPath) {
    return _assets.putIfAbsent(
      assetPath,
      () => Vehicle3DMesh.fromAsset(assetPath),
    );
  }
}
