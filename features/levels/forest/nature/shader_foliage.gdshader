shader_type spatial;
render_mode cull_disabled;
uniform vec4 leaf_color : source_color = vec4(0.16, 0.38, 0.20, 1.0);
uniform bool bare = false;
uniform float sway = 0.025;
uniform float wind_height = 1.6;
void vertex() {
    vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float tip = smoothstep(0.0, wind_height, VERTEX.y);
    VERTEX.x += sin(TIME * 1.35 + world.x * 0.65 + world.z * 0.45) * sway * tip;
    VERTEX.z += cos(TIME * 1.05 + world.z * 0.6) * sway * tip * 0.55;
}
void fragment() {
    if (bare) { discard; }
    ALBEDO = leaf_color.rgb;
    ROUGHNESS = 1.0;
    METALLIC = 0.0;
}
