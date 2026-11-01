// Both pools evaluate exactly the same endpoint and phase, once per vertex.
// Two ground centers per vec4 keep the uniform footprint bounded for WebGL2.
uniform float rain_time = 0.0;
uniform float rain_cycle_seconds = 1.1;
uniform int rain_site_count = 1;
uniform vec4 rain_sites[128];
uint rain_hash(uint x) {
 x ^= x >> 16u; x *= 0x7feb352du; x ^= x >> 15u;
 x *= 0x846ca68bu; return x ^ (x >> 16u);
}
vec4 rain_sample(vec4 custom) {
 float time = rain_time / max(rain_cycle_seconds,0.1) + custom.r;
 uint h = rain_hash(uint(custom.g) + uint(floor(time))*7919u + uint(custom.b*65535.0));
 int site = int(h % uint(max(rain_site_count,1)));
 vec4 pair = rain_sites[site/2];
 vec2 center = (site%2 == 0) ? pair.xy : pair.zw;
 vec2 jitter = vec2(float(rain_hash(h+1u)%1024u),float(rain_hash(h+2u)%1024u))/1023.0-vec2(0.5);
 return vec4(center+jitter*1.3,fract(time),custom.b);
}
