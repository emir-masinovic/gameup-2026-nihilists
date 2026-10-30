shader_type spatial;

uniform vec4 terrain_color : source_color = vec4(0.4, 0.5, 0.3, 1.0);
uniform vec4 line_color : source_color = vec4(0.12, 0.17, 0.10, 1.0);
uniform float cell_size = 2.0;
uniform float line_width = 0.035;
varying vec3 world_position;

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
 ALBEDO = mix(terrain_color.rgb, line_color.rgb, line);
 ROUGHNESS = 1.0;
}
