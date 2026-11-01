shader_type spatial;
render_mode cull_disabled;
uniform float visual_time = 0.0;
uniform bool branch = false;
uniform bool wetlands = false;
varying float vigor;
varying vec3 asset_tint;
void vertex() {
 asset_tint = COLOR.rgb;
 float phase = clamp((visual_time-INSTANCE_CUSTOM.b)/2.5,0.0,1.0);
 vigor = mix(INSTANCE_CUSTOM.r,INSTANCE_CUSTOM.g,phase);
 float growth = branch ? 1.0 : smoothstep(0.04,0.22,vigor)*mix(0.5,1.0,vigor);
 if (!branch) {
  VERTEX.x += VERTEX.y*(1.0-vigor)*0.35;
  VERTEX.y *= mix(0.4,1.0,vigor);
 }
 VERTEX *= growth*INSTANCE_CUSTOM.a;
}
void fragment() {
 float grey = dot(asset_tint,vec3(0.299,0.587,0.114));
 vec3 faded = mix(vec3(grey),vec3(0.55,0.43,0.21),0.6);
 if (branch) {
  vec3 wood = mix(asset_tint,vec3(0.3,0.22,0.12),0.75);
  ALBEDO = mix(vec3(0.63,0.56,0.43),wood*(wetlands ? 0.7 : 0.9),vigor);
 } else {
  ALBEDO = mix(faded,asset_tint,smoothstep(0.15,0.85,vigor));
 }
 ROUGHNESS = 1.0;
}
