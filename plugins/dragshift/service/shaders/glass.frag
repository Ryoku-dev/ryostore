#version 440
// DragShift's liquid glass (dragshift/liquid.py) on the GPU, for the radial menu.
//
// The shape is the union of n rounded annular slices plus the hub, as a signed
// distance field. Inside a thin bezel the backdrop is refracted like a thick lens
// edge, with R, G and B bent by different amounts (the rainbow fringe); a light
// blur and saturation boost, a tint that adapts to light or dark backdrops, an
// inner glow or bevel, a specular rim facing the light, and a soft drop shadow.
// A hovered slice pops toward the cursor: it is the same glass, scaled about its
// centre and pushed outward, exactly as radial.py's _paint_hover does.
//
// Coordinates: px = pixels in the item, y down. Angles in degrees, CCW, y up.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;          // item size in px
    float n;            // slice count (0: hub only)
    float rIn;
    float rOut;
    float rHub;
    float gapDeg;
    float corner;
    vec4 hov0;          // hover spring 0..1 of slices 0-3, 4-7, 8-11
    vec4 hov1;
    vec4 hov2;
    float erase;        // half-size of the square around the cursor to erase (the drag icon), 0 = off
};
layout(binding = 1) uniform sampler2D source;   // backdrop, same size as the item, mipmapped

const float PI = 3.14159265;
const float BEZEL = 22.0;
const float STRENGTH = 16.0;
const float DISPERSION = 0.32;
const float SATURATION = 1.45;
const float SPEC = 0.95;
const vec2 LIGHT = vec2(-0.55, -0.83);

float hoverOf(int i) {
    if (i < 4) return hov0[i];
    if (i < 8) return hov1[i - 4];
    return hov2[i - 8];
}

// liquid.sdf_ring_sector, for one point
float sdfSector(vec2 p, vec2 c, float r0, float r1, float a0, float a1, float rr) {
    vec2 d = vec2(p.x - c.x, c.y - p.y);
    float rad = length(d);
    float mid = radians((a0 + a1) * 0.5);
    float half_ = radians((a1 - a0) * 0.5);
    float ang = atan(d.y, d.x) - mid;
    ang = mod(ang + PI, 2.0 * PI) - PI;
    float side = rad * sin(abs(ang) - half_);
    if (abs(ang) - half_ > PI * 0.5) side = rad;
    float ring = max(r0 - rad, rad - r1);
    float rs = ring + rr;
    float ss = side + rr;
    float outside = length(max(vec2(rs, ss), 0.0));
    float inside = min(max(rs, ss), 0.0);
    return outside + inside - rr;
}

// Slice i's pop transform: screen point q -> the glass point it shows.
vec2 unpop(vec2 q, vec2 c, float a0, float a1, float h) {
    if (h < 0.001) return q;
    float mid = radians((a0 + a1) * 0.5);
    vec2 dir = vec2(cos(mid), -sin(mid));
    vec2 pc = c + dir * ((rIn + rOut) * 0.5);
    float k = 1.0 + 0.07 * h;
    return pc + (q - pc - dir * (6.0 * h)) / k;
}

void sliceAngles(int i, out float a0, out float a1) {
    float span = 360.0 / n;
    float start = 90.0 + span * 0.5 - float(i + 1) * span;
    a0 = start + gapDeg * 0.5;
    a1 = start + span - gapDeg * 0.5;
}

// The whole menu's field at screen point q. Returns the distance and, in p, the
// glass-space point that pixel shows (differs from q inside a popped slice).
float field(vec2 q, out vec2 p) {
    vec2 c = size * 0.5;
    float best = length(q - c) - rHub;
    p = q;
    int count = int(n + 0.5);
    for (int i = 0; i < 12; i++) {
        if (i >= count) break;
        float a0, a1;
        sliceAngles(i, a0, a1);
        float h = hoverOf(i);
        vec2 pi = unpop(q, c, a0, a1, h);
        float d = sdfSector(pi, c, rIn, rOut, a0, a1, corner) * (1.0 + 0.07 * h);
        // a popped slice sits on top of its neighbours, like the painted copy does
        if (d < best || (h > 0.001 && d < 0.5)) {
            best = d;
            p = pi;
        }
    }
    return best;
}

// The file manager's drag icon sits on the cursor, which is the menu's centre,
// and the capture includes it. Like radial.py's inpaint_rects, replace that
// square with what surrounds it: push samples out to just past its edge.
vec2 inpaint(vec2 px) {
    vec2 c = size * 0.5;
    vec2 d = px - c;
    float m = max(abs(d.x), abs(d.y));
    if (erase <= 0.0 || m >= erase) return px;
    vec2 dir = m < 0.5 ? vec2(0.0, -1.0) : d / m;
    return c + dir * (erase + 3.0);
}

// Backdrop brightness: the top mip level is the average of the whole capture.
float backdropLum() {
    return dot(textureLod(source, vec2(0.5), 12.0).rgb, vec3(0.2126, 0.7152, 0.0722));
}

vec3 soft(vec2 px) {
    // a light blur (liquid.py: Gaussian 2.2 px) and a saturation boost
    vec2 t = 1.0 / size;
    vec2 c = size * 0.5;
    if (erase > 0.0 && max(abs(px.x - c.x), abs(px.y - c.y)) < erase) {
        // inside the erased square: a heavily blurred sample from its edge, so the
        // fill is a smooth wash of the surroundings rather than streaks
        vec3 w = textureLod(source, inpaint(px) * t, 5.0).rgb;
        float lw = dot(w, vec3(0.2126, 0.7152, 0.0722));
        return clamp(mix(vec3(lw), w, SATURATION), 0.0, 1.0);
    }
    vec3 s = texture(source, px * t).rgb * 0.36;
    s += texture(source, (px + vec2(1.6, 1.6)) * t).rgb * 0.16;
    s += texture(source, (px + vec2(-1.6, 1.6)) * t).rgb * 0.16;
    s += texture(source, (px + vec2(1.6, -1.6)) * t).rgb * 0.16;
    s += texture(source, (px + vec2(-1.6, -1.6)) * t).rgb * 0.16;
    float l = dot(s, vec3(0.2126, 0.7152, 0.0722));
    return clamp(mix(vec3(l), s, SATURATION), 0.0, 1.0);
}

void main() {
    vec2 q = qt_TexCoord0 * size;
    vec2 p;
    float d = field(q, p);
    bool light = backdropLum() > 0.62;

    // soft drop shadow outside the glass (liquid.shadow: spread 26, offset (0, 8))
    vec2 ps;
    float ds = field(q - vec2(0.0, 8.0), ps);
    float shadowA = d < 0.0 ? 0.0 : pow(clamp(1.0 - max(ds, 0.0) / 26.0, 0.0, 1.0), 2.0) * (light ? 0.42 : 0.30);

    float alpha = clamp(0.5 - d, 0.0, 1.0);
    if (alpha <= 0.0) {
        fragColor = vec4(0.0, 0.0, 0.0, shadowA) * qt_Opacity;
        return;
    }

    // outward normal from the field's gradient, in glass space (y down)
    vec2 tmp;
    float dx = field(q + vec2(0.75, 0.0), tmp) - field(q - vec2(0.75, 0.0), tmp);
    float dy = field(q + vec2(0.0, 0.75), tmp) - field(q - vec2(0.0, 0.75), tmp);
    vec2 nrm = normalize(vec2(dx, dy) + 1e-6);

    float depth = -d;
    float t = clamp(1.0 - depth / BEZEL, 0.0, 1.0);
    float profile = 1.0 - sqrt(clamp(1.0 - t * t, 0.0, 1.0));   // quarter-circle bezel

    vec3 col;
    if (profile > 0.0) {
        float m = STRENGTH * profile;
        col.r = soft(p - nrm * m * (1.0 - DISPERSION)).r;
        col.g = soft(p - nrm * m).g;
        col.b = soft(p - nrm * m * (1.0 + DISPERSION)).b;
    } else {
        col = soft(p);
    }

    // adaptive tint keeps text legible on any wallpaper
    vec4 tint = light ? vec4(236.0, 232.0, 246.0, 0.14 * 255.0) / 255.0
                      : vec4(18.0, 14.0, 30.0, 0.26 * 255.0) / 255.0;
    col = col * (1.0 - tint.a) + tint.rgb * tint.a;

    if (light) {
        col -= pow(profile, 1.6) * vec3(62.0, 60.0, 54.0) / 255.0;
        col -= clamp(1.0 - depth / 1.6, 0.0, 1.0) * 40.0 / 255.0;
    } else {
        col += profile * profile * 38.0 / 255.0;
    }

    // specular rim, strongest where the edge faces the light
    float fdot = dot(nrm, LIGHT);
    float facing = clamp(fdot, 0.0, 1.0);
    float back = clamp(-fdot, 0.0, 1.0);
    float rim = clamp(1.0 - depth / 2.2, 0.0, 1.0);
    float rim2 = clamp(1.0 - depth / 7.0, 0.0, 1.0);
    float spec = rim * (0.35 + 0.65 * pow(facing, 1.4)) + rim2 * pow(facing, 3.0) * 0.35 + rim * back * back * 0.45;
    col += spec * SPEC;

    // the hub's iridescent ring (radial.py: iridescent_pen, angle 60)
    vec2 c = size * 0.5;
    float hr = abs(length(q - c) - (rHub - 0.5));
    if (hr < 1.1) {
        float a = atan(c.y - q.y, q.x - c.x) + radians(60.0);
        vec3 hue = 0.5 + 0.5 * cos(a + vec3(0.0, 2.094, 4.189));
        col = mix(col, hue, (1.0 - hr / 1.1) * 0.59);
    }

    col = clamp(col, 0.0, 1.0);
    // glass over its own shadow, premultiplied
    float outA = alpha + shadowA * (1.0 - alpha);
    fragColor = vec4(col * alpha, outA) * qt_Opacity;
}
