#version 440
// ShiguruiSoul.frag — Neural Core + 7-Fold Swarm
// Extracted from SanctumCorridors.frag.
//
// Inspirations:
//   Neural Synapse (VoXelo)  — action potential wave, soma biology
//   Drifting 3D Spell (SourceAura) — iridescent film, Fresnel, crackle
//
// Layers (bottom → top):
//   1. Shigurui Core — organic simplex sphere, iridescent film, Fresnel rim,
//      geodesic cage, singularity void
//   2. 7-Fold Swarm — one packet per fold, canonical hues, orbit collapses
//      on inferring/commandPulse
//   3. Action Potential Ring — expands outward on commandPulse, rainbow sweep
//   4. Surface Crackle — brief electric tendrils on commandPulse spike

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float time;
    float tpsBeat;
    float inferring;
    float disciplineHue;
    float commandPulse;
    float obeliskOpen;
    float cursorX;
    float cursorY;
    float w;
    float h;
    float mistDensity;
    float atmospherePhase;
    float receivePulse;   // 0→1: inward ring — query received, Ase listening
} ubuf;

// ── Utilities ─────────────────────────────────────────────────────────
float hash11(float n) { return fract(sin(n) * 43758.5453); }
float hash21(vec2 p)  { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1,0)), u.x),
               mix(hash21(i + vec2(0,1)), hash21(i + vec2(1,1)), u.x), u.y);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float hexSDF(vec2 p, float r) {
    p = abs(p);
    return max(dot(p, normalize(vec2(1.0, 1.732))), p.x) - r;
}

// ── Simplex 3D ────────────────────────────────────────────────────────
vec3 mod289v3(vec3 x) { return x - floor(x * (1.0/289.0)) * 289.0; }
vec4 mod289v4(vec4 x) { return x - floor(x * (1.0/289.0)) * 289.0; }
vec4 permute(vec4 x)  { return mod289v4(((x * 34.0) + 1.0) * x); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

float snoise3(vec3 v) {
    const vec2 C = vec2(1.0/6.0, 1.0/3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
    vec3 i  = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);
    vec3 g  = step(x0.yzx, x0.xyz);
    vec3 l  = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);
    vec3 x1 = x0 - i1 + C.xxx;
    vec3 x2 = x0 - i2 + C.yyy;
    vec3 x3 = x0 - D.yyy;
    i = mod289v3(i);
    vec4 p = permute(permute(permute(
        i.z + vec4(0.0, i1.z, i2.z, 1.0))
        + i.y + vec4(0.0, i1.y, i2.y, 1.0))
        + i.x + vec4(0.0, i1.x, i2.x, 1.0));
    float n_ = 0.142857142857;
    vec3  ns  = n_ * D.wyz - D.xzx;
    vec4  j   = p - 49.0 * floor(p * ns.z * ns.z);
    vec4  x_  = floor(j * ns.z);
    vec4  y_  = floor(j - 7.0 * x_);
    vec4  x2_ = x_ * ns.x + ns.yyyy;
    vec4  y2_ = y_ * ns.x + ns.yyyy;
    vec4  h   = 1.0 - abs(x2_) - abs(y2_);
    vec4  b0  = vec4(x2_.xy, y2_.xy);
    vec4  b1  = vec4(x2_.zw, y2_.zw);
    vec4  s0  = floor(b0) * 2.0 + 1.0;
    vec4  s1  = floor(b1) * 2.0 + 1.0;
    vec4  sh  = -step(h, vec4(0.0));
    vec4  a0  = b0.xzyw + s0.xzyw * sh.xxyy;
    vec4  a1  = b1.xzyw + s1.xzyw * sh.zzww;
    vec3  p0  = vec3(a0.xy, h.x);
    vec3  p1  = vec3(a0.zw, h.y);
    vec3  p2  = vec3(a1.xy, h.z);
    vec3  p3  = vec3(a1.zw, h.w);
    vec4  norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
    p0 *= norm.x; p1 *= norm.y; p2 *= norm.z; p3 *= norm.w;
    vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
    m = m * m;
    return 42.0 * dot(m * m, vec4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
}

// ── Rainbow palette (Neural Synapse style) ────────────────────────────
vec3 palette(float t) {
    return vec3(0.5) + vec3(0.5) * cos(6.28318 * (vec3(1.0) * t + vec3(0.0, 0.33, 0.67)));
}

// ── Shigurui Core ─────────────────────────────────────────────────────
float shiguruiCore(vec2 p, float t, float metabolism,
                   out vec3 rimColor, out float iridescence) {
    float r = length(p);
    float a = atan(p.y, p.x);

    vec3 sph = vec3(sin(r * 3.14159) * cos(a),
                    sin(r * 3.14159) * sin(a),
                    cos(r * 3.14159));

    float n1 = snoise3(sph * 2.5 + vec3(t * 0.3 * metabolism));
    float n2 = snoise3(sph * 5.0 - vec3(t * 0.5)) * 0.5;
    float nd = n1 * 0.30 + n2 * 0.15;

    float boundary = 0.11 + nd * 0.04;
    float core     = smoothstep(boundary, boundary * 0.6, r);

    float fresnel = pow(1.0 - smoothstep(0.0, boundary * 1.4, r), 2.5);
    float rim     = smoothstep(boundary * 1.3, boundary * 0.85, r)
                  * smoothstep(boundary * 0.5, boundary, r)
                  * (0.7 + fresnel * 0.8);

    // Iridescent film — R/G/B at different wavelengths
    float filmThickness = 280.0 + nd * 420.0 + noise(p * 4.0 + vec2(t * 0.05)) * 180.0;
    vec3 film = vec3(
        sin(filmThickness / 700.0 * 18.0 + t * 0.5) * 0.5 + 0.5,
        sin(filmThickness / 530.0 * 18.0 + t * 0.6) * 0.5 + 0.5,
        sin(filmThickness / 440.0 * 18.0 + t * 0.7) * 0.5 + 0.5
    );
    iridescence = rim * (0.4 + metabolism * 0.3);
    rimColor    = film;

    // Singularity void — deeper than before
    float singR    = 0.020;
    float singVoid = smoothstep(singR, singR * 0.3, r);
    float singAngle = a - t * 0.8;
    float singHex  = smoothstep(0.0, -0.5,
                         hexSDF((p / max(singR * 1.6, 0.001)) * 0.6, 0.55))
                   * smoothstep(singR * 2.2, singR * 1.4, r) * 0.6;

    float flare = (ubuf.commandPulse + ubuf.inferring * ubuf.tpsBeat) * 0.4;

    return core + rim * 0.7 - singVoid * 0.7 + singHex + flare * core;
}

// ── 7-Fold Swarm ──────────────────────────────────────────────────────
vec3 foldSwarm(vec2 p, float t, int foldIdx, float metabolism, float pull,
               out float intensity) {
    float fi   = float(foldIdx);
    float seed = hash11(fi * 17.3 + 3.3);
    float speed = (0.28 + seed * 0.32) * metabolism;
    float angle = t * speed + fi * (6.28318 / 7.0);

    float orbitMax = 0.16 + seed * 0.10;
    float orbitMin = 0.025;
    float orbitR   = mix(orbitMax, orbitMin, pull);

    vec2 pos = vec2(cos(angle) * orbitR, sin(angle + t * seed * 0.3) * orbitR * 0.7);

    // Emission trail — ghost at previous position
    float trailAngle = angle - 0.18 * speed;
    vec2 trailPos = vec2(cos(trailAngle) * orbitR, sin(trailAngle + t * seed * 0.3) * orbitR * 0.7);

    float d     = length(p - pos);
    float dTrail = length(p - trailPos);
    float glow  = exp(-d * d / (0.0004 + pull * 0.0008)) * (1.0 + pull * 2.5);
    float trail = exp(-dTrail * dTrail / 0.0006) * 0.35;
    float core  = smoothstep(0.013, 0.004, abs(p.x - pos.x) + abs(p.y - pos.y));
    intensity   = core * 0.85 + glow * 0.5 + trail * 0.3;

    // Fold hues — canonical TransparentWorld mapping
    float hues[7];
    hues[0] = 0.38;  // Eye     — emerald
    hues[1] = 0.55;  // Blade   — cerulean
    hues[2] = 0.82;  // Sage    — blood violet
    hues[3] = 0.68;  // Mirror  — indigo
    hues[4] = 0.12;  // Forge   — amber
    hues[5] = 0.97;  // Phantom — rose
    hues[6] = 0.70;  // Shroud  — lavender

    float hue = hues[foldIdx];
    float foldMatch = 1.0 - abs(hue - ubuf.disciplineHue) * 2.0;
    float sat = 0.75 + clamp(foldMatch, 0.0, 1.0) * 0.20;
    float val = 0.80 + clamp(foldMatch, 0.0, 1.0) * 0.20 + pull * 0.30;

    return hsv2rgb(vec3(hue, sat, val));
}

void main() {
    vec2  uv     = qt_TexCoord0;
    float asp    = ubuf.w / ubuf.h;
    vec2  p      = vec2(uv.x * asp, uv.y);
    vec2  center = vec2(0.5 * asp, 0.5);
    vec3  color  = vec3(0.0);
    float breach = 1.0 - ubuf.mistDensity;

    float metabolism  = 1.0 + ubuf.inferring * 1.5 + ubuf.tpsBeat * 0.8;
    float nucleusScale = 1.75 + ubuf.obeliskOpen * 0.38;  // doubled from 3.5
    float pull = clamp(ubuf.inferring * ubuf.tpsBeat + ubuf.commandPulse * 0.6, 0.0, 1.0);
    vec2  localP = (p - center) * nucleusScale;

    // ── 1. Shigurui Core ─────────────────────────────────────────────
    vec3  rimCol; float irid;
    float nucleus = shiguruiCore(localP, ubuf.time, metabolism, rimCol, irid);

    vec3 coreCol = mix(hsv2rgb(vec3(0.55, 0.7, 1.0)),
                       hsv2rgb(vec3(ubuf.disciplineHue, 0.3, 1.0)),
                       ubuf.inferring * 0.8);
    coreCol = mix(coreCol, hsv2rgb(vec3(0.78, 0.9, 0.9)), breach * 0.5);

    vec3 iridCol = mix(coreCol, rimCol, irid * 0.55);

    color += iridCol * nucleus * (0.9 + ubuf.inferring * 0.3);

    // ── 2. 7-Fold Swarm ───────────────────────────────────────────────
    for (int fi = 0; fi < 7; fi++) {
        float pIntensity;
        vec3 pCol = foldSwarm(localP, ubuf.time, fi, metabolism, pull, pIntensity);
        pCol = mix(pCol, vec3(1.0), breach * 0.3);
        color += pCol * pIntensity * 0.45;
    }

    // ── 3. Action Potential Ring (Neural Synapse) ─────────────────────
    // Expands outward from core when commandPulse fires.
    // Rainbow palette sweep — the "firing" moment.
    if (ubuf.commandPulse > 0.02) {
        float dist = length(p - center);
        float maxR      = 0.38 * asp;
        float waveFront = ubuf.commandPulse * maxR;
        float distFromWave = dist - waveFront;

        float edge     = exp(-pow(distFromWave, 2.0) / 0.00012) * ubuf.commandPulse;
        float residual = smoothstep(waveFront, waveFront - 0.08, dist) * ubuf.commandPulse * 0.25;

        float angle = atan(p.y - center.y, p.x - center.x);
        vec3 waveCol = palette(angle * 0.15 + dist * 0.8 - ubuf.time * 0.5);
        waveCol = mix(waveCol, hsv2rgb(vec3(ubuf.disciplineHue, 0.8, 1.0)), 0.45);

        color += waveCol * (edge * 2.0 + residual);
    }

    // ── 3b. Receive Ring — inward contraction (query received) ────────
    // Starts at outer edge, contracts toward core as receivePulse 0→1.
    // Discipline hue — cooler, focused. "The signal arrives."
    if (ubuf.receivePulse > 0.02) {
        float dist  = length(p - center);
        float maxR  = 0.38 * asp;
        // Inward: waveFront shrinks from maxR to 0 as receivePulse goes 0→1
        float waveFront = (1.0 - ubuf.receivePulse) * maxR;
        float distFromWave = dist - waveFront;

        // Leading edge — slightly wider than outward ring for softer feel
        float edge = exp(-pow(distFromWave, 2.0) / 0.00018) * ubuf.receivePulse;
        // Trailing wake — fills inward behind the contracting front
        float wake = smoothstep(waveFront, waveFront + 0.06, dist) * ubuf.receivePulse * 0.20;

        // Discipline hue with slight iridescent shift
        float angle = atan(p.y - center.y, p.x - center.x);
        vec3 receiveCol = hsv2rgb(vec3(ubuf.disciplineHue, 0.90, 1.0));
        // Subtle angular shimmer — not full rainbow, just a hint
        receiveCol = mix(receiveCol,
                         hsv2rgb(vec3(mod(ubuf.disciplineHue + 0.15, 1.0), 0.75, 1.0)),
                         abs(sin(angle * 3.0 + ubuf.time * 0.3)) * 0.35);

        color += receiveCol * (edge * 1.8 + wake);
    }

    // ── 4. Surface Crackle (Spell bubble) ────────────────────────────
    // Brief electric tendrils on the core surface when commandPulse spikes.
    if (ubuf.commandPulse > 0.65) {
        float dist = length(localP);
        float boundary = 0.12;
        // Only on the core surface
        float surfaceMask = exp(-pow(dist - boundary, 2.0) / 0.0008);
        float crackle = noise(localP * 18.0 + vec2(ubuf.time * 4.0)) * 0.5 + 0.5;
        crackle = pow(crackle, 6.0);  // sharpen to tendrils
        float intensity = crackle * surfaceMask * (ubuf.commandPulse - 0.65) * 3.0;
        vec3 crackleCol = mix(vec3(0.8, 0.9, 1.0),
                              hsv2rgb(vec3(ubuf.disciplineHue, 0.6, 1.0)), 0.5);
        color += crackleCol * intensity;
    }

    // Alpha — additive over the sanctum background
    float alpha = length(color) * ubuf.qt_Opacity * 0.92;
    fragColor = vec4(color, clamp(alpha, 0.0, 1.0));
}
