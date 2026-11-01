shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never;
uniform vec3 sun_direction = vec3(0.5,0.8,0.2);
uniform float ray_opacity = 0.0;
uniform float ray_time = 0.0;
uniform float ray_length = 9.0;
uniform float ray_width = 0.35;
uniform float ray_speed = 0.3;
varying float pulse;
void vertex() {
 vec3 right = normalize(INV_VIEW_MATRIX[0].xyz);
 // Keep the stylized shaft readable when looking nearly along the sun.
 vec3 view_direction = normalize(INV_VIEW_MATRIX[2].xyz);
 float projected = length(sun_direction-view_direction*dot(sun_direction,view_direction));
 vec3 axis = normalize(sun_direction+INV_VIEW_MATRIX[1].xyz*max(0.0,0.5-projected));
 VERTEX = right*VERTEX.x*ray_width + axis*UV.y*ray_length;
 pulse = 0.8+0.2*sin(ray_time*ray_speed+INSTANCE_CUSTOM.r*6.2831853);
}
void fragment() {
 float edge = pow(max(0.0,1.0-abs(UV.x*2.0-1.0)),1.5);
 float ends = sin(UV.y*3.14159265);
 ALBEDO = vec3(1.0,0.72,0.32);
 ALPHA = ray_opacity*edge*ends*pulse;
}
