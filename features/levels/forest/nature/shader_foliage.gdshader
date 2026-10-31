shader_type spatial;
render_mode cull_disabled;
uniform vec4 leaf_color : source_color = vec4(0.16, 0.38, 0.20, 1.0);
uniform bool bare = false;
uniform float canopy_density = 1.0;
varying vec3 leaf_position;
uniform bool instance_health = false;
varying float vitality;
uniform float sway = 0.025;
uniform float wind_height = 1.6;
void vertex() {
    vitality = INSTANCE_CUSTOM.r;
    leaf_position = VERTEX;
    vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float tip = smoothstep(0.0, wind_height, VERTEX.y);
    VERTEX.x += sin(TIME * 1.35 + world.x * 0.65 + world.z * 0.45) * sway * tip;
    VERTEX.z += cos(TIME * 1.05 + world.z * 0.6) * sway * tip * 0.55;
}
void fragment() {
    if (bare) { discard; }
    // Stable model-space clusters: thinning never crawls with wind or camera.
    float cluster = fract(sin(dot(floor(leaf_position * 7.0), vec3(12.9898,78.233,37.719))) * 43758.5453);
    if (!instance_health && cluster > canopy_density) { discard; }
    vec3 plant_color = mix(vec3(0.46, 0.25, 0.08), vec3(0.67, 0.58, 0.17), smoothstep(0.05, 0.5, vitality));
    plant_color = mix(plant_color, leaf_color.rgb, smoothstep(0.45, 0.9, vitality));
    ALBEDO = instance_health ? plant_color : leaf_color.rgb;
    ROUGHNESS = 1.0;
    METALLIC = 0.0;
}
