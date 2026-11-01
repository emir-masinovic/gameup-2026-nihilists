shader_type spatial;
render_mode cull_disabled;
uniform vec4 leaf_color : source_color = vec4(0.16, 0.38, 0.20, 1.0);
uniform bool bare = false;
uniform float canopy_density = 1.0;
varying vec3 leaf_position;
uniform bool instance_health = false;
uniform bool blade_grass = false;
uniform float view_thickening : hint_range(0.0, 0.6) = 0.0;
uniform bool spatial_wind_enabled = false;
uniform sampler2D wind_field : repeat_enable, filter_linear;
uniform float lod_straighten : hint_range(0.0,1.0) = 0.0;
varying float blade_height;
varying vec3 blade_tint;
varying float vitality;
uniform float sway = 0.025;
uniform float wind_height = 1.6;
uniform vec2 wind_direction = vec2(0.8,0.6);
uniform float wind_strength = 0.55;
uniform float wind_deformation = 1.0;
uniform float gust_strength = 0.25;
uniform float gust_speed = 1.0;
uniform float wind_time = 0.0;
uniform bool shelter_enabled = false;
uniform vec4 wind_exposure[73];
uniform vec2 shelter_origin = vec2(-16.0);
void vertex() {
    blade_height = UV.y;
    float occlusion = blade_grass ? INSTANCE_CUSTOM.b : 0.0;
    float root_shade = mix(0.88,0.38,occlusion);
    float top = mix(smoothstep(0.0,0.95,UV.y),UV.y,lod_straighten);
    float hue = fract(INSTANCE_CUSTOM.g*17.31);
    vec3 variation = mix(vec3(0.94,0.99,0.88),vec3(1.03,1.01,0.98),hue);
    blade_tint = mix(vec3(root_shade),vec3(1.03,1.07,0.94),top)*variation;
    vitality = INSTANCE_CUSTOM.r;
    leaf_position = VERTEX;
    vec3 world = MODEL_MATRIX[3].xyz;
    if (blade_grass) {
        vec3 blade_axis = vec3(COLOR.r*2.0-1.0,0.0,COLOR.g*2.0-1.0);
        vec3 blade_side = cross(blade_axis,vec3(0.0,1.0,0.0));
        vec3 straight = vec3(0.0,UV.y*0.5,0.0)+blade_axis*(0.03+UV2.y)*UV.y+blade_side*(UV.x*2.0-1.0)*(1.0-UV.y)*UV2.x;
        VERTEX = mix(VERTEX,straight,lod_straighten);
        NORMAL = normalize(mix(NORMAL,vec3(0.0,1.0,0.0),lod_straighten));
    }
    float height = clamp(VERTEX.y / wind_height, 0.0, 1.0);
    float vigor = instance_health ? (0.3 + vitality * 0.7) : 1.0;
    if (blade_grass) {
        float lean = fract(INSTANCE_CUSTOM.g*13.17+COLOR.b*0.371)-0.5;
        VERTEX.xz += (COLOR.rg*2.0-1.0)*lean*0.06*mix(height*height,height,lod_straighten);
    }
    if (instance_health) { VERTEX.y *= 0.4 + vitality * 0.6; }
    // A shared travelling field, with only a small seeded local phase offset.
    float phase = instance_health ? INSTANCE_CUSTOM.g * 0.45 : 0.0;
    float along_wind = dot(world.xz, wind_direction);
    float wave;
    float gust;
    vec2 field_direction = wind_direction;
    if (blade_grass && spatial_wind_enabled) {
        vec2 flow_uv = world.xz * 0.025 - wind_direction * wind_time * gust_speed * 0.012;
        float broad = textureLod(wind_field,flow_uv,0.0).r;
        float detail = textureLod(wind_field,world.xz*0.11-wind_direction*wind_time*gust_speed*0.026+vec2(0.37,0.61),0.0).r;
        wave = clamp((broad-0.5)*2.0+(detail-0.5)*0.4,-1.0,1.0);
        gust = clamp(1.0+(broad-0.5)*2.0*gust_strength,0.25,1.75);
        field_direction = normalize(wind_direction+vec2(-wind_direction.y,wind_direction.x)*(detail-0.5)*0.3);
    }
    else {
        wave = sin(wind_time * 1.65 - along_wind * 0.44 + phase);
        gust = 0.75 + 0.25 * sin(wind_time * 0.43 - along_wind * 0.1);
    }
    vec3 direction = vec3(field_direction.x,0.0,field_direction.y);
    vec3 local_direction = vec3(dot(normalize(MODEL_MATRIX[0].xyz), direction), 0.0,
                                dot(normalize(MODEL_MATRIX[2].xyz), direction));
    ivec2 cell = ivec2(floor((world.xz-shelter_origin)/2.0+vec2(0.5)));
    int index = clamp(cell.y*17+cell.x,0,288);
    float exposure = shelter_enabled ? wind_exposure[index/4][index%4] : 1.0;
    float root_weight = mix(height*height,height,lod_straighten);
    float bend = (0.6+wave*0.4)*gust*wind_strength*1.8*sway*root_weight*vigor;
    if (blade_grass) {
        // A bounded visual response; shelter applies after the cap, including debug extremes.
        float response = pow(clamp(wind_strength,0.0,3.0),1.35);
        bend = min((0.65+wave*0.35)*gust*response*1.8*sway*wind_deformation*root_weight*vigor,0.38*root_weight);
    }
    VERTEX += local_direction * exposure * bend;
    if (blade_grass && view_thickening > 0.0) {
        vec3 blade_axis = normalize(vec3(COLOR.r*2.0-1.0,0.0,COLOR.g*2.0-1.0));
        vec3 face = normalize((MODEL_MATRIX*vec4(blade_axis,0.0)).xyz);
        vec3 view = PROJECTION_MATRIX[3][3] > 0.5 ? INV_VIEW_MATRIX[2].xyz : normalize(CAMERA_POSITION_WORLD-world);
        float facing = abs(dot(face,view));
        float edge = (1.0-facing)*smoothstep(0.02,0.25,facing);
        vec3 right_local = normalize(vec3(MODELVIEW_MATRIX[0].x,MODELVIEW_MATRIX[1].x,MODELVIEW_MATRIX[2].x));
        VERTEX += right_local * (UV.x*2.0-1.0) * 0.05 * view_thickening * edge * sin(UV.y*3.14159265) * (1.0-lod_straighten);
    }
}
void fragment() {
    if (bare) { discard; }
    // Stable model-space clusters: thinning never crawls with wind or camera.
    if (!instance_health) {
        float cluster = fract(sin(dot(floor(leaf_position * 7.0), vec3(12.9898,78.233,37.719))) * 43758.5453);
        if (cluster > canopy_density) { discard; }
    }
    vec3 plant_color = mix(vec3(0.46, 0.25, 0.08), vec3(0.67, 0.58, 0.17), smoothstep(0.05, 0.5, vitality));
    plant_color = mix(plant_color, leaf_color.rgb, smoothstep(0.45, 0.9, vitality));
    ALBEDO = instance_health ? plant_color : leaf_color.rgb;
    if (blade_grass) {
        if (!FRONT_FACING) { NORMAL = -NORMAL; }
        // Real vitality approximates dense-cover root occlusion; tips stay soft.
        ALBEDO *= blade_tint;
    }
    ROUGHNESS = 1.0;
    METALLIC = 0.0;
}
