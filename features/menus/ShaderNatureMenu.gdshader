shader_type canvas_item;
// Texture-free presentation: two value-noise samples and two silhouette layers.
float hash_point(vec2 p) {
 vec3 h = fract(vec3(p.xyx)*0.1031);
 h += dot(h,h.yzx+33.33);
 return fract((h.x+h.y)*h.z);
}
float soft_noise(vec2 p) {
 vec2 cell = floor(p);
 vec2 f = fract(p);f = f*f*(3.0-2.0*f);
 return mix(mix(hash_point(cell),hash_point(cell+vec2(1.0,0.0)),f.x),mix(hash_point(cell+vec2(0.0,1.0)),hash_point(cell+vec2(1.0)),f.x),f.y);
}
float trees(vec2 p,float spacing,float base,float height,float seed) {
 float column = floor(p.x/spacing);
 float local_x = abs(fract(p.x/spacing)-0.5);
 float top = base-height*mix(0.7,1.2,hash_point(vec2(column,seed)));
 float level = (p.y-top)/(base-top);
 float width = (0.12+0.3*fract(level*3.0))*smoothstep(0.0,0.2,level);
 float canopy = (1.0-smoothstep(width,width+0.025,local_x))*smoothstep(0.0,0.015,level)*(1.0-smoothstep(0.97,1.0,level));
 float trunk = (1.0-smoothstep(0.025,0.045,local_x))*smoothstep(top,base,p.y);
 return max(max(canopy,trunk),smoothstep(base,base+0.02,p.y));
}
void fragment() {
 float aspect = SCREEN_PIXEL_SIZE.y/SCREEN_PIXEL_SIZE.x;
 vec2 p = vec2((UV.x-0.5)*aspect,UV.y);
 float drift = TIME*0.006;
 float organic = soft_noise(p*3.0+vec2(drift,-drift*0.4))*0.7+soft_noise(p*6.0-vec2(drift*0.6,0.0))*0.3;
 vec3 forest = mix(vec3(0.018,0.04,0.033),vec3(0.065,0.135,0.09),organic*(1.0-UV.y*0.4));
 vec2 sun = p-vec2(aspect*0.28,0.24);
 float glow = exp(-dot(sun,sun)*5.0);
 forest += vec3(0.13,0.12,0.045)*glow*(0.8+organic*0.2);
 float breeze = sin(TIME*0.12)*0.003;
 float distant = trees(vec2(p.x+2.0+breeze,UV.y),0.17,0.94,0.32,7.0);
 forest = mix(forest,vec3(0.028,0.065,0.049),distant*0.85);
 float near = trees(vec2(p.x+3.1+breeze*0.5,UV.y),0.23,1.02,0.38,19.0);
 forest = mix(forest,vec3(0.012,0.031,0.025),near);
 // Keep the unchanged central button column quiet and high-contrast.
 float center = 1.0-smoothstep(0.12,0.35,abs(UV.x-0.5));
 forest *= 1.0-center*0.25;
 float vignette = clamp(1.0-length((UV-0.5)*vec2(0.8,0.6))*0.5,0.6,1.0);
 COLOR = vec4(forest*vignette,1.0);
}
