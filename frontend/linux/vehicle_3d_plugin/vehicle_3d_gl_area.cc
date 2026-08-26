#include "vehicle_3d_plugin/vehicle_3d_gl_area.h"

#include <epoxy/gl.h>
#include <limits.h>
#include <unistd.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <string>
#include <vector>

namespace {

struct Vec3 { float x, y, z; };
struct Mat4 { std::array<float, 16> v{}; };
struct GpuVertex {
  float px, py, pz;
  float nx, ny, nz;
  float r, g, b, a;
  float roughness, metallic;
};

Vec3 Sub(Vec3 a, Vec3 b) { return {a.x-b.x, a.y-b.y, a.z-b.z}; }
float Dot(Vec3 a, Vec3 b) { return a.x*b.x+a.y*b.y+a.z*b.z; }
Vec3 Cross(Vec3 a, Vec3 b) {
  return {a.y*b.z-a.z*b.y, a.z*b.x-a.x*b.z, a.x*b.y-a.y*b.x};
}
Vec3 Normalize(Vec3 a) {
  const float l = std::sqrt(std::max(Dot(a,a), 0.000001f));
  return {a.x/l,a.y/l,a.z/l};
}
Mat4 Identity() { Mat4 m; m.v[0]=m.v[5]=m.v[10]=m.v[15]=1; return m; }
Mat4 Multiply(const Mat4& a, const Mat4& b) {
  Mat4 r;
  for (int c=0;c<4;c++) for (int row=0;row<4;row++)
    for (int k=0;k<4;k++) r.v[c*4+row]+=a.v[k*4+row]*b.v[c*4+k];
  return r;
}
Mat4 Translation(float x,float y,float z) {
  Mat4 m=Identity(); m.v[12]=x;m.v[13]=y;m.v[14]=z; return m;
}
Mat4 Scale(float s) { Mat4 m=Identity();m.v[0]=m.v[5]=m.v[10]=s;return m; }
Mat4 RotationX(float a) {
  Mat4 m=Identity(); const float c=std::cos(a),s=std::sin(a);
  m.v[5]=c;m.v[6]=s;m.v[9]=-s;m.v[10]=c;return m;
}
Mat4 RotationY(float a) {
  Mat4 m=Identity(); const float c=std::cos(a),s=std::sin(a);
  m.v[0]=c;m.v[2]=-s;m.v[8]=s;m.v[10]=c;return m;
}
Mat4 Perspective(float fov,float aspect,float near,float far) {
  Mat4 m; const float f=1/std::tan(fov*.5f);
  m.v[0]=f/std::max(aspect,.01f);m.v[5]=f;
  m.v[10]=(far+near)/(near-far);m.v[11]=-1;m.v[14]=2*far*near/(near-far);
  return m;
}
Mat4 LookAt(Vec3 eye,Vec3 center,Vec3 up) {
  Vec3 f=Normalize(Sub(center,eye)),s=Normalize(Cross(f,up)),u=Cross(s,f);
  Mat4 m=Identity();m.v[0]=s.x;m.v[4]=s.y;m.v[8]=s.z;
  m.v[1]=u.x;m.v[5]=u.y;m.v[9]=u.z;m.v[2]=-f.x;m.v[6]=-f.y;m.v[10]=-f.z;
  m.v[12]=-Dot(s,eye);m.v[13]=-Dot(u,eye);m.v[14]=Dot(f,eye);return m;
}

GLuint Shader(GLenum type,const char* source) {
  GLuint s=glCreateShader(type);glShaderSource(s,1,&source,nullptr);glCompileShader(s);
  GLint ok=0;glGetShaderiv(s,GL_COMPILE_STATUS,&ok);
  if(ok) return s; char log[2048]{};glGetShaderInfoLog(s,sizeof(log),nullptr,log);
  g_warning("Vehicle GLArea shader: %s",log);glDeleteShader(s);return 0;
}
GLuint Program() {
  const char* vs=R"GLSL(#version 330 core
layout(location=0) in vec3 p; layout(location=1) in vec3 n;
layout(location=2) in vec4 color; layout(location=3) in vec2 surface;
uniform mat4 model; uniform mat4 mvp;
out vec3 N; out vec3 P; out vec4 C; out vec2 S;
void main(){vec4 w=model*vec4(p,1);P=w.xyz;N=mat3(model)*n;C=color;S=surface;gl_Position=mvp*vec4(p,1);})GLSL";
  const char* fs=R"GLSL(#version 330 core
in vec3 N; in vec3 P; in vec4 C; in vec2 S; uniform vec3 camera;
out vec4 outColor;
const float PI=3.14159265359;
vec3 fresnelSchlick(float cosine,vec3 f0){return f0+(1-f0)*pow(1-cosine,5);}
float distributionGgx(float noh,float alpha){
 float a2=alpha*alpha,d=noh*noh*(a2-1)+1;return a2/max(PI*d*d,.0001);
}
float geometrySchlick(float nox,float k){return nox/max(nox*(1-k)+k,.0001);}
vec3 directLight(vec3 n,vec3 v,vec3 l,vec3 radiance,vec3 base,float rough,float metal){
 vec3 h=normalize(v+l);float nov=max(dot(n,v),0),nol=max(dot(n,l),0),noh=max(dot(n,h),0),voh=max(dot(v,h),0);
 float alpha=max(rough*rough,.004),k=(rough+1)*(rough+1)/8;
 vec3 f0=mix(vec3(.045),base,metal),f=fresnelSchlick(voh,f0);
 float d=distributionGgx(noh,alpha),g=geometrySchlick(nov,k)*geometrySchlick(nol,k);
 vec3 spec=d*g*f/max(4*nov*nol,.001),diffuse=(1-f)*(1-metal)*base/PI;
 return (diffuse+spec)*radiance*nol;
}
vec3 aces(vec3 x){return clamp((x*(2.51*x+.03))/(x*(2.43*x+.59)+.14),0,1);}
void main(){
 vec3 n=normalize(N),v=normalize(camera-P);
 float rough=clamp(S.x*.82,.055,.92),metal=clamp(S.y,0,1);
 vec3 base=pow(max(C.rgb,vec3(.028)),vec3(2.2));
 vec3 key=directLight(n,v,normalize(vec3(-.48,.82,.42)),vec3(4.4,4.75,5.2),base,rough,metal);
 vec3 fill=directLight(n,v,normalize(vec3(.72,.38,.56)),vec3(1.55,1.82,2.15),base,rough,metal);
 vec3 rim=directLight(n,v,normalize(vec3(.12,.58,-.81)),vec3(.72,1.12,1.48),base,rough,metal);
 float nov=max(dot(n,v),0),sky=.5+.5*n.y;vec3 reflected=reflect(-v,n);
 vec3 f0=mix(vec3(.045),base,metal),fres=fresnelSchlick(nov,f0);
 float horizon=pow(max(0,1-abs(reflected.y)),3);
 float softbox=pow(max(0,1-abs(dot(reflected,normalize(vec3(.72,.12,.68))))),7);
 vec3 environment=mix(vec3(.025,.045,.065),vec3(.24,.29,.34),sky);
 vec3 indirect=base*(1-metal)*(.075+.13*sky)+fres*(environment*(.62+.50*(1-rough))
   +vec3(.55,.72,.92)*(.34*horizon+.72*softbox));
 float clearCoat=pow(max(dot(n,normalize(normalize(vec3(-.48,.82,.42))+v)),0),mix(360.0,80.0,rough));
 vec3 linear=key+fill+rim+indirect+vec3(.75,.90,1.0)*clearCoat*.48*(1-.55*rough);
 outColor=vec4(pow(aces(linear),vec3(1/2.2)),C.a);
})GLSL";
  GLuint a=Shader(GL_VERTEX_SHADER,vs),b=Shader(GL_FRAGMENT_SHADER,fs);
  if(!a||!b)return 0;GLuint p=glCreateProgram();glAttachShader(p,a);glAttachShader(p,b);
  glLinkProgram(p);glDeleteShader(a);glDeleteShader(b);GLint ok=0;glGetProgramiv(p,GL_LINK_STATUS,&ok);
  if(ok)return p;glDeleteProgram(p);return 0;
}

std::string AssetPath() {
  char path[PATH_MAX]{}; const ssize_t n=readlink("/proc/self/exe",path,sizeof(path)-1);
  if(n<=0)return {};path[n]=0;std::string p(path);const auto slash=p.find_last_of('/');
  return p.substr(0,slash)+"/data/flutter_assets/assets/models/toyota_veloz_2022_source.sdtmesh";
}
uint32_t U32(const std::vector<uint8_t>& b,size_t o){uint32_t v;std::memcpy(&v,b.data()+o,4);return v;}
bool LoadMesh(std::vector<GpuVertex>* out) {
  std::ifstream in(AssetPath(),std::ios::binary);if(!in)return false;
  std::vector<uint8_t>b((std::istreambuf_iterator<char>(in)),{});
  if(b.size()<16||std::memcmp(b.data(),"SDTMESH2",8)||U32(b,8)!=2)return false;
  const uint32_t count=U32(b,12);const size_t expected=16+size_t(count)*32;
  if(!count||b.size()!=expected)return false;
  const float* pos=reinterpret_cast<const float*>(b.data()+16);
  const float* norm=pos+size_t(count)*3;
  const uint32_t* colors=reinterpret_cast<const uint32_t*>(norm+size_t(count)*3);
  const uint32_t* surfaces=colors+count;out->resize(count);
  for(uint32_t i=0;i<count;i++){
    const uint32_t c=colors[i],s=surfaces[i];
    (*out)[i]={pos[i*3],pos[i*3+1],pos[i*3+2],norm[i*3],norm[i*3+1],norm[i*3+2],
      float((c>>16)&255)/255,float((c>>8)&255)/255,float(c&255)/255,float((c>>24)&255)/255,
      float(s&255)/255,float((s>>8)&255)/255};
  }return true;
}

}  // namespace

struct Vehicle3DGlArea {
  GtkWidget* parent=nullptr; GtkWidget* area=nullptr; GLuint vao=0,vbo=0,program=0;
  GLuint msaa_fbo=0,msaa_color=0,msaa_depth=0; int msaa_width=0,msaa_height=0;
  GLuint motion_fbo=0,motion_color=0,motion_depth=0; int motion_width=0,motion_height=0;
  GLint model_uniform=-1,mvp_uniform=-1,camera_uniform=-1; int msaa_samples=-1;
  GLsizei count=0; float yaw=-.38f,pitch=.08f,zoom=1.16f,focus_x=0,focus_y=0;
  double last_x=0,last_y=0,press_x=0,press_y=0; bool drag_moved=false;
  int x=0,y=0,width=640,height=360; bool visible=false,interacting=false;
  Vehicle3DTapCallback tap_callback=nullptr; void* tap_user_data=nullptr;
  std::vector<GpuVertex> pending_vertices;
};

static bool EnsureMotionBuffer(Vehicle3DGlArea* v,int width,int height){
  if(!v->motion_fbo){glGenFramebuffers(1,&v->motion_fbo);glGenRenderbuffers(1,&v->motion_color);glGenRenderbuffers(1,&v->motion_depth);}
  if(v->motion_width==width&&v->motion_height==height)return true;
  v->motion_width=width;v->motion_height=height;glBindFramebuffer(GL_FRAMEBUFFER,v->motion_fbo);
  glBindRenderbuffer(GL_RENDERBUFFER,v->motion_color);glRenderbufferStorage(GL_RENDERBUFFER,GL_RGBA8,width,height);
  glFramebufferRenderbuffer(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_RENDERBUFFER,v->motion_color);
  glBindRenderbuffer(GL_RENDERBUFFER,v->motion_depth);glRenderbufferStorage(GL_RENDERBUFFER,GL_DEPTH_COMPONENT24,width,height);
  glFramebufferRenderbuffer(GL_FRAMEBUFFER,GL_DEPTH_ATTACHMENT,GL_RENDERBUFFER,v->motion_depth);
  const bool complete=glCheckFramebufferStatus(GL_FRAMEBUFFER)==GL_FRAMEBUFFER_COMPLETE;
  if(!complete){v->motion_width=0;v->motion_height=0;g_warning("Vehicle GLArea motion framebuffer is incomplete");}
  return complete;
}

static bool EnsureMsaa(Vehicle3DGlArea* v,int width,int height){
  // 2x MSAA keeps the body/wheel edges clean at this small viewport while
  // halving multisample fill and resolve work compared with 4x on Jetson.
  if(v->msaa_samples<0){GLint maximum=0;glGetIntegerv(GL_MAX_SAMPLES,&maximum);v->msaa_samples=std::min(maximum,2);}
  const int samples=v->msaa_samples;
  if(samples<2)return false;
  if(!v->msaa_fbo){glGenFramebuffers(1,&v->msaa_fbo);glGenRenderbuffers(1,&v->msaa_color);glGenRenderbuffers(1,&v->msaa_depth);}
  if(v->msaa_width==width&&v->msaa_height==height)return true;
  v->msaa_width=width;v->msaa_height=height;glBindFramebuffer(GL_FRAMEBUFFER,v->msaa_fbo);
  glBindRenderbuffer(GL_RENDERBUFFER,v->msaa_color);glRenderbufferStorageMultisample(GL_RENDERBUFFER,samples,GL_RGBA8,width,height);
  glFramebufferRenderbuffer(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_RENDERBUFFER,v->msaa_color);
  glBindRenderbuffer(GL_RENDERBUFFER,v->msaa_depth);glRenderbufferStorageMultisample(GL_RENDERBUFFER,samples,GL_DEPTH_COMPONENT24,width,height);
  glFramebufferRenderbuffer(GL_FRAMEBUFFER,GL_DEPTH_ATTACHMENT,GL_RENDERBUFFER,v->msaa_depth);
  const bool complete=glCheckFramebufferStatus(GL_FRAMEBUFFER)==GL_FRAMEBUFFER_COMPLETE;
  if(!complete)g_warning("Vehicle GLArea MSAA framebuffer is incomplete");
  return complete;
}

static gboolean Render(GtkGLArea* area,GdkGLContext*,gpointer data) {
  auto* v=static_cast<Vehicle3DGlArea*>(data);
  if(!v->program){
    if(v->pending_vertices.empty()&&!LoadMesh(&v->pending_vertices)){g_warning("Vehicle GLArea mesh load failed");return TRUE;}
    v->program=Program();if(!v->program)return TRUE;glGenVertexArrays(1,&v->vao);glGenBuffers(1,&v->vbo);
    glBindVertexArray(v->vao);glBindBuffer(GL_ARRAY_BUFFER,v->vbo);
    glBufferData(GL_ARRAY_BUFFER,v->pending_vertices.size()*sizeof(GpuVertex),v->pending_vertices.data(),GL_STATIC_DRAW);
    const GLsizei stride=sizeof(GpuVertex);
    glEnableVertexAttribArray(0);glVertexAttribPointer(0,3,GL_FLOAT,FALSE,stride,(void*)0);
    glEnableVertexAttribArray(1);glVertexAttribPointer(1,3,GL_FLOAT,FALSE,stride,(void*)(3*sizeof(float)));
    glEnableVertexAttribArray(2);glVertexAttribPointer(2,4,GL_FLOAT,FALSE,stride,(void*)(6*sizeof(float)));
    glEnableVertexAttribArray(3);glVertexAttribPointer(3,2,GL_FLOAT,FALSE,stride,(void*)(10*sizeof(float)));
    v->count=static_cast<GLsizei>(v->pending_vertices.size());
    v->model_uniform=glGetUniformLocation(v->program,"model");v->mvp_uniform=glGetUniformLocation(v->program,"mvp");
    v->camera_uniform=glGetUniformLocation(v->program,"camera");
    std::vector<GpuVertex>().swap(v->pending_vertices);
  }
  const int scale=gtk_widget_get_scale_factor(GTK_WIDGET(area));
  const int w=std::max(1,gtk_widget_get_allocated_width(GTK_WIDGET(area))*scale);
  const int h=std::max(1,gtk_widget_get_allocated_height(GTK_WIDGET(area))*scale);
  GLint default_fbo=0;glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING,&default_fbo);
  // Motion is where frame pacing matters most and edge aliasing is least
  // visible. Render single-sample while dragging, then restore 2x MSAA for the
  // final stationary frame. This nearly halves fill/resolve work on Jetson.
  const bool msaa=!v->interacting&&EnsureMsaa(v,w,h);
  const bool motion=v->interacting&&EnsureMotionBuffer(v,w,h);
  const GLuint render_fbo=msaa?v->msaa_fbo:(motion?v->motion_fbo:static_cast<GLuint>(default_fbo));
  glBindFramebuffer(GL_FRAMEBUFFER,render_fbo);
  glViewport(0,0,w,h);glClearColor(0,0,0,0);glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
  glEnable(GL_DEPTH_TEST);glDepthFunc(GL_LEQUAL);glDisable(GL_CULL_FACE);
  if(msaa)glEnable(GL_MULTISAMPLE);else glDisable(GL_MULTISAMPLE);
  // Keep a stable safety margin around the 4.4-unit model. At 5.4 units the
  // near rear corner could leave the frustum at three-quarter angles even
  // without user zoom, which looked like the rear frame was cut off.
  const Vec3 eye={0,.78f,5.9f};
  Mat4 model=Multiply(Translation(v->focus_x,-.82f+v->focus_y,0),Multiply(RotationX(v->pitch),Multiply(RotationY(v->yaw),Scale(v->zoom))));
  Mat4 vp=Multiply(Perspective(.52f,float(w)/h,.1f,30),LookAt(eye,{0,0,0},{0,1,0}));
  Mat4 mvp=Multiply(vp,model);glUseProgram(v->program);
  glUniformMatrix4fv(v->model_uniform,1,FALSE,model.v.data());
  glUniformMatrix4fv(v->mvp_uniform,1,FALSE,mvp.v.data());
  glUniform3f(v->camera_uniform,eye.x,eye.y,eye.z);
  glBindVertexArray(v->vao);glDrawArrays(GL_TRIANGLES,0,v->count);glBindVertexArray(0);
  if(msaa||motion){glBindFramebuffer(GL_READ_FRAMEBUFFER,render_fbo);glBindFramebuffer(GL_DRAW_FRAMEBUFFER,default_fbo);glBlitFramebuffer(0,0,w,h,0,0,w,h,GL_COLOR_BUFFER_BIT,GL_LINEAR);glBindFramebuffer(GL_FRAMEBUFFER,default_fbo);}
  // Submit the completed off-screen frame before GTK composites the alpha
  // surface. This prevents an empty backing image from being sampled during
  // rapid drag updates on the NVIDIA/GTK stack.
  glFlush();
  return TRUE;
}
static void SizeAllocated(GtkWidget* widget,GtkAllocation* allocation,gpointer data){
  auto*v=static_cast<Vehicle3DGlArea*>(data);
  if(!v||!v->visible||allocation->width<1||allocation->height<1)return;
  // set_size_request() queues a GTK allocation asynchronously. With
  // auto-render disabled, the render requested by set_bounds() can therefore
  // run against the old framebuffer and be discarded when the new allocation
  // lands. Queue the authoritative frame after allocation so moving the shared
  // surface Home -> Tire Pressure -> Home can never leave it transparent.
  gtk_gl_area_queue_render(GTK_GL_AREA(widget));
}
static gboolean Button(GtkWidget* w,GdkEventButton* e,gpointer d){
  auto*v=(Vehicle3DGlArea*)d;v->last_x=e->x;v->last_y=e->y;
  const bool interacting=e->type==GDK_BUTTON_PRESS;
  if(interacting){v->press_x=e->x;v->press_y=e->y;v->drag_moved=false;}
  if(v->interacting!=interacting){v->interacting=interacting;gtk_gl_area_queue_render(GTK_GL_AREA(w));}
  if(!interacting&&!v->drag_moved&&e->button==1&&v->tap_callback){
    const double width=std::max(1,gtk_widget_get_allocated_width(w));
    const double height=std::max(1,gtk_widget_get_allocated_height(w));
    v->tap_callback(std::clamp(e->x/width,0.0,1.0),std::clamp(e->y/height,0.0,1.0),v->tap_user_data);
  }
  return TRUE;
}
static gboolean Motion(GtkWidget* w,GdkEventMotion* e,gpointer d){
  auto*v=(Vehicle3DGlArea*)d;if(!(e->state&GDK_BUTTON1_MASK))return FALSE;
  if(std::hypot(e->x-v->press_x,e->y-v->press_y)>8)v->drag_moved=true;
  v->yaw+=(e->x-v->last_x)*.008f;v->pitch=std::clamp(v->pitch+(float)(e->y-v->last_y)*.004f,-.18f,.42f);
  v->last_x=e->x;v->last_y=e->y;gtk_gl_area_queue_render(GTK_GL_AREA(w));return TRUE;
}
static gboolean Scroll(GtkWidget* w,GdkEventScroll* e,gpointer d){
  auto*v=(Vehicle3DGlArea*)d;double dy=0;if(e->direction==GDK_SCROLL_UP)dy=-1;else if(e->direction==GDK_SCROLL_DOWN)dy=1;else gdk_event_get_scroll_deltas((GdkEvent*)e,nullptr,&dy);
  v->zoom=std::clamp(v->zoom*(dy>0 ? .92f : 1.08f),.72f,1.55f);gtk_gl_area_queue_render(GTK_GL_AREA(w));return TRUE;
}

Vehicle3DGlArea* vehicle_3d_gl_area_new(GtkWidget* parent){
  if(!parent||!GTK_IS_FIXED(parent))return nullptr;auto*v=new Vehicle3DGlArea();v->parent=parent;v->area=gtk_gl_area_new();
  // Parse the compact mesh while the app is still starting. The first Home
  // frame then only compiles shaders and uploads the already prepared buffer,
  // avoiding a visible pause when the Veloz replaces the empty card.
  if(!LoadMesh(&v->pending_vertices))g_warning("Vehicle GLArea mesh preload failed; retrying on first render");
  gtk_gl_area_set_required_version(GTK_GL_AREA(v->area),3,3);gtk_gl_area_set_has_alpha(GTK_GL_AREA(v->area),TRUE);
  gtk_gl_area_set_has_depth_buffer(GTK_GL_AREA(v->area),TRUE);gtk_gl_area_set_auto_render(GTK_GL_AREA(v->area),FALSE);
  gtk_widget_set_app_paintable(v->area,TRUE);
  gtk_widget_add_events(v->area,GDK_BUTTON_PRESS_MASK|GDK_BUTTON_RELEASE_MASK|GDK_POINTER_MOTION_MASK|GDK_SCROLL_MASK|GDK_SMOOTH_SCROLL_MASK);
  g_signal_connect(v->area,"render",G_CALLBACK(Render),v);g_signal_connect(v->area,"button-press-event",G_CALLBACK(Button),v);
  g_signal_connect_after(v->area,"size-allocate",G_CALLBACK(SizeAllocated),v);
  g_signal_connect(v->area,"button-release-event",G_CALLBACK(Button),v);
  g_signal_connect(v->area,"motion-notify-event",G_CALLBACK(Motion),v);g_signal_connect(v->area,"scroll-event",G_CALLBACK(Scroll),v);
  gtk_fixed_put(GTK_FIXED(parent),v->area,-10000,-10000);g_object_ref(v->area);gtk_widget_set_size_request(v->area,v->width,v->height);
  // Keep GtkGLArea mapped for its whole lifetime. Repeatedly mapping and
  // unmapping an alpha GL surface can replace the complete Flutter frame with
  // black on NVIDIA/GTK. Keep its final allocation while it is parked so the
  // framebuffer can be prepared before it is moved on-screen. Auto-render is
  // disabled, therefore the parked surface does not consume frames.
  gtk_widget_show(v->area);return v;
}
void vehicle_3d_gl_area_destroy(Vehicle3DGlArea*v){if(!v)return;if(v->area){gtk_widget_destroy(v->area);g_object_unref(v->area);}delete v;}
bool vehicle_3d_gl_area_initialize(Vehicle3DGlArea*v){return v!=nullptr;}
void vehicle_3d_gl_area_set_bounds(Vehicle3DGlArea*v,int x,int y,int w,int h){
  if(!v)return;w=std::max(w,1);h=std::max(h,1);
  if(v->x==x&&v->y==y&&v->width==w&&v->height==h){
    // Bounds can be re-applied after the Flutter overlay has settled. Queue a
    // fresh frame even when the allocation is unchanged so a parked/stale
    // GtkGLArea cannot remain blank in the Tire Pressure viewport.
    if(v->visible)gtk_gl_area_queue_render(GTK_GL_AREA(v->area));
    return;
  }
  v->x=x;v->y=y;v->width=w;v->height=h;
  gtk_widget_set_size_request(v->area,w,h);
  gtk_fixed_move(GTK_FIXED(v->parent),v->area,v->visible?x:-10000,v->visible?y:-10000);
  gtk_gl_area_queue_render(GTK_GL_AREA(v->area));
}
void vehicle_3d_gl_area_set_visible(Vehicle3DGlArea*v,bool show){
  if(!v)return;
  if(v->visible==show){
    if(show){
      gtk_fixed_move(GTK_FIXED(v->parent),v->area,v->x,v->y);
      gtk_gl_area_queue_render(GTK_GL_AREA(v->area));
    }
    return;
  }
  v->visible=show;
  if(show){
    gtk_fixed_move(GTK_FIXED(v->parent),v->area,v->x,v->y);
    gtk_widget_set_size_request(v->area,v->width,v->height);
    gtk_gl_area_queue_render(GTK_GL_AREA(v->area));
  }else{
    gtk_fixed_move(GTK_FIXED(v->parent),v->area,-10000,-10000);
  }
}
void vehicle_3d_gl_area_set_transform(Vehicle3DGlArea*v,float y,float p,float z){
  if(!v)return;p=std::clamp(p,-.18f,.42f);z=std::clamp(z,.72f,1.55f);
  if(std::abs(v->yaw-y)<.0001f&&std::abs(v->pitch-p)<.0001f&&std::abs(v->zoom-z)<.0001f)return;
  v->yaw=y;v->pitch=p;v->zoom=z;if(v->visible)gtk_gl_area_queue_render(GTK_GL_AREA(v->area));
}
void vehicle_3d_gl_area_set_interacting(Vehicle3DGlArea*v,bool interacting){
  if(!v||v->interacting==interacting)return;v->interacting=interacting;
  if(v->visible)gtk_gl_area_queue_render(GTK_GL_AREA(v->area));
}
void vehicle_3d_gl_area_set_focus(Vehicle3DGlArea*v,float x,float y){
  if(!v)return;x=std::clamp(x,-1.5f,1.5f);y=std::clamp(y,-.4f,.9f);
  if(std::abs(v->focus_x-x)<.0001f&&std::abs(v->focus_y-y)<.0001f)return;
  v->focus_x=x;v->focus_y=y;if(v->visible)gtk_gl_area_queue_render(GTK_GL_AREA(v->area));
}
void vehicle_3d_gl_area_set_tap_callback(Vehicle3DGlArea*v,Vehicle3DTapCallback callback,void* user_data){
  if(!v)return;v->tap_callback=callback;v->tap_user_data=user_data;
}
void vehicle_3d_gl_area_reset(Vehicle3DGlArea*v){
  vehicle_3d_gl_area_set_focus(v,0,0);vehicle_3d_gl_area_set_transform(v,-.38f,.08f,1.16f);
}
