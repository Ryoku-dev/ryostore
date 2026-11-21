#version 440
// Liquid glass for Dynamic Island controls.
//
// Build: qsb --qt6 -o liquidglass.frag.qsb liquidglass.frag   (tools/build-shaders.sh)
//
// The control is a slab of curved glass lying on top of a backdrop texture
// (whatever the island draws underneath it: black, album art, a card):
//
//   1. A rounded-rectangle signed distance field gives every pixel its depth
//      inside the glass and the direction of the nearest edge.
//   2. A circular bevel turns that depth into a surface normal: flat in the
//      middle, steep at the rim.
//   3. Snell's law (n = 1.52) bends the view ray through the normal, which
//      shifts where the backdrop is sampled. The rim pulls content inwards,
//      so edges magnify the way a real lens does.
//   4. The shifted backdrop is read through a small spiral blur (frost),
//      with the red and blue channels split slightly at the rim (dispersion).
//   5. Vibrancy, a milky lift, an optional tint, a soft top sheen, edge
//      absorption and a specular rim lit from the top left finish it off.
//
// With no backdrop (hasSrc = 0) the surface colour stands in for it, so the
// glass still reads as glass on a plain black island.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;     // whole effect item in px (glass + pad on every side)
    vec2 srcOrigin;    // the effect item's top-left inside the backdrop texture, px
    vec2 srcSize;      // backdrop texture size, px
    vec4 base;         // the surface the glass sits on
    vec4 tint;         // tint colour (alpha scales tintAmt)
    float pad;         // room around the glass for its shadow, px
    float radius;      // corner radius, px
    float bezel;       // width of the curved rim, px
    float refraction;  // how far the rim shifts the backdrop, px
    float blur;        // frost blur radius, px
    float frost;       // milky lift, 0..1
    float dispersion;  // chromatic split at the rim, 0..1
    float rim;         // specular rim strength
    float tintAmt;     // 0..1
    float hasSrc;      // 1 when a backdrop texture is bound
    float light;       // 0..1 hover / press brightening
    float shadow;      // drop shadow strength
};

layout(binding = 1) uniform sampler2D src;

float sdRoundBox(vec2 p, vec2 h, float r)
{
    vec2 q = abs(p) - h + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float hash(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec3 backdrop(vec2 px, float lod)
{
    vec2 uv = (px + srcOrigin) / srcSize;
    vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
    vec4 s = textureLod(src, clamp(uv, vec2(0.0), vec2(1.0)), lod);
    vec3 c = s.rgb + base.rgb * (1.0 - s.a);           // premultiplied, over the surface
    return mix(base.rgb, c, inside.x * inside.y);
}

vec3 frosted(vec2 px, vec2 disp, float r)
{
    if (hasSrc < 0.5)
        return base.rgb;
    const int TAPS = 10;
    float lod = clamp(log2(max(r * 0.6, 1.0)), 0.0, 5.0);
    float rot = hash(gl_FragCoord.xy) * 6.2831853;
    vec3 acc = vec3(0.0);
    float wsum = 0.0;
    for (int i = 0; i < TAPS; ++i) {
        float fi = float(i) + 0.5;
        float k = sqrt(fi / float(TAPS));
        float a = fi * 2.39996323 + rot;
        vec2 o = vec2(cos(a), sin(a)) * k * r;
        float w = exp(-2.2 * k * k);
        vec3 c;
        c.r = backdrop(px + o + disp * (1.0 + dispersion), lod).r;
        c.g = backdrop(px + o + disp, lod).g;
        c.b = backdrop(px + o + disp * (1.0 - dispersion), lod).b;
        acc += c * w;
        wsum += w;
    }
    return acc / wsum;
}

void main()
{
    vec2 p = qt_TexCoord0 * itemSize;
    vec2 gs = itemSize - 2.0 * pad;
    vec2 hs = gs * 0.5;
    vec2 q = p - pad - hs;
    float r = min(radius, min(hs.x, hs.y));

    float d = sdRoundBox(q, hs, r);
    float cov = clamp(0.5 - d, 0.0, 1.0);

    // soft contact shadow, only outside the glass
    float sd = sdRoundBox(q - vec2(0.0, pad * 0.3), hs, r);
    float sh = shadow * 0.32 * (1.0 - smoothstep(-1.0, max(pad, 1.0), sd));
    if (d > 0.75) {
        fragColor = vec4(0.0, 0.0, 0.0, sh) * qt_Opacity;
        return;
    }

    // depth inside the glass and the outward edge direction
    float t = max(-d, 0.0);
    vec2 e = vec2(0.5, 0.0);
    vec2 g = vec2(sdRoundBox(q + e.xy, hs, r) - sdRoundBox(q - e.xy, hs, r),
                  sdRoundBox(q + e.yx, hs, r) - sdRoundBox(q - e.yx, hs, r));
    g = length(g) > 1e-5 ? normalize(g) : vec2(0.0, -1.0);

    // circular bevel: flat plateau, steep rim
    float bz = max(bezel, 1.0);
    float u = clamp(t / bz, 0.0, 1.0);
    float om = 1.0 - u;
    float slope = min(om / sqrt(max(1.0 - om * om, 1e-3)), 6.0);
    vec3 n = normalize(vec3(g * slope * 0.65, 1.0));

    // refraction through the curved surface
    vec3 rd = refract(vec3(0.0, 0.0, -1.0), n, 1.0 / 1.52);
    vec2 disp = rd.xy / max(-rd.z, 0.3) * refraction;

    float blurR = blur * mix(0.55, 1.0, u);
    vec3 col = frosted(p, disp, blurR);

    // vibrancy, frost, tint
    float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(vec3(l), col, 1.35);
    col = mix(col, vec3(1.0), clamp(frost, 0.0, 1.0));
    col = mix(col, tint.rgb, clamp(tintAmt * tint.a, 0.0, 1.0));

    // depth: soft sheen at the top, light absorbed towards the rim
    float ty = clamp((q.y + hs.y) / max(gs.y, 1.0), 0.0, 1.0);
    col += (1.0 - ty) * (1.0 - ty) * (0.07 + 0.06 * light);
    col *= 1.0 - 0.12 * exp(-t / (bz * 0.5));

    // specular rim, lit from the top left; a weaker bounce on the opposite side
    vec2 L = normalize(vec2(-0.6, -0.8));
    float f = dot(g, L);
    float spec = pow(max(f, 0.0), 2.0) + 0.45 * pow(max(-f, 0.0), 3.0);
    float hair = exp(-t / 0.85);
    float halo = exp(-t / (bz * 0.6));
    col += rim * (hair * (0.10 + 0.95 * spec) + halo * 0.20 * spec) * (0.9 + 0.6 * light);

    // fine grain so the frost reads as a material, not a gradient
    col += (hash(gl_FragCoord.xy * 1.7) - 0.5) * 0.018;
    col = clamp(col, 0.0, 1.0);

    float a = cov + sh * (1.0 - cov);
    fragColor = vec4(col * cov, a) * qt_Opacity;
}
