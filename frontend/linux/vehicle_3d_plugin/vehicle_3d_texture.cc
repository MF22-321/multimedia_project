#include "vehicle_3d_plugin/vehicle_3d_texture.h"

#include <epoxy/gl.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <mutex>
#include <vector>

namespace {

constexpr float kPi = 3.14159265358979323846f;

struct Vec3 {
  float x;
  float y;
  float z;
};

Vec3 operator-(const Vec3& left, const Vec3& right) {
  return {left.x - right.x, left.y - right.y, left.z - right.z};
}

float Dot(const Vec3& left, const Vec3& right) {
  return left.x * right.x + left.y * right.y + left.z * right.z;
}

Vec3 Cross(const Vec3& left, const Vec3& right) {
  return {
      left.y * right.z - left.z * right.y,
      left.z * right.x - left.x * right.z,
      left.x * right.y - left.y * right.x,
  };
}

Vec3 Normalize(const Vec3& value) {
  const float length = std::sqrt(std::max(Dot(value, value), 0.000001f));
  return {value.x / length, value.y / length, value.z / length};
}

struct Mat4 {
  std::array<float, 16> value{};
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
      float total = 0;
      for (int index = 0; index < 4; ++index) {
        total += left.value[index * 4 + row] *
                 right.value[column * 4 + index];
      }
      result.value[column * 4 + row] = total;
    }
  }
  return result;
}

Mat4 Translation(float x, float y, float z) {
  Mat4 result = Identity();
  result.value[12] = x;
  result.value[13] = y;
  result.value[14] = z;
  return result;
}

Mat4 Scale(float x, float y, float z) {
  Mat4 result = Identity();
  result.value[0] = x;
  result.value[5] = y;
  result.value[10] = z;
  return result;
}

Mat4 RotationX(float radians) {
  Mat4 result = Identity();
  const float cosine = std::cos(radians);
  const float sine = std::sin(radians);
  result.value[5] = cosine;
  result.value[6] = sine;
  result.value[9] = -sine;
  result.value[10] = cosine;
  return result;
}

Mat4 RotationY(float radians) {
  Mat4 result = Identity();
  const float cosine = std::cos(radians);
  const float sine = std::sin(radians);
  result.value[0] = cosine;
  result.value[2] = -sine;
  result.value[8] = sine;
  result.value[10] = cosine;
  return result;
}

Mat4 RotationZ(float radians) {
  Mat4 result = Identity();
  const float cosine = std::cos(radians);
  const float sine = std::sin(radians);
  result.value[0] = cosine;
  result.value[1] = sine;
  result.value[4] = -sine;
  result.value[5] = cosine;
  return result;
}

Mat4 Perspective(float field_of_view,
                 float aspect,
                 float near_plane,
                 float far_plane) {
  Mat4 result;
  const float factor = 1.0f / std::tan(field_of_view * 0.5f);
  result.value[0] = factor / std::max(aspect, 0.01f);
  result.value[5] = factor;
  result.value[10] =
      (far_plane + near_plane) / (near_plane - far_plane);
  result.value[11] = -1;
  result.value[14] =
      (2 * far_plane * near_plane) / (near_plane - far_plane);
  return result;
}

Mat4 LookAt(const Vec3& eye, const Vec3& center, const Vec3& up) {
  const Vec3 forward = Normalize(center - eye);
  const Vec3 side = Normalize(Cross(forward, up));
  const Vec3 corrected_up = Cross(side, forward);
  Mat4 result = Identity();
  result.value[0] = side.x;
  result.value[4] = side.y;
  result.value[8] = side.z;
  result.value[1] = corrected_up.x;
  result.value[5] = corrected_up.y;
  result.value[9] = corrected_up.z;
  result.value[2] = -forward.x;
  result.value[6] = -forward.y;
  result.value[10] = -forward.z;
  result.value[12] = -Dot(side, eye);
  result.value[13] = -Dot(corrected_up, eye);
  result.value[14] = Dot(forward, eye);
  return result;
}

struct Vertex {
  float px;
  float py;
  float pz;
  float nx;
  float ny;
  float nz;
};

struct VehicleViewState {
  std::mutex mutex;
  FlTextureRegistrar* registrar = nullptr;
  uint32_t width = 960;
  uint32_t height = 540;
  float yaw = -0.38f;
  float pitch = 0.08f;
  float zoom = 1.0f;
  bool active = false;
  // Continuous external-texture updates can corrupt the Flutter Linux
  // compositor on Jetson/NVIDIA. Flutter may explicitly enable this for an
  // isolated scene, but initialization must remain idle by default.
  bool auto_rotate = false;
  bool dirty = true;
  std::array<std::vector<uint8_t>, 4> pixel_buffers;
  size_t front_buffer = 0;
  bool pixels_ready = false;
};

struct GlResources {
  bool ready = false;
  GLuint color_texture = 0;
  GLuint framebuffer = 0;
  GLuint depth_buffer = 0;
  GLuint shader_program = 0;
  GLuint cube_vao = 0;
  GLuint cube_vbo = 0;
  GLsizei cube_vertex_count = 0;
  GLuint cylinder_vao = 0;
  GLuint cylinder_vbo = 0;
  GLsizei cylinder_vertex_count = 0;
  uint32_t allocated_width = 0;
  uint32_t allocated_height = 0;
};

GLuint CompileShader(GLenum type, const char* source) {
  const GLuint shader = glCreateShader(type);
  glShaderSource(shader, 1, &source, nullptr);
  glCompileShader(shader);
  GLint compiled = GL_FALSE;
  glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
  if (compiled == GL_TRUE) return shader;
  GLint length = 0;
  glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &length);
  std::vector<char> log(std::max(length, 1));
  glGetShaderInfoLog(shader, length, nullptr, log.data());
  g_warning("Vehicle 3D shader compile failed: %s", log.data());
  glDeleteShader(shader);
  return 0;
}

GLuint CreateProgram() {
  constexpr char kVertexShader[] = R"GLSL(
#version 330 core
layout(location = 0) in vec3 aPosition;
layout(location = 1) in vec3 aNormal;
uniform mat4 uMvp;
uniform mat4 uModel;
out vec3 vNormal;
out vec3 vWorldPosition;
void main() {
  vec4 world = uModel * vec4(aPosition, 1.0);
  vWorldPosition = world.xyz;
  vNormal = mat3(transpose(inverse(uModel))) * aNormal;
  gl_Position = uMvp * vec4(aPosition, 1.0);
}
)GLSL";
  constexpr char kFragmentShader[] = R"GLSL(
#version 330 core
in vec3 vNormal;
in vec3 vWorldPosition;
uniform vec4 uColor;
uniform float uMetallic;
uniform vec3 uCamera;
out vec4 fragmentColor;
void main() {
  vec3 normal = normalize(vNormal);
  vec3 viewDirection = normalize(uCamera - vWorldPosition);
  vec3 keyLight = normalize(vec3(-0.5, 1.0, 0.7));
  vec3 fillLight = normalize(vec3(0.8, 0.35, -0.45));
  float diffuse = max(dot(normal, keyLight), 0.0) * 0.72 +
                  max(dot(normal, fillLight), 0.0) * 0.24 + 0.15;
  vec3 halfVector = normalize(keyLight + viewDirection);
  float shininess = mix(28.0, 110.0, uMetallic);
  float specular = pow(max(dot(normal, halfVector), 0.0), shininess);
  float fresnel = pow(1.0 - max(dot(normal, viewDirection), 0.0), 4.0);
  vec3 lit = uColor.rgb * diffuse +
             vec3(specular * mix(0.18, 0.95, uMetallic)) +
             vec3(fresnel * 0.16 * uMetallic);
  fragmentColor = vec4(lit * uColor.a, uColor.a);
}
)GLSL";
  const GLuint vertex = CompileShader(GL_VERTEX_SHADER, kVertexShader);
  const GLuint fragment = CompileShader(GL_FRAGMENT_SHADER, kFragmentShader);
  if (vertex == 0 || fragment == 0) {
    if (vertex != 0) glDeleteShader(vertex);
    if (fragment != 0) glDeleteShader(fragment);
    return 0;
  }
  const GLuint program = glCreateProgram();
  glAttachShader(program, vertex);
  glAttachShader(program, fragment);
  glLinkProgram(program);
  glDeleteShader(vertex);
  glDeleteShader(fragment);
  GLint linked = GL_FALSE;
  glGetProgramiv(program, GL_LINK_STATUS, &linked);
  if (linked == GL_TRUE) return program;
  GLint length = 0;
  glGetProgramiv(program, GL_INFO_LOG_LENGTH, &length);
  std::vector<char> log(std::max(length, 1));
  glGetProgramInfoLog(program, length, nullptr, log.data());
  g_warning("Vehicle 3D program link failed: %s", log.data());
  glDeleteProgram(program);
  return 0;
}

std::vector<Vertex> CreateCubeVertices() {
  std::vector<Vertex> vertices;
  vertices.reserve(36);
  const auto face = [&vertices](Vec3 a, Vec3 b, Vec3 c, Vec3 d, Vec3 normal) {
    for (const Vec3& point : {a, b, c, a, c, d}) {
      vertices.push_back(
          {point.x, point.y, point.z, normal.x, normal.y, normal.z});
    }
  };
  face({-.5f, -.5f, .5f}, {.5f, -.5f, .5f}, {.5f, .5f, .5f},
       {-.5f, .5f, .5f}, {0, 0, 1});
  face({.5f, -.5f, -.5f}, {-.5f, -.5f, -.5f}, {-.5f, .5f, -.5f},
       {.5f, .5f, -.5f}, {0, 0, -1});
  face({-.5f, -.5f, -.5f}, {-.5f, -.5f, .5f}, {-.5f, .5f, .5f},
       {-.5f, .5f, -.5f}, {-1, 0, 0});
  face({.5f, -.5f, .5f}, {.5f, -.5f, -.5f}, {.5f, .5f, -.5f},
       {.5f, .5f, .5f}, {1, 0, 0});
  face({-.5f, .5f, .5f}, {.5f, .5f, .5f}, {.5f, .5f, -.5f},
       {-.5f, .5f, -.5f}, {0, 1, 0});
  face({-.5f, -.5f, -.5f}, {.5f, -.5f, -.5f}, {.5f, -.5f, .5f},
       {-.5f, -.5f, .5f}, {0, -1, 0});
  return vertices;
}

std::vector<Vertex> CreateCylinderVertices() {
  constexpr int kSegments = 28;
  std::vector<Vertex> vertices;
  vertices.reserve(kSegments * 12);
  for (int index = 0; index < kSegments; ++index) {
    const float angle_a = 2.0f * kPi * index / kSegments;
    const float angle_b = 2.0f * kPi * (index + 1) / kSegments;
    const Vec3 a = {std::cos(angle_a), std::sin(angle_a), -0.5f};
    const Vec3 b = {std::cos(angle_b), std::sin(angle_b), -0.5f};
    const Vec3 c = {std::cos(angle_b), std::sin(angle_b), 0.5f};
    const Vec3 d = {std::cos(angle_a), std::sin(angle_a), 0.5f};
    const Vec3 normal_a = {a.x, a.y, 0};
    const Vec3 normal_b = {b.x, b.y, 0};
    vertices.insert(vertices.end(), {
        {a.x, a.y, a.z, normal_a.x, normal_a.y, 0},
        {b.x, b.y, b.z, normal_b.x, normal_b.y, 0},
        {c.x, c.y, c.z, normal_b.x, normal_b.y, 0},
        {a.x, a.y, a.z, normal_a.x, normal_a.y, 0},
        {c.x, c.y, c.z, normal_b.x, normal_b.y, 0},
        {d.x, d.y, d.z, normal_a.x, normal_a.y, 0},
        {0, 0, -0.5f, 0, 0, -1},
        {b.x, b.y, b.z, 0, 0, -1},
        {a.x, a.y, a.z, 0, 0, -1},
        {0, 0, 0.5f, 0, 0, 1},
        {d.x, d.y, d.z, 0, 0, 1},
        {c.x, c.y, c.z, 0, 0, 1},
    });
  }
  return vertices;
}

void UploadMesh(const std::vector<Vertex>& vertices,
                GLuint* vao,
                GLuint* vbo,
                GLsizei* count) {
  glGenVertexArrays(1, vao);
  glGenBuffers(1, vbo);
  glBindVertexArray(*vao);
  glBindBuffer(GL_ARRAY_BUFFER, *vbo);
  glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(Vertex),
               vertices.data(), GL_STATIC_DRAW);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), nullptr);
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex),
                        reinterpret_cast<void*>(3 * sizeof(float)));
  glBindVertexArray(0);
  *count = static_cast<GLsizei>(vertices.size());
}

bool InitializeGl(GlResources* gl) {
  gl->shader_program = CreateProgram();
  if (gl->shader_program == 0) return false;
  UploadMesh(CreateCubeVertices(), &gl->cube_vao, &gl->cube_vbo,
             &gl->cube_vertex_count);
  UploadMesh(CreateCylinderVertices(), &gl->cylinder_vao, &gl->cylinder_vbo,
             &gl->cylinder_vertex_count);
  glGenTextures(1, &gl->color_texture);
  glGenFramebuffers(1, &gl->framebuffer);
  glGenRenderbuffers(1, &gl->depth_buffer);
  gl->ready = true;
  return true;
}

bool ResizeTarget(GlResources* gl, uint32_t width, uint32_t height) {
  if (gl->allocated_width == width && gl->allocated_height == height) {
    return true;
  }
  glBindTexture(GL_TEXTURE_2D, gl->color_texture);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_RGBA,
               GL_UNSIGNED_BYTE, nullptr);
  glBindRenderbuffer(GL_RENDERBUFFER, gl->depth_buffer);
  glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, width, height);
  glBindFramebuffer(GL_FRAMEBUFFER, gl->framebuffer);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D,
                         gl->color_texture, 0);
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT,
                            GL_RENDERBUFFER, gl->depth_buffer);
  const bool complete =
      glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE;
  gl->allocated_width = width;
  gl->allocated_height = height;
  if (!complete) g_warning("Vehicle 3D framebuffer is incomplete");
  return complete;
}

struct Color {
  float red;
  float green;
  float blue;
  float alpha;
};

void DrawMesh(const GlResources& gl,
              GLuint vao,
              GLsizei count,
              const Mat4& view_projection,
              const Mat4& root,
              const Mat4& local,
              const Color& color,
              float metallic,
              const Vec3& camera) {
  const Mat4 model = Multiply(root, local);
  const Mat4 mvp = Multiply(view_projection, model);
  glUniformMatrix4fv(glGetUniformLocation(gl.shader_program, "uMvp"), 1,
                     GL_FALSE, mvp.value.data());
  glUniformMatrix4fv(glGetUniformLocation(gl.shader_program, "uModel"), 1,
                     GL_FALSE, model.value.data());
  glUniform4f(glGetUniformLocation(gl.shader_program, "uColor"), color.red,
              color.green, color.blue, color.alpha);
  glUniform1f(glGetUniformLocation(gl.shader_program, "uMetallic"), metallic);
  glUniform3f(glGetUniformLocation(gl.shader_program, "uCamera"), camera.x,
              camera.y, camera.z);
  glBindVertexArray(vao);
  glDrawArrays(GL_TRIANGLES, 0, count);
}

Mat4 Part(float x,
          float y,
          float z,
          float scale_x,
          float scale_y,
          float scale_z,
          float rotation_z = 0) {
  return Multiply(Translation(x, y, z),
                  Multiply(RotationZ(rotation_z),
                           Scale(scale_x, scale_y, scale_z)));
}

void RenderVehicle(GlResources* gl,
                   uint32_t width,
                   uint32_t height,
                   float yaw,
                   float pitch,
                   float zoom) {
  glBindFramebuffer(GL_FRAMEBUFFER, gl->framebuffer);
  glViewport(0, 0, width, height);
  glDisable(GL_SCISSOR_TEST);
  glDisable(GL_STENCIL_TEST);
  glDisable(GL_FRAMEBUFFER_SRGB);
  glDisable(GL_POLYGON_OFFSET_FILL);
  glDisable(GL_RASTERIZER_DISCARD);
  glEnable(GL_DEPTH_TEST);
  glDepthFunc(GL_LEQUAL);
  glDepthMask(GL_TRUE);
  glEnable(GL_CULL_FACE);
  glCullFace(GL_BACK);
  glFrontFace(GL_CCW);
  glEnable(GL_BLEND);
  glBlendEquationSeparate(GL_FUNC_ADD, GL_FUNC_ADD);
  glBlendFuncSeparate(GL_ONE, GL_ONE_MINUS_SRC_ALPHA, GL_ONE,
                      GL_ONE_MINUS_SRC_ALPHA);
  glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
  glClearColor(0, 0, 0, 0);
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
  glUseProgram(gl->shader_program);

  const float distance_scale = 1.0f / std::clamp(zoom, 0.72f, 1.65f);
  const Vec3 camera = {-5.6f * distance_scale, 3.25f * distance_scale,
                       5.8f * distance_scale};
  const Mat4 projection = Perspective(42.0f * kPi / 180.0f,
                                      static_cast<float>(width) / height,
                                      0.1f, 100.0f);
  const Mat4 view = LookAt(camera, {0, 0.95f, 0}, {0, 1, 0});
  const Mat4 view_projection = Multiply(projection, view);
  const Mat4 root = Multiply(RotationY(yaw), RotationX(pitch));

  const Color silver = {0.68f, 0.72f, 0.79f, 1.0f};
  const Color silver_light = {0.86f, 0.9f, 0.96f, 1.0f};
  const Color dark = {0.012f, 0.017f, 0.024f, 1.0f};
  const Color glass = {0.025f, 0.08f, 0.12f, 0.92f};
  const Color chrome = {0.62f, 0.7f, 0.78f, 1.0f};
  const Color headlight = {0.72f, 0.93f, 1.0f, 1.0f};
  const Color tail_light = {1.0f, 0.035f, 0.025f, 1.0f};

  // Soft contact shadow first so the transparent texture blends into Flutter.
  DrawMesh(*gl, gl->cylinder_vao, gl->cylinder_vertex_count,
           view_projection, root,
           Multiply(Translation(0.15f, 0.05f, 0),
                    Multiply(RotationX(kPi / 2), Scale(2.35f, 1.05f, 0.025f))),
           {0, 0, 0, 0.28f}, 0, camera);

  // Main MPV silhouette.
  DrawMesh(*gl, gl->cube_vao, gl->cube_vertex_count, view_projection, root,
           Part(0, 0.78f, 0, 4.15f, 0.72f, 1.72f), silver, 0.82f,
           camera);
  DrawMesh(*gl, gl->cube_vao, gl->cube_vertex_count, view_projection, root,
           Part(-1.35f, 1.14f, 0, 1.5f, 0.32f, 1.64f, -0.04f),
           silver_light, 0.9f, camera);
  DrawMesh(*gl, gl->cube_vao, gl->cube_vertex_count, view_projection, root,
           Part(0.38f, 1.48f, 0, 2.55f, 0.86f, 1.52f), silver, 0.82f,
           camera);
  DrawMesh(*gl, gl->cube_vao, gl->cube_vertex_count, view_projection, root,
           Part(0.48f, 1.94f, 0, 2.38f, 0.15f, 1.38f), silver_light,
           0.88f, camera);

  // Windshield and side glass panels.
  DrawMesh(*gl, gl->cube_vao, gl->cube_vertex_count, view_projection, root,
           Part(-0.86f, 1.55f, 0, 0.09f, 0.73f, 1.39f, -0.34f), glass,
           0.35f, camera);
  for (const float side : {-0.775f, 0.775f}) {
    DrawMesh(*gl, gl->cube_vao, gl->cube_vertex_count, view_projection, root,
             Part(-0.14f, 1.59f, side, 0.78f, 0.57f, 0.035f), glass,
             0.35f, camera);
    DrawMesh(*gl, gl->cube_vao, gl->cube_vertex_count, view_projection, root,
             Part(0.73f, 1.59f, side, 0.78f, 0.57f, 0.035f), glass,
             0.35f, camera);
    DrawMesh(*gl, gl->cube_vao, gl->cube_vertex_count, view_projection, root,
             Part(1.35f, 1.57f, side, 0.39f, 0.53f, 0.035f), glass,
             0.35f, camera);
    // Door line and handle accents.
    for (const float door_x : {0.22f, 1.12f}) {
      DrawMesh(*gl, gl->cube_vao, gl->cube_vertex_count, view_projection,
               root, Part(door_x, 1.13f, side * 1.015f, 0.52f, 0.025f,
                          0.025f),
               dark, 0.45f, camera);
      DrawMesh(*gl, gl->cube_vao, gl->cube_vertex_count, view_projection,
               root, Part(door_x + 0.2f, 1.31f, side * 1.025f, 0.18f,
                          0.055f, 0.035f),
               chrome, 0.92f, camera);
    }
  }

  // Front fascia, grille, lamps, bumper and rear lamps.
  DrawMesh(*gl, gl->cube_vao, gl->cube_vertex_count, view_projection, root,
           Part(-2.09f, 0.83f, 0, 0.09f, 0.56f, 1.12f), dark, 0.32f,
           camera);
  for (int bar = -3; bar <= 3; ++bar) {
    DrawMesh(*gl, gl->cube_vao, gl->cube_vertex_count, view_projection,
             root, Part(-2.145f, 0.83f + bar * 0.07f, 0, 0.025f, 0.025f,
                        1.0f - std::abs(bar) * 0.07f),
             chrome, 0.95f, camera);
  }
  for (const float side : {-0.59f, 0.59f}) {
    DrawMesh(*gl, gl->cube_vao, gl->cube_vertex_count, view_projection,
             root, Part(-2.14f, 1.22f, side, 0.07f, 0.16f, 0.48f),
             headlight, 0.48f, camera);
    DrawMesh(*gl, gl->cube_vao, gl->cube_vertex_count, view_projection,
             root, Part(2.11f, 1.18f, side, 0.07f, 0.29f, 0.31f),
             tail_light, 0.4f, camera);
  }
  DrawMesh(*gl, gl->cube_vao, gl->cube_vertex_count, view_projection, root,
           Part(-2.11f, 0.46f, 0, 0.12f, 0.16f, 1.48f), chrome, 0.95f,
           camera);

  // Roof rails.
  for (const float side : {-0.58f, 0.58f}) {
    DrawMesh(*gl, gl->cube_vao, gl->cube_vertex_count, view_projection,
             root, Part(0.5f, 2.06f, side, 2.15f, 0.07f, 0.07f), dark,
             0.72f, camera);
  }

  // Four wheels with alloy rims and hubs.
  for (const float wheel_x : {-1.35f, 1.35f}) {
    for (const float wheel_z : {-0.91f, 0.91f}) {
      DrawMesh(*gl, gl->cylinder_vao, gl->cylinder_vertex_count,
               view_projection, root,
               Multiply(Translation(wheel_x, 0.45f, wheel_z),
                        Scale(0.48f, 0.48f, 0.34f)),
               dark, 0.12f, camera);
      DrawMesh(*gl, gl->cylinder_vao, gl->cylinder_vertex_count,
               view_projection, root,
               Multiply(Translation(wheel_x, 0.45f,
                                    wheel_z + (wheel_z > 0 ? 0.185f : -0.185f)),
                        Scale(0.32f, 0.32f, 0.04f)),
               chrome, 0.98f, camera);
      DrawMesh(*gl, gl->cylinder_vao, gl->cylinder_vertex_count,
               view_projection, root,
               Multiply(Translation(wheel_x, 0.45f,
                                    wheel_z + (wheel_z > 0 ? 0.215f : -0.215f)),
                        Scale(0.085f, 0.085f, 0.025f)),
               dark, 0.8f, camera);
    }
  }

}

}  // namespace

struct _Vehicle3DTexture {
  FlPixelBufferTexture parent_instance;
  VehicleViewState* state;
  GlResources* gl;
  FlView* view;
  GdkGLContext* render_context;
};

G_DEFINE_TYPE(Vehicle3DTexture,
              vehicle_3d_texture,
              fl_pixel_buffer_texture_get_type())

static bool EnsureRenderContext(Vehicle3DTexture* self) {
  if (self->render_context != nullptr) return true;
  if (self->view == nullptr) {
    g_warning("Vehicle 3D cannot create GL context without FlView");
    return false;
  }
  GdkWindow* window = gtk_widget_get_window(GTK_WIDGET(self->view));
  if (window == nullptr) {
    g_warning("Vehicle 3D cannot create GL context before FlView is realized");
    return false;
  }

  g_autoptr(GError) error = nullptr;
  GdkGLContext* context = gdk_window_create_gl_context(window, &error);
  if (context == nullptr) {
    g_warning("Vehicle 3D GL context creation failed: %s",
              error != nullptr ? error->message : "unknown error");
    return false;
  }
  gdk_gl_context_set_required_version(context, 3, 3);
  gdk_gl_context_set_use_es(context, FALSE);
  if (!gdk_gl_context_realize(context, &error)) {
    g_warning("Vehicle 3D GL context realize failed: %s",
              error != nullptr ? error->message : "unknown error");
    g_object_unref(context);
    return false;
  }
  self->render_context = context;
  return true;
}

class ScopedRenderContext {
 public:
  explicit ScopedRenderContext(GdkGLContext* context)
      : previous_(gdk_gl_context_get_current()) {
    if (previous_ != nullptr) g_object_ref(previous_);
    gdk_gl_context_make_current(context);
  }

  ~ScopedRenderContext() {
    if (previous_ != nullptr) {
      gdk_gl_context_make_current(previous_);
      g_object_unref(previous_);
    } else {
      gdk_gl_context_clear_current();
    }
  }

  ScopedRenderContext(const ScopedRenderContext&) = delete;
  ScopedRenderContext& operator=(const ScopedRenderContext&) = delete;

 private:
  GdkGLContext* previous_;
};

static bool RenderPendingFrame(Vehicle3DTexture* self) {
  if (!EnsureRenderContext(self)) return false;
  const ScopedRenderContext context(self->render_context);
  std::lock_guard<std::mutex> lock(self->state->mutex);
  if (!self->state->dirty && self->gl->ready) return true;
  if (!self->gl->ready && !InitializeGl(self->gl)) return false;
  if (!ResizeTarget(self->gl, self->state->width, self->state->height)) {
    return false;
  }
  RenderVehicle(self->gl, self->state->width, self->state->height,
                self->state->yaw, self->state->pitch, self->state->zoom);
  const size_t write_buffer =
      (self->state->front_buffer + 1) % self->state->pixel_buffers.size();
  auto& pixels = self->state->pixel_buffers[write_buffer];
  pixels.resize(static_cast<size_t>(self->state->width) *
                self->state->height * 4);
  glPixelStorei(GL_PACK_ALIGNMENT, 1);
  glReadPixels(0, 0, self->state->width, self->state->height, GL_RGBA,
               GL_UNSIGNED_BYTE, pixels.data());
  // Complete rendering and readback in the dedicated context before Flutter's
  // render thread is told that a new CPU pixel buffer is available.
  glFinish();
  self->state->front_buffer = write_buffer;
  self->state->pixels_ready = true;
  self->state->dirty = false;
  return true;
}

static gboolean vehicle_3d_texture_copy_pixels(FlPixelBufferTexture* texture,
                                               const uint8_t** buffer,
                                               uint32_t* width,
                                               uint32_t* height,
                                               GError** error) {
  auto* self = VEHICLE_3D_TEXTURE(texture);
  std::lock_guard<std::mutex> lock(self->state->mutex);
  // Do not issue any GL command here. Flutter receives a stable CPU buffer and
  // performs the upload inside its own renderer. Four rotating buffers keep a
  // recently returned frame alive while gestures prepare later frames.
  if (!self->state->pixels_ready) {
    g_set_error(error, g_quark_from_static_string("vehicle-3d"), 1,
                "Vehicle pixel buffer has not rendered its first frame");
    return FALSE;
  }
  *buffer = self->state->pixel_buffers[self->state->front_buffer].data();
  *width = self->state->width;
  *height = self->state->height;
  return TRUE;
}

static void vehicle_3d_texture_dispose(GObject* object) {
  auto* self = VEHICLE_3D_TEXTURE(object);
  if (self->state != nullptr) {
    g_clear_object(&self->state->registrar);
    delete self->state;
    self->state = nullptr;
  }
  g_clear_object(&self->render_context);
  self->view = nullptr;
  // Shared GL objects are reclaimed when the final shared context is destroyed.
  delete self->gl;
  self->gl = nullptr;
  G_OBJECT_CLASS(vehicle_3d_texture_parent_class)->dispose(object);
}

static void vehicle_3d_texture_class_init(Vehicle3DTextureClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = vehicle_3d_texture_dispose;
  FL_PIXEL_BUFFER_TEXTURE_CLASS(klass)->copy_pixels =
      vehicle_3d_texture_copy_pixels;
}

static void vehicle_3d_texture_init(Vehicle3DTexture* self) {
  self->state = new VehicleViewState();
  self->gl = new GlResources();
  self->view = nullptr;
  self->render_context = nullptr;
}

Vehicle3DTexture* vehicle_3d_texture_new(FlTextureRegistrar* registrar,
                                        FlView* view) {
  auto* self = VEHICLE_3D_TEXTURE(
      g_object_new(vehicle_3d_texture_get_type(), nullptr));
  self->state->registrar = FL_TEXTURE_REGISTRAR(g_object_ref(registrar));
  self->view = view;
  return self;
}

void vehicle_3d_texture_set_size(Vehicle3DTexture* self,
                                 uint32_t width,
                                 uint32_t height) {
  g_return_if_fail(VEHICLE_3D_IS_TEXTURE(self));
  std::lock_guard<std::mutex> lock(self->state->mutex);
  self->state->width = std::clamp(width, 320u, 1920u);
  self->state->height = std::clamp(height, 180u, 1080u);
  self->state->dirty = true;
}

void vehicle_3d_texture_set_transform(Vehicle3DTexture* self,
                                      float yaw,
                                      float pitch,
                                      float zoom) {
  g_return_if_fail(VEHICLE_3D_IS_TEXTURE(self));
  bool active = false;
  {
    std::lock_guard<std::mutex> lock(self->state->mutex);
    self->state->yaw = yaw;
    self->state->pitch = std::clamp(pitch, -0.18f, 0.42f);
    self->state->zoom = std::clamp(zoom, 0.72f, 1.65f);
    self->state->dirty = true;
    active = self->state->active;
  }
  // Direct GtkGLArea is the Home renderer. Its MethodChannel transform is
  // mirrored here only to retain state for the legacy texture fallback. Never
  // render/read back that dormant 960x540 texture: doing so issued glReadPixels
  // + glFinish on every drag and blocked the GTK/UI thread.
  if (active && RenderPendingFrame(self)) {
    fl_texture_registrar_mark_texture_frame_available(
        self->state->registrar, FL_TEXTURE(self));
  }
}

void vehicle_3d_texture_set_auto_rotate(Vehicle3DTexture* self, bool enabled) {
  g_return_if_fail(VEHICLE_3D_IS_TEXTURE(self));
  std::lock_guard<std::mutex> lock(self->state->mutex);
  self->state->auto_rotate = enabled;
}

void vehicle_3d_texture_set_active(Vehicle3DTexture* self, bool active) {
  g_return_if_fail(VEHICLE_3D_IS_TEXTURE(self));
  {
    std::lock_guard<std::mutex> lock(self->state->mutex);
    self->state->active = active;
    self->state->dirty = true;
  }
  if (active && RenderPendingFrame(self)) {
    fl_texture_registrar_mark_texture_frame_available(
        self->state->registrar, FL_TEXTURE(self));
  }
}

void vehicle_3d_texture_reset(Vehicle3DTexture* self) {
  g_return_if_fail(VEHICLE_3D_IS_TEXTURE(self));
  vehicle_3d_texture_set_transform(self, -0.38f, 0.08f, 1.0f);
}

bool vehicle_3d_texture_render_frame(Vehicle3DTexture* self) {
  g_return_val_if_fail(VEHICLE_3D_IS_TEXTURE(self), false);
  if (!RenderPendingFrame(self)) return false;
  fl_texture_registrar_mark_texture_frame_available(
      self->state->registrar, FL_TEXTURE(self));
  return true;
}

void vehicle_3d_texture_tick(Vehicle3DTexture* self, float delta_seconds) {
  g_return_if_fail(VEHICLE_3D_IS_TEXTURE(self));
  bool render = false;
  {
    std::lock_guard<std::mutex> lock(self->state->mutex);
    if (self->state->active && self->state->auto_rotate) {
      self->state->yaw += delta_seconds * 0.18f;
      if (self->state->yaw > kPi) self->state->yaw -= 2 * kPi;
      self->state->dirty = true;
      render = true;
    }
  }
  if (render) vehicle_3d_texture_render_frame(self);
}
