import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:frontend/core/models/vehicle_3d_mesh.dart';

const _depthBucketCount = 32768;

class Vehicle3DRenderCache {
  static final Expando<Vehicle3DRenderCache> _meshCaches =
      Expando<Vehicle3DRenderCache>('vehicle-3d-render-cache');

  static Vehicle3DRenderCache forMesh(Vehicle3DMesh mesh) {
    return _meshCaches[mesh] ??= Vehicle3DRenderCache(mesh);
  }

  Vehicle3DRenderCache(Vehicle3DMesh mesh)
    : vertexCount = mesh.vertexCount,
      triangleCount = mesh.triangleCount,
      projected = Float32List(mesh.vertexCount * 2),
      sortedProjected = Float32List(mesh.vertexCount * 2),
      depths = Float32List(mesh.vertexCount),
      colors = Int32List(mesh.vertexCount),
      sortedColors = Int32List(mesh.vertexCount),
      triangleBuckets = Uint16List(mesh.triangleCount),
      bucketCounts = Uint32List(_depthBucketCount),
      bucketCursors = Uint32List(_depthBucketCount),
      baseAlpha = Uint8List(mesh.vertexCount),
      baseRed = Uint8List(mesh.vertexCount),
      baseGreen = Uint8List(mesh.vertexCount),
      baseBlue = Uint8List(mesh.vertexCount),
      environment = Float32List(mesh.vertexCount),
      directSpecularScale = Float32List(mesh.vertexCount),
      fillSpecularScale = Float32List(mesh.vertexCount),
      rimSpecularScale = Float32List(mesh.vertexCount) {
    // Material channels never change with the camera. Decode the GLB-derived
    // values once instead of repeating bit extraction and material math for
    // all source vertices on every interaction frame.
    for (var index = 0; index < mesh.vertexCount; index++) {
      final source = mesh.colors[index];
      final red = (source >>> 16) & 0xFF;
      final green = (source >>> 8) & 0xFF;
      final blue = source & 0xFF;
      final surface = mesh.surfaces[index];
      final roughness = (surface & 0xFF) / 255;
      final metallic = ((surface >>> 8) & 0xFF) / 255;
      final gloss = 1 - roughness;
      final glossWeight = 0.38 + gloss * 0.62;
      final reflectance = 0.68 + metallic * 0.42;
      final brightest = math.max(red, math.max(green, blue));

      baseAlpha[index] = (source >>> 24) & 0xFF;
      baseRed[index] = red;
      baseGreen[index] = green;
      baseBlue[index] = blue;
      environment[index] = (1 - brightest / 255) * (12 + gloss * 12);
      directSpecularScale[index] =
          glossWeight * (92 + metallic * 54) * gloss * reflectance;
      fillSpecularScale[index] =
          glossWeight * (28 + metallic * 24) * gloss * reflectance;
      rimSpecularScale[index] =
          (16 + metallic * 18) * gloss * gloss * reflectance;
    }
  }

  final int vertexCount;
  final int triangleCount;
  final Float32List projected;
  final Float32List sortedProjected;
  final Float32List depths;
  final Int32List colors;
  final Int32List sortedColors;
  final Uint16List triangleBuckets;
  final Uint32List bucketCounts;
  final Uint32List bucketCursors;
  final Uint8List baseAlpha;
  final Uint8List baseRed;
  final Uint8List baseGreen;
  final Uint8List baseBlue;
  final Float32List environment;
  final Float32List directSpecularScale;
  final Float32List fillSpecularScale;
  final Float32List rimSpecularScale;

  bool supports(Vehicle3DMesh mesh) =>
      vertexCount == mesh.vertexCount && triangleCount == mesh.triangleCount;
}

class Vehicle3DScenePainter extends CustomPainter {
  const Vehicle3DScenePainter({
    required this.yaw,
    required this.pitch,
    required this.zoom,
    this.focusX = 0,
    this.focusY = 0,
    this.modelScale = 1,
    this.mesh,
    this.renderCache,
  });

  final double yaw;
  final double pitch;
  final double zoom;
  final double focusX;
  final double focusY;
  final double modelScale;
  final Vehicle3DMesh? mesh;
  final Vehicle3DRenderCache? renderCache;

  @override
  void paint(Canvas canvas, Size size) {
    if (mesh != null) {
      _paintImportedMesh(canvas, size, mesh!);
      return;
    }
    final projection = _Projection(size, yaw, pitch, zoom, focusX, focusY);
    final faces = <_Face>[];

    _addBox(
      faces,
      center: const _V3(0, 0.88, 0),
      size: const _V3(4.2, 0.82, 1.72),
      color: const Color(0xFFB8C2D2),
    );
    _addBox(
      faces,
      center: const _V3(0.18, 1.5, 0),
      size: const _V3(2.85, 0.76, 1.55),
      color: const Color(0xFFAEB8C8),
    );
    _addBox(
      faces,
      center: const _V3(0.32, 1.94, 0),
      size: const _V3(2.38, 0.12, 1.46),
      color: const Color(0xFFD1D7E1),
    );

    // Windows and pillars on both sides.
    for (final side in const [-1.0, 1.0]) {
      _addBox(
        faces,
        center: _V3(-0.72, 1.58, side * 0.795),
        size: const _V3(0.86, 0.47, 0.025),
        color: const Color(0xFF253444),
      );
      _addBox(
        faces,
        center: _V3(0.25, 1.58, side * 0.795),
        size: const _V3(0.82, 0.47, 0.025),
        color: const Color(0xFF304455),
      );
      _addBox(
        faces,
        center: _V3(1.14, 1.58, side * 0.795),
        size: const _V3(0.62, 0.47, 0.025),
        color: const Color(0xFF293B4C),
      );
      _addBox(
        faces,
        center: _V3(0.26, 1.12, side * 0.875),
        size: const _V3(0.72, 0.055, 0.035),
        color: const Color(0xFF647183),
      );
      _addBox(
        faces,
        center: _V3(1.18, 1.12, side * 0.875),
        size: const _V3(0.72, 0.055, 0.035),
        color: const Color(0xFF647183),
      );
      _addBox(
        faces,
        center: _V3(0.38, 2.08, side * 0.57),
        size: const _V3(2.3, 0.07, 0.07),
        color: const Color(0xFF252B35),
      );
    }

    // Grille, bumpers, lights, and rear lamps.
    _addBox(
      faces,
      center: const _V3(-2.13, 0.82, 0),
      size: const _V3(0.10, 0.54, 1.18),
      color: const Color(0xFF202733),
    );
    _addBox(
      faces,
      center: const _V3(-2.18, 0.49, 0),
      size: const _V3(0.11, 0.16, 1.52),
      color: const Color(0xFF788494),
    );
    for (final side in const [-0.57, 0.57]) {
      _addBox(
        faces,
        center: _V3(-2.18, 1.18, side),
        size: const _V3(0.10, 0.17, 0.46),
        color: const Color(0xFFDFF7FF),
      );
      _addBox(
        faces,
        center: _V3(2.16, 1.15, side),
        size: const _V3(0.10, 0.30, 0.30),
        color: const Color(0xFFFF304D),
      );
    }

    // Wheels are depth-sorted with the body faces.
    for (final x in const [-1.34, 1.34]) {
      for (final side in const [-0.93, 0.93]) {
        _addWheel(faces, _V3(x, 0.48, side), 0.45);
      }
    }

    final shadowCenter = projection.project(const _V3(0.15, 0.03, 0));
    canvas.drawOval(
      Rect.fromCenter(
        center: shadowCenter.point + const Offset(0, 9),
        width: size.shortestSide * 0.58 * zoom,
        height: size.shortestSide * 0.15 * zoom,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    final projected = faces.map((face) {
      final points = face.vertices.map(projection.project).toList();
      final depth =
          points.fold<double>(0, (sum, point) => sum + point.depth) /
          points.length;
      return _ProjectedFace(points, depth, face.color);
    }).toList()..sort((left, right) => left.depth.compareTo(right.depth));

    for (final face in projected) {
      final path = Path()
        ..moveTo(face.points.first.point.dx, face.points.first.point.dy);
      for (final point in face.points.skip(1)) {
        path.lineTo(point.point.dx, point.point.dy);
      }
      path.close();
      final shade = (0.84 + (face.depth + 4) * 0.025).clamp(0.68, 1.08);
      final color = face.color.withValues(
        red: (face.color.r * shade).clamp(0.0, 1.0).toDouble(),
        green: (face.color.g * shade).clamp(0.0, 1.0).toDouble(),
        blue: (face.color.b * shade).clamp(0.0, 1.0).toDouble(),
      );
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.75
          ..color = Colors.black.withValues(alpha: 0.20),
      );
    }

    final highlight = projection.project(const _V3(-0.45, 1.98, 0.45));
    canvas.drawCircle(
      highlight.point,
      4.5 * zoom,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  @override
  bool shouldRepaint(Vehicle3DScenePainter oldDelegate) {
    return oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.zoom != zoom ||
        oldDelegate.focusX != focusX ||
        oldDelegate.focusY != focusY ||
        oldDelegate.modelScale != modelScale ||
        oldDelegate.mesh != mesh;
  }

  void _paintImportedMesh(Canvas canvas, Size size, Vehicle3DMesh imported) {
    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);
    final distance = 8.2 / zoom;
    // The imported Veloz is normalized to a 4.4-unit vehicle length. Give it
    // a larger presentation scale than the old procedural preview so the
    // body lines remain readable in the relatively shallow Home card.
    final screenScale =
        size.shortestSide * (size.aspectRatio > 2.0 ? 2.12 : 1.62) * modelScale;
    final frame = renderCache?.supports(imported) == true
        ? renderCache!
        : Vehicle3DRenderCache.forMesh(imported);
    final vertexCount = frame.vertexCount;
    final projected = frame.projected;
    final depths = frame.depths;
    final colors = frame.colors;

    for (var index = 0; index < vertexCount; index++) {
      final offset = index * 3;
      final x = imported.positions[offset];
      final y = imported.positions[offset + 1] - 0.82;
      final z = imported.positions[offset + 2];
      final rotatedX = x * cosYaw + z * sinYaw;
      final yawDepth = -x * sinYaw + z * cosYaw;
      final rotatedY = y * cosPitch - yawDepth * sinPitch;
      final depth = y * sinPitch + yawDepth * cosPitch;
      final scale = screenScale / math.max(distance - depth, 2.4);
      projected[index * 2] =
          size.width * 0.5 +
          focusX * size.shortestSide * 0.22 +
          rotatedX * scale;
      projected[index * 2 + 1] =
          size.height * 0.52 -
          focusY * size.shortestSide * 0.20 -
          rotatedY * scale;
      depths[index] = depth;

      final nx = imported.normals[offset];
      final ny = imported.normals[offset + 1];
      final nz = imported.normals[offset + 2];
      final rotatedNx = nx * cosYaw + nz * sinYaw;
      final yawNz = -nx * sinYaw + nz * cosYaw;
      final rotatedNy = ny * cosPitch - yawNz * sinPitch;
      final rotatedNz = ny * sinPitch + yawNz * cosPitch;
      final keyDiffuse = math.max(
        0.0,
        rotatedNx * -0.28 + rotatedNy * 0.82 + rotatedNz * 0.50,
      );
      final fillDiffuse = math.max(
        0.0,
        rotatedNx * 0.72 + rotatedNy * 0.28 + rotatedNz * 0.63,
      );
      // Use the same studio-lighting response during drag and idle. Material
      // constants are precomputed in Vehicle3DRenderCache, so the real GLB
      // colors/roughness/metallic data no longer has to be decoded per frame.
      final key2 = keyDiffuse * keyDiffuse;
      final key4 = key2 * key2;
      final key8 = key4 * key4;
      final fill2 = fillDiffuse * fillDiffuse;
      final fill4 = fill2 * fill2;
      final grazing = 1 - math.min(rotatedNz.abs(), 1.0);
      final specular =
          key8 * frame.directSpecularScale[index] +
          fill4 * frame.fillSpecularScale[index] +
          grazing * grazing * frame.rimSpecularScale[index];
      final light =
          0.48 +
          keyDiffuse * 0.58 +
          fillDiffuse * 0.16 +
          math.max(rotatedNy, 0) * 0.08;
      // A small environment bounce keeps the original near-black body paint
      // legible without replacing the material color stored in the GLB.
      final environment = frame.environment[index];
      final sourceRed = frame.baseRed[index];
      final sourceGreen = frame.baseGreen[index];
      final sourceBlue = frame.baseBlue[index];
      final red = (sourceRed * light + specular * 0.97 + environment * 0.88)
          .round()
          .clamp(0, 255);
      final green = (sourceGreen * light + specular + environment * 0.96)
          .round()
          .clamp(0, 255);
      final blue = (sourceBlue * light + specular * 1.05 + environment * 1.08)
          .round()
          .clamp(0, 255);
      colors[index] =
          (frame.baseAlpha[index] << 24) | (red << 16) | (green << 8) | blue;
    }

    // Fine-grained counting sort approximates a depth buffer closely enough
    // for the grille, lamps and bumper surfaces that sit millimetres apart.
    // Typed arrays avoid allocating thousands of Dart List objects per frame.
    const bucketCount = _depthBucketCount;
    const minimumDepth = -3.5;
    const depthRange = 7.0;
    final triangleCount = frame.triangleCount;
    final triangleBuckets = frame.triangleBuckets;
    final bucketCounts = frame.bucketCounts..fillRange(0, bucketCount, 0);
    for (var triangle = 0; triangle < triangleCount; triangle++) {
      final first = triangle * 3;
      final depth = (depths[first] + depths[first + 1] + depths[first + 2]) / 3;
      final bucket = (((depth - minimumDepth) / depthRange) * (bucketCount - 1))
          .floor()
          .clamp(0, bucketCount - 1);
      triangleBuckets[triangle] = bucket;
      bucketCounts[bucket]++;
    }
    final bucketCursors = frame.bucketCursors;
    var indexOffset = 0;
    for (var bucket = 0; bucket < bucketCount; bucket++) {
      bucketCursors[bucket] = indexOffset;
      indexOffset += bucketCounts[bucket] * 3;
    }
    final sortedProjected = frame.sortedProjected;
    final sortedColors = frame.sortedColors;
    for (var triangle = 0; triangle < triangleCount; triangle++) {
      final first = triangle * 3;
      final bucket = triangleBuckets[triangle];
      final cursor = bucketCursors[bucket];
      for (var corner = 0; corner < 3; corner++) {
        final sourceVertex = first + corner;
        final destinationVertex = cursor + corner;
        sortedProjected[destinationVertex * 2] = projected[sourceVertex * 2];
        sortedProjected[destinationVertex * 2 + 1] =
            projected[sourceVertex * 2 + 1];
        sortedColors[destinationVertex] = colors[sourceVertex];
      }
      bucketCursors[bucket] = cursor + 3;
    }

    final projection = _Projection(size, yaw, pitch, zoom, focusX, focusY);
    final shadowCenter = projection.project(const _V3(0, 0.02, 0));
    canvas.drawOval(
      Rect.fromCenter(
        center: shadowCenter.point + const Offset(0, 8),
        width: size.shortestSide * 0.61 * zoom,
        height: size.shortestSide * 0.14 * zoom,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      sortedProjected,
      colors: sortedColors,
    );
    canvas.drawVertices(
      vertices,
      BlendMode.modulate,
      Paint()
        ..color = Colors.white
        ..isAntiAlias = true,
    );
  }
}

void _addBox(
  List<_Face> faces, {
  required _V3 center,
  required _V3 size,
  required Color color,
}) {
  final x = size.x / 2;
  final y = size.y / 2;
  final z = size.z / 2;
  final vertices = <_V3>[
    center + _V3(-x, -y, -z),
    center + _V3(x, -y, -z),
    center + _V3(x, y, -z),
    center + _V3(-x, y, -z),
    center + _V3(-x, -y, z),
    center + _V3(x, -y, z),
    center + _V3(x, y, z),
    center + _V3(-x, y, z),
  ];
  const indices = <List<int>>[
    [0, 1, 2, 3],
    [4, 7, 6, 5],
    [0, 4, 5, 1],
    [3, 2, 6, 7],
    [0, 3, 7, 4],
    [1, 5, 6, 2],
  ];
  for (final face in indices) {
    faces.add(_Face(face.map((index) => vertices[index]).toList(), color));
  }
}

void _addWheel(List<_Face> faces, _V3 center, double radius) {
  const segments = 18;
  final tyre = <_V3>[];
  final rim = <_V3>[];
  final outside = center.z.isNegative ? center.z - 0.035 : center.z + 0.035;
  for (var index = 0; index < segments; index++) {
    final angle = math.pi * 2 * index / segments;
    tyre.add(
      _V3(
        center.x + math.cos(angle) * radius,
        center.y + math.sin(angle) * radius,
        outside,
      ),
    );
    rim.add(
      _V3(
        center.x + math.cos(angle) * radius * 0.57,
        center.y + math.sin(angle) * radius * 0.57,
        outside + (center.z.isNegative ? -0.008 : 0.008),
      ),
    );
  }
  faces.add(_Face(tyre, const Color(0xFF161A20)));
  faces.add(_Face(rim, const Color(0xFF9AA6B6)));
}

class _Projection {
  const _Projection(
    this.size,
    this.yaw,
    this.pitch,
    this.zoom,
    this.focusX,
    this.focusY,
  );

  final Size size;
  final double yaw;
  final double pitch;
  final double zoom;
  final double focusX;
  final double focusY;

  _ProjectedPoint project(_V3 point) {
    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final rotatedX = point.x * cosYaw + point.z * sinYaw;
    final yawDepth = -point.x * sinYaw + point.z * cosYaw;
    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);
    final centeredY = point.y - 1.05;
    final rotatedY = centeredY * cosPitch - yawDepth * sinPitch;
    final depth = centeredY * sinPitch + yawDepth * cosPitch;
    final distance = 8.2 / zoom;
    final scale = size.shortestSide * 1.02 / math.max(distance - depth, 2.4);
    return _ProjectedPoint(
      Offset(
        size.width * 0.5 + focusX * size.shortestSide * 0.22 + rotatedX * scale,
        size.height * 0.53 -
            focusY * size.shortestSide * 0.20 -
            rotatedY * scale,
      ),
      depth,
    );
  }
}

class _V3 {
  const _V3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  _V3 operator +(_V3 other) => _V3(x + other.x, y + other.y, z + other.z);
}

class _Face {
  const _Face(this.vertices, this.color);

  final List<_V3> vertices;
  final Color color;
}

class _ProjectedPoint {
  const _ProjectedPoint(this.point, this.depth);

  final Offset point;
  final double depth;
}

class _ProjectedFace {
  const _ProjectedFace(this.points, this.depth, this.color);

  final List<_ProjectedPoint> points;
  final double depth;
  final Color color;
}
