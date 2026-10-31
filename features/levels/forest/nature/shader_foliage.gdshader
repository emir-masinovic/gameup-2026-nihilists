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
    vec3 world = MODEL_MATRIX[3].xyz;
    float height = clamp(VERTEX.y / wind_height, 0.0, 1.0);
    float vigor = instance_health ? (0.3 + vitality * 0.7) : 1.0;
    if (instance_health) { VERTEX.y *= 0.4 + vitality * 0.6; }
    // A shared travelling field, with only a small seeded local phase offset.
    float phase = instance_health ? INSTANCE_CUSTOM.g * 0.45 : 0.0;
    float wave = sin(TIME * 1.65 - dot(world.xz, vec2(0.35, 0.26)) + phase);
    float gust = 0.65 + 0.35 * sin(TIME * 0.43 - dot(world.xz, vec2(0.08, 0.06)));
    vec3 direction = vec3(0.8, 0.0, 0.6);
    vec3 local_direction = vec3(dot(normalize(MODEL_MATRIX[0].xyz), direction), 0.0,
                                dot(normalize(MODEL_MATRIX[2].xyz), direction));
    VERTEX += local_direction * (0.35 + wave * 0.65) * gust * sway * height * height * vigor;
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
