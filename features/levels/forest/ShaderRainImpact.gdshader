shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
#include "ShaderRainCycle.gdshaderinc"
uniform float splash_size = 1.7;
uniform float splash_opacity = 0.75;
uniform float splash_variation = 0.25;
varying float opacity;
void vertex() {
 vec4 sample = rain_sample(INSTANCE_CUSTOM);
 float phase = clamp((sample.z-0.78)/0.22,0.0,1.0);
 float variation = mix(1.0-splash_variation,1.0+splash_variation,sample.w);
 VERTEX.xz *= (0.3+phase*1.5)*splash_size*variation;
 VERTEX.y *= 0.25;
 VERTEX += vec3(sample.x,0.028,sample.y);
 opacity = step(0.78,sample.z)*(1.0-phase)*splash_opacity*mix(0.8,1.0,sample.w);
}
void fragment() { ALBEDO=vec3(0.75,0.86,0.9); ALPHA=opacity; }
