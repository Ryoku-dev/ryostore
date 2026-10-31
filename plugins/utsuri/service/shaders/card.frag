#version 440
// The result cards' glass (toasts.py: paint_glass over LiquidBacking). The
// frost itself is Hyprland's live blur behind the layer (the float-utsuri
// layer rule in user.lua), so it stays right while cards stack and move. This
// adds what paint_glass does on top: the dark (or red, for an error) tint, the
// inner bezel glow, the specular rim facing the light and the iridescent edge.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float radius;
    float err;          // 1 = error card
    vec4 tint;          // coloured theme: body colour (rgb) and opacity (a); a = 0: the original dark frost
    vec4 accent;        // coloured theme: edge colour instead of the rainbow
};

float sdf(vec2 p) {
    vec2 h = size * 0.5 - radius;
    vec2 q = abs(p - size * 0.5) - h;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    float d = sdf(p);
    float alpha = clamp(0.5 - d, 0.0, 1.0);
    if (alpha <= 0.0) { fragColor = vec4(0.0); return; }
    vec2 n = normalize(vec2(sdf(p + vec2(0.75, 0.0)) - sdf(p - vec2(0.75, 0.0)),
                            sdf(p + vec2(0.0, 0.75)) - sdf(p - vec2(0.0, 0.75))) + 1e-6);
    float depth = -d;
    float t = clamp(1.0 - depth / 16.0, 0.0, 1.0);
    float profile = 1.0 - sqrt(clamp(1.0 - t * t, 0.0, 1.0));

    bool themed = tint.a > 0.0;
    vec4 body = err > 0.5 ? vec4(140.0, 30.0, 50.0, 150.0) / 255.0
              : themed ? tint : vec4(20.0, 16.0, 32.0, 120.0) / 255.0;
    vec3 col = body.rgb;
    float a = body.a;
    // inner bezel glow
    col += profile * profile * 0.22;
    a = max(a, profile * profile * 0.35);
    // specular rim, strongest facing the top-left light
    float rim = clamp(1.0 - depth / 2.2, 0.0, 1.0);
    float facing = clamp(dot(n, vec2(-0.55, -0.83)), 0.0, 1.0);
    float spec = rim * (0.30 + 0.70 * pow(facing, 1.4));
    // iridescent edge (paint_glass rainbow_alpha 170)
    float hue = atan(p.y - size.y * 0.5, p.x - size.x * 0.5);
    vec3 rainbow = themed ? accent.rgb : 0.55 + 0.45 * cos(hue + vec3(0.0, 2.094, 4.189));
    float edge = clamp(1.0 - depth / 1.4, 0.0, 1.0) * (170.0 / 255.0);
    col = mix(col, rainbow, edge * 0.7) + spec * 0.6;
    a = max(a, max(edge, spec * 0.8));
    a *= alpha;
    fragColor = vec4(clamp(col, 0.0, 1.0) * a, a) * qt_Opacity;
}
