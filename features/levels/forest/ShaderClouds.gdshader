shader_type spatial;
render_mode unshaded,depth_prepass_alpha;
uniform vec2 travel = vec2(0.0);
uniform float cloud_heading = 0.0;
uniform float extent = 23.0;
uniform float altitude = 7.0;
uniform float cloud_scale = 1.5;
uniform float min_scale_variation = 0.7;
uniform float max_scale_variation = 1.5;
uniform float cloud_opacity = 0.7;
uniform float coverage = 4.0;
uniform float darkening = 0.0;
uniform float daylight = 1.0;
uniform vec2 rainbow_position = vec2(0.0);
uniform float rainbow_clearance = 0.0;
uniform vec2 player_screen_uv = vec2(-2.0);
uniform float screen_aspect = 1.0;
varying float visibility;
varying float shade;
void vertex() {
 vec2 original = MODEL_MATRIX[3].xz;
 vec2 center = mod(original*extent+travel+vec2(extent),vec2(extent*2.0))-vec2(extent);
 float edge = 1.0-smoothstep(extent-3.0,extent,max(abs(center.x),abs(center.y)));
 float gap = mix(1.0,smoothstep(4.0,8.0,distance(center,rainbow_position)),rainbow_clearance);
 visibility = smoothstep(INSTANCE_CUSTOM.r,INSTANCE_CUSTOM.r+1.0,coverage)*edge*gap;
 shade = INSTANCE_CUSTOM.a;
 // Stable local-axis proportions keep model identity while avoiding identical silhouettes.
 vec3 proportions = vec3(mix(0.92,1.08,INSTANCE_CUSTOM.b),mix(0.92,1.08,fract(INSTANCE_CUSTOM.b*7.31)),mix(1.06,0.94,INSTANCE_CUSTOM.b));
 VERTEX *= proportions;
 NORMAL = normalize(NORMAL/proportions);
 // Existing seeded custom.b provides stable +/-12-degree variety; no new RNG.
 float angle = cloud_heading+(INSTANCE_CUSTOM.b*2.0-1.0)*0.20943951;
 float c = cos(angle);
 float s = sin(angle);
 VERTEX.xz = vec2(c*VERTEX.x-s*VERTEX.z,s*VERTEX.x+c*VERTEX.z);
 NORMAL.xz = vec2(c*NORMAL.x-s*NORMAL.z,s*NORMAL.x+c*NORMAL.z);
 float seed_scale = clamp((INSTANCE_CUSTOM.g-0.8)/0.4,0.0,1.0);
 float low = min(min_scale_variation,max_scale_variation);
 float high = max(min_scale_variation,max_scale_variation);
 VERTEX *= cloud_scale*mix(low,high,seed_scale);
 VERTEX.xz += center-original;
 VERTEX.y += altitude+(INSTANCE_CUSTOM.b-0.5)*1.5;
}
void fragment() {
 float facet = 0.78+0.22*max(dot(normalize(NORMAL),normalize(vec3(-0.4,0.8,0.6))),0.0);
 ALBEDO = mix(vec3(0.96,0.98,1.0),vec3(0.3,0.34,0.42),darkening)*facet*shade*mix(0.32,1.0,daylight);
 // Preserve character readability when a cloud crosses the isometric sightline.
 float player_gap = smoothstep(0.035,0.1,length((SCREEN_UV-player_screen_uv)*vec2(screen_aspect,1.0)));
 ALPHA = cloud_opacity*visibility*player_gap;
}
