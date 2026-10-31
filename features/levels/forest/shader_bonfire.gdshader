shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float animation_time = 0.0;
varying float flame_height;

void vertex() {
 flame_height = clamp((VERTEX.y + 0.55) / 1.1, 0.0, 1.0);
 float phase = (MODEL_MATRIX[3].x + MODEL_MATRIX[3].z) * 2.7;
 float flicker = sin(animation_time * 7.0 + phase);
 VERTEX.y += flame_height * (0.1 * flicker + 0.06 * sin(animation_time * 11.0 + phase));
 VERTEX.x += flame_height * flame_height * 0.13 * sin(animation_time * 5.0 + phase);
 VERTEX.z += flame_height * flame_height * 0.09 * cos(animation_time * 6.0 + phase);
}

void fragment() {
 vec3 gold = vec3(1.0, 0.77, 0.22);
 vec3 orange = vec3(0.95, 0.23, 0.035);
 ALBEDO = mix(gold, orange, smoothstep(0.05, 1.0, flame_height));
 EMISSION = ALBEDO * 0.35;
}
