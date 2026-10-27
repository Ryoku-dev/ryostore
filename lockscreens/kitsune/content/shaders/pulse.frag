#version 440
// pulse — energy in the glass over the veiled ground.
// Filaments breathe; a surge front sweeps; crackle flares.
// The water shares this field. Uniforms: u_time seconds,
// u_surge / u_crackle envelopes, u_front surge position,
// u_src the ground, u_ripples[3] (xy origin, z birth,
// w strength), u_calm filament level, u_res resolution.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float u_time;
    float u_surge;
    float u_front;
    float u_crackle;
    float u_calm;
    vec2 u_click;
    float u_clickAge;
    float u_aspect;
};
layout(binding = 1) uniform sampler2D u_ground;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.55; }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;

    // ---- the water first: its slope field bends the ground sample
    float ct = u_clickAge;
    vec2 bend = vec2(0.0);
    float crestLight = 0.0;
    vec3 prismGlow = vec3(0.0);
    if (ct >= 0.0 && ct < 3.6) {
        vec2 dp = (uv - u_click) * vec2(u_aspect, 1.0);
        float cd = length(dp);
        vec2 rdir = cd > 0.0001 ? dp / cd : vec2(0.0);
        float wob = fbm(uv * 18.0 + u_click * 7.0) - 0.5;
        float d = cd + wob * 0.014 * smoothstep(0.0, 0.25, cd);
        float rad = 0.42 * pow(ct, 0.82);
        float env = exp(-ct * 1.0) * exp(-max(cd - rad, 0.0) * 3.0);
        float facing = dot(rdir, normalize(vec2(-0.55, -0.83))) * 0.5 + 0.5;
        float spec = 0.72 + 0.5 * facing;
        float slope = 0.0;
        for (int k = 0; k < 3; k++) {
            float rk = rad - float(k) * 0.055;
            if (rk < 0.0) continue;
            float amp = env * (k == 0 ? 1.0 : (k == 1 ? 0.40 : 0.18)) * spec;
            float x = (d - rk) * 34.0;
            slope += 2.0 * 34.0 * 34.0 * (d - rk) * exp(-x * x) * amp;
            prismGlow += vec3(exp(-pow((d - rk - 0.007) * 34.0, 2.0)),
                              exp(-pow((d - rk) * 34.0, 2.0)),
                              exp(-pow((d - rk + 0.007) * 34.0, 2.0))) * amp;
            crestLight += exp(-pow((d - rk) * 70.0, 2.0)) * amp;
        }
        // capillary shimmer riding inside the train
        float cap = sin(d * 230.0 - ct * 6.0) * 0.5 + 0.5;
        crestLight += cap * 0.05 * env * exp(-max(rad - d, 0.0) * 4.0);
        bend = vec2(rdir.x / u_aspect, rdir.y) * slope * 0.00013;
        prismGlow *= 0.5;
        crestLight *= 0.5;
    }
    vec3 ground = texture(u_ground, clamp(uv + bend, 0.001, 0.999)).rgb;

    // ---- the sleeping energy, over the (possibly bent) ground
    float drift = u_time * 0.014;
    float f = fbm(uv * vec2(9.0, 5.0) + vec2(drift, drift * 0.6));
    float vein = pow(clamp(1.0 - abs(2.0 * f - 1.0), 0.0, 1.0), 14.0);
    vec3 ecol = mix(vec3(0.55, 0.38, 1.0), vec3(0.25, 0.9, 1.0), fbm(uv * 3.0 + 7.0));
    float front = exp(-pow((uv.x - u_front) * 4.4, 2.0));
    float inten = u_calm + u_surge * front * 0.30 + u_crackle * 0.50;
    vec3 energy = ecol * vein * inten;
    energy += vec3(0.72, 0.62, 1.0) * u_crackle * 0.10 * (0.6 + 0.4 * noise(uv * 3.0 + u_time * 0.7));
    energy += prismGlow * (0.75 + 0.5 * vein) + vec3(0.92, 0.97, 1.0) * crestLight;

    fragColor = vec4(ground + energy, 1.0) * qt_Opacity;
}
