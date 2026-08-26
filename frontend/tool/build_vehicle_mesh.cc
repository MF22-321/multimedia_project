#include <meshoptimizer.h>
#include <nlohmann/json.hpp>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>

using Json = nlohmann::json;

namespace {

struct Vec3 {
  float x;
  float y;
  float z;
};

struct Mat4 {
  std::array<float, 16> value{};
};

struct Vertex {
  Vec3 position;
  Vec3 normal;
  uint32_t argb;
  uint32_t surface;
};

Mat4 Identity() {
  Mat4 result;
  result.value[0] = 1;
  result.value[5] = 1;
  result.value[10] = 1;
  result.value[15] = 1;
  return result;
}

Mat4 Multiply(const Mat4& left, const Mat4& right) {
  Mat4 result;
  for (int column = 0; column < 4; ++column) {
    for (int row = 0; row < 4; ++row) {
      for (int index = 0; index < 4; ++index) {
        result.value[column * 4 + row] +=
            left.value[index * 4 + row] * right.value[column * 4 + index];
      }
    }
  }
  return result;
}

Mat4 NodeMatrix(const Json& node) {
  if (node.contains("matrix")) {
    Mat4 result;
    for (size_t index = 0; index < 16; ++index) {
      result.value[index] = node["matrix"][index].get<float>();
    }
    return result;
  }
  const auto translation = node.value("translation", std::vector<float>{0, 0, 0});
  const auto rotation = node.value("rotation", std::vector<float>{0, 0, 0, 1});
  const auto scale = node.value("scale", std::vector<float>{1, 1, 1});
  const float x = rotation[0];
  const float y = rotation[1];
  const float z = rotation[2];
  const float w = rotation[3];
  Mat4 result = Identity();
  result.value[0] = (1 - 2 * y * y - 2 * z * z) * scale[0];
  result.value[1] = (2 * x * y + 2 * z * w) * scale[0];
  result.value[2] = (2 * x * z - 2 * y * w) * scale[0];
  result.value[4] = (2 * x * y - 2 * z * w) * scale[1];
  result.value[5] = (1 - 2 * x * x - 2 * z * z) * scale[1];
  result.value[6] = (2 * y * z + 2 * x * w) * scale[1];
  result.value[8] = (2 * x * z + 2 * y * w) * scale[2];
  result.value[9] = (2 * y * z - 2 * x * w) * scale[2];
  result.value[10] = (1 - 2 * x * x - 2 * y * y) * scale[2];
  result.value[12] = translation[0];
  result.value[13] = translation[1];
  result.value[14] = translation[2];
  return result;
}

Vec3 TransformPoint(const Mat4& matrix, const Vec3& point) {
  return {
      matrix.value[0] * point.x + matrix.value[4] * point.y +
          matrix.value[8] * point.z + matrix.value[12],
      matrix.value[1] * point.x + matrix.value[5] * point.y +
          matrix.value[9] * point.z + matrix.value[13],
      matrix.value[2] * point.x + matrix.value[6] * point.y +
          matrix.value[10] * point.z + matrix.value[14],
  };
}

Vec3 TransformNormal(const Mat4& matrix, const Vec3& normal) {
  Vec3 result = {
      matrix.value[0] * normal.x + matrix.value[4] * normal.y +
          matrix.value[8] * normal.z,
      matrix.value[1] * normal.x + matrix.value[5] * normal.y +
          matrix.value[9] * normal.z,
      matrix.value[2] * normal.x + matrix.value[6] * normal.y +
          matrix.value[10] * normal.z,
  };
  const float length = std::sqrt(std::max(
      result.x * result.x + result.y * result.y + result.z * result.z,
      0.000001f));
  result.x /= length;
  result.y /= length;
  result.z /= length;
  return result;
}

uint32_t ReadU32(const std::vector<uint8_t>& bytes, size_t offset) {
  uint32_t value;
  std::memcpy(&value, bytes.data() + offset, sizeof(value));
  return value;
}

class GlbBuilder {
 public:
  explicit GlbBuilder(std::vector<uint8_t> bytes, float target_ratio)
      : bytes_(std::move(bytes)), target_ratio_(target_ratio) {
    if (bytes_.size() < 28 || ReadU32(bytes_, 0) != 0x46546C67 ||
        ReadU32(bytes_, 4) != 2) {
      throw std::runtime_error("Input is not a valid glTF 2.0 binary file");
    }
    const uint32_t json_length = ReadU32(bytes_, 12);
    if (ReadU32(bytes_, 16) != 0x4E4F534A) {
      throw std::runtime_error("GLB JSON chunk is missing");
    }
    document_ = Json::parse(
        std::string(reinterpret_cast<const char*>(bytes_.data() + 20),
                    json_length));
    const size_t binary_header = 20 + json_length;
    if (binary_header + 8 > bytes_.size() ||
        ReadU32(bytes_, binary_header + 4) != 0x004E4942) {
      throw std::runtime_error("GLB binary chunk is missing");
    }
    binary_offset_ = binary_header + 8;
  }

  std::vector<Vertex> Build() {
    const int scene_index = document_.value("scene", 0);
    for (const auto& node : document_["scenes"][scene_index]["nodes"]) {
      WalkNode(node.get<int>(), Identity());
    }
    NormalizeModel();
    return vertices_;
  }

  size_t source_triangles() const { return source_triangles_; }

 private:
  const uint8_t* AccessorData(const Json& accessor) const {
    const Json& view = document_["bufferViews"][accessor["bufferView"].get<int>()];
    return bytes_.data() + binary_offset_ + view.value("byteOffset", 0) +
           accessor.value("byteOffset", 0);
  }

  size_t AccessorStride(const Json& accessor, size_t packed_size) const {
    const Json& view = document_["bufferViews"][accessor["bufferView"].get<int>()];
    return view.value("byteStride", packed_size);
  }

  std::vector<Vec3> ReadVec3Accessor(int accessor_index) const {
    const Json& accessor = document_["accessors"][accessor_index];
    if (accessor["componentType"].get<int>() != 5126 ||
        accessor["type"].get<std::string>() != "VEC3") {
      throw std::runtime_error("Only FLOAT VEC3 accessors are supported");
    }
    const size_t count = accessor["count"].get<size_t>();
    const size_t stride = AccessorStride(accessor, sizeof(float) * 3);
    const uint8_t* data = AccessorData(accessor);
    std::vector<Vec3> result(count);
    for (size_t index = 0; index < count; ++index) {
      std::memcpy(&result[index], data + index * stride, sizeof(Vec3));
    }
    return result;
  }

  std::vector<unsigned int> ReadIndices(int accessor_index) const {
    const Json& accessor = document_["accessors"][accessor_index];
    const size_t count = accessor["count"].get<size_t>();
    const int component = accessor["componentType"].get<int>();
    const size_t size = component == 5125 ? 4 : component == 5123 ? 2 : 1;
    const size_t stride = AccessorStride(accessor, size);
    const uint8_t* data = AccessorData(accessor);
    std::vector<unsigned int> result(count);
    for (size_t index = 0; index < count; ++index) {
      if (component == 5125) {
        std::memcpy(&result[index], data + index * stride, 4);
      } else if (component == 5123) {
        uint16_t value;
        std::memcpy(&value, data + index * stride, 2);
        result[index] = value;
      } else if (component == 5121) {
        result[index] = data[index * stride];
      } else {
        throw std::runtime_error("Unsupported index component type");
      }
    }
    return result;
  }

  uint32_t MaterialColor(int material_index) const {
    const Json& material = document_["materials"][material_index];
    const auto factor = material["pbrMetallicRoughness"].value(
        "baseColorFactor", std::vector<float>{0.8f, 0.8f, 0.8f, 1.0f});
    const auto channel = [](float value, bool black_floor = false) {
      const float adjusted = black_floor ? std::max(value, 0.035f) : value;
      return static_cast<uint32_t>(
          std::clamp(std::lround(adjusted * 255.0f), 0l, 255l));
    };
    const bool near_black = factor[0] + factor[1] + factor[2] < 0.05f;
    return (channel(factor[3]) << 24) |
           (channel(factor[0], near_black) << 16) |
           (channel(factor[1], near_black) << 8) |
           channel(factor[2], near_black);
  }

  uint32_t MaterialSurface(int material_index) const {
    const Json& material = document_["materials"][material_index];
    const Json& pbr = material["pbrMetallicRoughness"];
    // glTF 2.0 defaults both factors to 1.0 when they are omitted.
    const float roughness = pbr.value("roughnessFactor", 1.0f);
    const float metallic = pbr.value("metallicFactor", 1.0f);
    const auto channel = [](float value) {
      return static_cast<uint32_t>(std::clamp(
          std::lround(std::clamp(value, 0.0f, 1.0f) * 255.0f), 0l, 255l));
    };
    return channel(roughness) | (channel(metallic) << 8);
  }

  void AddMesh(int mesh_index, const Mat4& world) {
    const Json& mesh = document_["meshes"][mesh_index];
    for (const Json& primitive : mesh["primitives"]) {
      if (primitive.value("mode", 4) != 4) continue;
      const auto positions =
          ReadVec3Accessor(primitive["attributes"]["POSITION"].get<int>());
      const auto normals =
          ReadVec3Accessor(primitive["attributes"]["NORMAL"].get<int>());
      const auto indices = ReadIndices(primitive["indices"].get<int>());
      source_triangles_ += indices.size() / 3;

      const size_t triangle_count = indices.size() / 3;
      // Preserve genuinely tiny trim primitives, but simplify medium-sized
      // pieces too. The Veloz GLB contains many sub-180-triangle primitives;
      // exempting all of them previously left a 37k-triangle runtime mesh even
      // with a very low target ratio, which overloads Flutter Canvas on Jetson.
      const size_t target_triangles = triangle_count < 48
                                          ? triangle_count
                                          : std::max<size_t>(12, static_cast<size_t>(
                                                                     triangle_count *
                                                                     target_ratio_));
      std::vector<unsigned int> simplified = indices;
      if (target_triangles < triangle_count) {
        std::vector<unsigned int> destination(indices.size());
        const size_t target_indices = target_triangles * 3;
        float result_error = 0;
        size_t result_count = meshopt_simplify(
            destination.data(), indices.data(), indices.size(),
            &positions[0].x, positions.size(), sizeof(Vec3), target_indices,
            0.025f, &result_error);
        // Some GLB primitives contain disconnected trim islands and the
        // topology-preserving pass cannot reduce them at all. Use the spatial
        // fallback only when it misses the target badly; tiny primitives were
        // already exempted above, preserving lamps, badges and wheel details.
        if (result_count > target_indices * 3 / 2) {
          result_count = meshopt_simplifySloppy(
              destination.data(), indices.data(), indices.size(),
              &positions[0].x, positions.size(), sizeof(Vec3), target_indices,
              0.035f, &result_error);
        }
        destination.resize(result_count - result_count % 3);
        simplified = std::move(destination);
      }

      const uint32_t color = MaterialColor(primitive.value("material", 0));
      const uint32_t surface =
          MaterialSurface(primitive.value("material", 0));
      vertices_.reserve(vertices_.size() + simplified.size());
      for (const unsigned int index : simplified) {
        vertices_.push_back({TransformPoint(world, positions[index]),
                             TransformNormal(world, normals[index]), color,
                             surface});
      }
    }
  }

  void WalkNode(int node_index, const Mat4& parent) {
    const Json& node = document_["nodes"][node_index];
    const Mat4 world = Multiply(parent, NodeMatrix(node));
    if (node.contains("mesh")) AddMesh(node["mesh"].get<int>(), world);
    if (node.contains("children")) {
      for (const auto& child : node["children"]) {
        WalkNode(child.get<int>(), world);
      }
    }
  }

  void NormalizeModel() {
    const auto bounds = [this]() {
      std::array<Vec3, 2> result = {
          Vec3{std::numeric_limits<float>::max(),
               std::numeric_limits<float>::max(),
               std::numeric_limits<float>::max()},
          Vec3{-std::numeric_limits<float>::max(),
               -std::numeric_limits<float>::max(),
               -std::numeric_limits<float>::max()}};
      for (const Vertex& vertex : vertices_) {
        result[0].x = std::min(result[0].x, vertex.position.x);
        result[0].y = std::min(result[0].y, vertex.position.y);
        result[0].z = std::min(result[0].z, vertex.position.z);
        result[1].x = std::max(result[1].x, vertex.position.x);
        result[1].y = std::max(result[1].y, vertex.position.y);
        result[1].z = std::max(result[1].z, vertex.position.z);
      }
      return result;
    };
    auto model_bounds = bounds();
    const float source_extent_x = model_bounds[1].x - model_bounds[0].x;
    const float source_extent_z = model_bounds[1].z - model_bounds[0].z;
    // Sketchfab stores this vehicle's length on Z. The Flutter viewer expects
    // vehicle length on X and Y-up, so rotate once during asset generation.
    if (source_extent_z > source_extent_x) {
      for (Vertex& vertex : vertices_) {
        vertex.position =
            {vertex.position.z, vertex.position.y, -vertex.position.x};
        vertex.normal = {vertex.normal.z, vertex.normal.y, -vertex.normal.x};
      }
      model_bounds = bounds();
    }
    const Vec3 minimum = model_bounds[0];
    const Vec3 maximum = model_bounds[1];
    const float extent_x = maximum.x - minimum.x;
    const float extent_y = maximum.y - minimum.y;
    const float extent_z = maximum.z - minimum.z;
    std::cerr << "source bounds: [" << minimum.x << ", " << minimum.y << ", "
              << minimum.z << "] - [" << maximum.x << ", " << maximum.y
              << ", " << maximum.z << "] extents=" << extent_x << ","
              << extent_y << "," << extent_z << "\n";
    const float scale = 4.4f / std::max(extent_x, std::max(extent_y, extent_z));
    const Vec3 center = {(minimum.x + maximum.x) * 0.5f, minimum.y,
                         (minimum.z + maximum.z) * 0.5f};
    for (Vertex& vertex : vertices_) {
      vertex.position.x = (vertex.position.x - center.x) * scale;
      vertex.position.y = (vertex.position.y - center.y) * scale;
      vertex.position.z = (vertex.position.z - center.z) * scale;
    }
  }

  std::vector<uint8_t> bytes_;
  Json document_;
  size_t binary_offset_ = 0;
  float target_ratio_;
  size_t source_triangles_ = 0;
  std::vector<Vertex> vertices_;
};

template <typename T>
void Write(std::ofstream& output, const T& value) {
  output.write(reinterpret_cast<const char*>(&value), sizeof(value));
}

void WriteMesh(const std::string& path, const std::vector<Vertex>& vertices) {
  if (vertices.size() > 500000) {
    throw std::runtime_error("Optimized mesh exceeds runtime safety limit");
  }
  std::ofstream output(path, std::ios::binary);
  if (!output) throw std::runtime_error("Unable to open output file");
  output.write("SDTMESH2", 8);
  const uint32_t version = 2;
  const uint32_t vertex_count = static_cast<uint32_t>(vertices.size());
  Write(output, version);
  Write(output, vertex_count);
  for (const Vertex& vertex : vertices) Write(output, vertex.position);
  for (const Vertex& vertex : vertices) Write(output, vertex.normal);
  for (const Vertex& vertex : vertices) Write(output, vertex.argb);
  for (const Vertex& vertex : vertices) Write(output, vertex.surface);
}

}  // namespace

int main(int argc, char** argv) {
  if (argc < 3 || argc > 4) {
    std::cerr << "usage: build_vehicle_mesh input.glb output.sdtmesh [ratio]\n";
    return 2;
  }
  try {
    std::ifstream input(argv[1], std::ios::binary);
    if (!input) throw std::runtime_error("Unable to open input GLB");
    std::vector<uint8_t> bytes((std::istreambuf_iterator<char>(input)), {});
    const float ratio = argc == 4 ? std::stof(argv[3]) : 0.125f;
    GlbBuilder builder(std::move(bytes), ratio);
    const std::vector<Vertex> vertices = builder.Build();
    WriteMesh(argv[2], vertices);
    std::cout << "source_triangles=" << builder.source_triangles()
              << " optimized_triangles=" << vertices.size() / 3
              << " vertices=" << vertices.size() << " output=" << argv[2]
              << "\n";
  } catch (const std::exception& exception) {
    std::cerr << "vehicle mesh build failed: " << exception.what() << "\n";
    return 1;
  }
  return 0;
}
