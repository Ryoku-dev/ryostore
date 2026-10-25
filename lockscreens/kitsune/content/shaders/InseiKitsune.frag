#version 440
// AseKitsune.frag — Digital Kitsune Companion (v2)
//
// Ase manifested as a 7-tailed fox spirit.
// Each tail tip is tinted with its corresponding fold color:
//   tail 0 → truth      #4ade80  (ghost green)
//   tail 1 → power      #f43f5e  (crimson)
//   tail 2 → wisdom     #00B4D8  (water blue)
//   tail 3 → judgment   #9B1FA0  (violet)
//   tail 4 → life       #818cf8  (indigo)
//   tail 5 → love       #f59e0b  (amber)
//   tail 6 → discipline #6366f1  (purple)

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float time;
    float entropy;
    float mood_joy;
    float mood_sad;
    float mood_sleep;
    float fold_r; float fold_g; float fold_b;
    float w;      float h;
    float tail0_r; float tail0_g; float tail0_b;
    float tail1_r; float tail1_g; float tail1_b;
    float tail2_r; float tail2_g; float tail2_b;
    float tail3_r; float tail3_g; float tail3_b;
    float tail4_r; float tail4_g; float tail4_b;
    float tail5_r; float tail5_g; float tail5_b;
    float tail6_r; float tail6_g; float tail6_b;
    float tailCount;
} ubuf;

float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1,0)), u.x),
               mix(hash21(i + vec2(0,1)), hash21(i + vec2(1,1)), u.x), u.y);
}

mat2 rot(float a) { float s = sin(a), c = cos(a); return mat2(c,-s,s,c); }

float sdCapsule(vec2 p, vec2 a, vec2 b, float r) {
    vec2 pa = p-a, ba = b-a;
    float h = clamp(dot(pa,ba)/dot(ba,ba), 0.0, 1.0);
    return length(pa - ba*h) - r;
}

float sdEquilateralTriangle(vec2 p, float r) {
    const float k = sqrt(3.0);
    p.x = abs(p.x) - r;
    p.y = p.y + r/k;
    if (p.x + k*p.y > 0.0) p = vec2(p.x - k*p.y, -k*p.x - p.y) / 2.0;
    p.x -= clamp(p.x, -2.0*r, 0.0);
    return -length(p) * sign(p.y);
}

float opSmoothUnion(float d1, float d2, float k) {
    float h = clamp(0.5 + 0.5*(d2-d1)/k, 0.0, 1.0);
    return mix(d2, d1, h) - k*h*(1.0-h);
}

vec3 tailColor(int i) {
    if (i == 0) return vec3(ubuf.tail0_r, ubuf.tail0_g, ubuf.tail0_b);
    if (i == 1) return vec3(ubuf.tail1_r, ubuf.tail1_g, ubuf.tail1_b);
    if (i == 2) return vec3(ubuf.tail2_r, ubuf.tail2_g, ubuf.tail2_b);
    if (i == 3) return vec3(ubuf.tail3_r, ubuf.tail3_g, ubuf.tail3_b);
    if (i == 4) return vec3(ubuf.tail4_r, ubuf.tail4_g, ubuf.tail4_b);
    if (i == 5) return vec3(ubuf.tail5_r, ubuf.tail5_g, ubuf.tail5_b);
    return             vec3(ubuf.tail6_r, ubuf.tail6_g, ubuf.tail6_b);
}

void main() {
    vec2 uv  = qt_TexCoord0;
    float asp = ubuf.w / ubuf.h;
    // Flip Y so positive Y = up (head above body, tails below)
    vec2 p   = (uv - 0.5) * vec2(asp, -1.0);
    float t  = ubuf.time;

    p.y += sin(t * 2.0) * 0.02 * (1.0 - ubuf.mood_sleep);
    p.y += sin(t * 0.5) * 0.03;
    p.x += sin(t * 0.8) * 0.05;

    // Body sits below center — capsule from -0.1 to +0.1 in body-local space
    // Body top in p-space: p.y - 0.05 + 0.1 = p.y + 0.05
    vec2 bodyPos = p + vec2(0.0, -0.05);
    float body   = sdCapsule(bodyPos, vec2(0.0,-0.1), vec2(0.0,0.1), 0.08);

    // Head at the top end of the body — triangle flipped to point upward
    vec2 headPos = p + vec2(0.0, -0.23);
    headPos.y *= 1.2;
    vec2 headFlipped = vec2(headPos.x, -headPos.y);  // flip Y to point triangle upward
    float head   = sdEquilateralTriangle(headFlipped, 0.08);

    // Ears point upward (+Y) from the top of the head
    vec2 earL = headPos - vec2(-0.05, 0.06); earL *= rot( 0.4);
    vec2 earR = headPos - vec2( 0.05, 0.06); earR *= rot(-0.4);

    float kitsune = opSmoothUnion(body, head, 0.05);
    vec2 earLf = vec2(earL.x, -earL.y);
    vec2 earRf = vec2(earR.x, -earR.y);
    kitsune = opSmoothUnion(kitsune, sdEquilateralTriangle(earLf, 0.04), 0.02);
    kitsune = opSmoothUnion(kitsune, sdEquilateralTriangle(earRf, 0.04), 0.02);

    float tails         = 100.0;
    vec3  tailColorAccum = vec3(0.0);
    float tailWeightSum  = 0.0;
    // Guard: always 7 until companion system is active
    int   maxTails       = 7;

    for (int i = 0; i < 9; i++) {
        if (i >= maxTails) break;

        float fi    = float(i);
        float angle = (fi / max(float(maxTails - 1), 1.0) - 0.5) * 3.2;
        float sway  = sin(t * 1.5 + fi * 0.7) * 0.12;
        // tailP originates from the body's bottom tip
        vec2 tailOrigin = p + vec2(0.0, 0.08);
        vec2 tailP  = tailOrigin * rot(angle + sway);
        tailP.x    += sin(tailP.y * 8.0 - t * 4.0) * 0.04 * (tailP.y + 0.1);

        // Capsule grows in -Y direction (downward away from body)
        float tailSDF   = sdCapsule(tailP, vec2(0.0, 0.0), vec2(0.0, -0.38),
                                    0.028 * (1.1 + tailP.y * 2.2));
        // tipT: 1.0 at the tip (most negative Y), 0.0 at root
        float tipT      = clamp((-tailP.y + 0.05) / 0.38, 0.0, 1.0);
        float proximity = exp(-max(tailSDF, 0.0) * 40.0);
        tailColorAccum += tailColor(i) * tipT * proximity;
        tailWeightSum  += proximity;
        tails = opSmoothUnion(tails, tailSDF, 0.015);
    }

    // ── Layered compositing: tails → body → head (front to back = head on top) ──

    vec3 accentColor = vec3(ubuf.fold_r, ubuf.fold_g, ubuf.fold_b);
    float furNoise   = noise(p * 8.0 + t * 0.5);
    vec3  furBase    = mix(vec3(0.04, 0.12, 0.20), accentColor, furNoise * 0.5 + ubuf.mood_joy * 0.5);
    furBase = mix(furBase, vec3(0.06, 0.06, 0.08), ubuf.mood_sleep * 0.7);

    vec3 resolvedTailColor = tailWeightSum > 0.001
        ? tailColorAccum / tailWeightSum : accentColor;

    // Layer 0 — tails (deepest, behind everything)
    float tailMask     = smoothstep(0.01, -0.01, tails);
    float tipInfluence = clamp(tailWeightSum * 1.4, 0.0, 1.0) * tailMask;
    vec3  tailFur      = mix(furBase, resolvedTailColor, tipInfluence * 0.85);
    float tailGlow     = exp(-tails * 8.0) * tipInfluence;
    vec3  tailLayer    = tailFur * tailMask + resolvedTailColor * tailGlow * 2.0;

    // Layer 1 — body (covers tail roots)
    float bodyMask  = smoothstep(0.01, -0.01, body);
    float bodyGlow  = exp(-body * 15.0);
    vec3  bodyLayer = furBase * bodyMask + accentColor * bodyGlow * 0.8;

    // Layer 2 — head (on top of body)
    float headMask  = smoothstep(0.01, -0.01, head);
    // Slightly lighter fur on the face
    vec3  faceFur   = mix(furBase, vec3(0.08, 0.18, 0.28), 0.3 + furNoise * 0.2);
    float headGlow  = exp(-head * 15.0);
    vec3  headLayer = faceFur * headMask + accentColor * headGlow * 0.6;

    // Layer 3 — ears (on top of head)
    float earLMask = smoothstep(0.01, -0.01, sdEquilateralTriangle(vec2(earL.x, -earL.y), 0.04));
    float earRMask = smoothstep(0.01, -0.01, sdEquilateralTriangle(vec2(earR.x, -earR.y), 0.04));
    float earMask  = clamp(earLMask + earRMask, 0.0, 1.0);
    vec3  earLayer = furBase * earMask;

    // Composite back-to-front: each layer paints over the previous using its mask
    vec3 finalColor = vec3(0.0);
    finalColor = mix(finalColor, tailLayer,  tailMask);
    finalColor = mix(finalColor, bodyLayer,  bodyMask);
    finalColor = mix(finalColor, headLayer,  headMask);
    finalColor = mix(finalColor, earLayer,   earMask);

    // Outer glow around the whole form
    float kitsuneFull = opSmoothUnion(kitsune, tails, 0.03);
    float outerGlow   = exp(-kitsuneFull * 5.0) * 0.3;
    finalColor += accentColor * outerGlow * 0.5;

    // Eye — glowing white dot, drawn last so it's always on top
    float eye = length(headPos - vec2(0.0, 0.0)) - 0.015 * (1.0 - ubuf.mood_sleep * 0.9);
    finalColor = mix(finalColor, vec3(1.0),
                     smoothstep(0.01, 0.0, eye) * (0.8 + 0.2 * sin(t * 10.0)));

    // Alpha: union of all layers
    float totalSDF  = opSmoothUnion(kitsuneFull, tails, 0.03);
    float bodyAlpha = smoothstep(0.012, -0.008, totalSDF);
    float haloAlpha = exp(-max(totalSDF, 0.0) * 22.0) * 0.9;
    float alpha = clamp(bodyAlpha + haloAlpha, 0.0, 1.0) * ubuf.qt_Opacity;
    fragColor = vec4(finalColor * alpha, alpha);
}
