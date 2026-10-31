shader_type spatial;

uniform vec4 terrain_color : source_color = vec4(0.4, 0.5, 0.3, 1.0);
uniform vec4 line_color : source_color = vec4(0.12, 0.17, 0.10, 1.0);
uniform float cell_size = 2.0;
uniform float line_width = 0.035;
uniform float world_seed = 2026.0;
uniform float terrain_health = 1.0;
uniform float variation_strength = 0.14;
varying vec3 world_position;

float hash_patch(vec2 p) {
 return fract(sin(dot(p, vec2(127.1, 311.7)) + world_seed * 0.137) * 43758.5453);
}

float patch_noise(vec2 p) {
 vec2 whole = floor(p);
 vec2 local = fract(p);
 vec2 blend = local * local * (3.0 - 2.0 * local);
 return mix(mix(hash_patch(whole), hash_patch(whole + vec2(1.0, 0.0)), blend.x),
            mix(hash_patch(whole + vec2(0.0, 1.0)), hash_patch(whole + vec2(1.0)), blend.x), blend.y);
}

void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
 vec2 grid_uv = world_position.xz / cell_size;
 vec2 cell = fract(grid_uv + 0.5);
 vec2 edge = min(cell, 1.0 - cell);
 float distance_to_edge = min(edge.x, edge.y);
 float aa = max(max(fwidth(grid_uv.x), fwidth(grid_uv.y)) * 0.6, 0.0001);
 float half_width = line_width / (2.0 * cell_size);
 float line = 1.0 - smoothstep(half_width - aa, half_width + aa, distance_to_edge);
 // Broad patches span several cells. Fine variation adds mottling without
 // textures, extra materials, or altering the climate's authoritative color.
 float broad = patch_noise(grid_uv * 0.29);
 float fine = patch_noise(grid_uv * 1.8);
 float variation = (broad - 0.5) * 1.4 + (fine - 0.5) * 0.35;
 vec3 ground = terrain_color.rgb * (1.0 + variation * variation_strength);
 float dirt = smoothstep(0.54, 0.75, broad) * min(variation_strength * 3.5, 0.7) * terrain_health;
 ground = mix(ground, vec3(0.43, 0.34, 0.23), dirt);
 ALBEDO = mix(ground, line_color.rgb, line);
 ROUGHNESS = 1.0;
}
