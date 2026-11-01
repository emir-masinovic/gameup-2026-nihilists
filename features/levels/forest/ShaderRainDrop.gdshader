shader_type spatial;
render_mode unshaded;
#include "ShaderRainCycle.gdshaderinc"
varying float drop_visible;
void vertex() {
 vec4 sample = rain_sample(INSTANCE_CUSTOM);
 drop_visible = 1.0-step(0.78,sample.z);
 VERTEX += vec3(sample.x,0.278+6.0*(1.0-min(sample.z/0.78,1.0)),sample.y);
}
void fragment() {
 if(drop_visible < 0.5) { discard; }
 ALBEDO = vec3(0.58,0.75,0.84);
}
