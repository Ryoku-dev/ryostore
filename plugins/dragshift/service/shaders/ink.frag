#version 440
// Text colour for the radial menu (radial.py: _text_colors). Labels are drawn
// white into a layer; this recolours them for the backdrop: dark ink with a
// white shadow on light backdrops, white with a dark shadow on dark ones. The
// backdrop's brightness is read from its top mip level, so no CPU readback.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
};
layout(binding = 1) uniform sampler2D source;     // the label layer (white text)
layout(binding = 2) uniform sampler2D backdrop;   // the menu's backdrop, mipmapped

void main() {
    float lum = dot(textureLod(backdrop, vec2(0.5), 12.0).rgb, vec3(0.2126, 0.7152, 0.0722));
    bool light = lum > 0.62;
    float a = texture(source, qt_TexCoord0).a;
    float s = texture(source, qt_TexCoord0 - vec2(0.0, 1.0 / size.y)).a;   // shadow 1 px below
    vec3 fg = light ? vec3(28.0, 20.0, 44.0) / 255.0 : vec3(1.0);
    vec4 sh = light ? vec4(1.0, 1.0, 1.0, 120.0 / 255.0) : vec4(0.0, 0.0, 0.0, 110.0 / 255.0);
    float sa = sh.a * s * (1.0 - a);
    fragColor = vec4(fg * a + sh.rgb * sa, a + sa) * qt_Opacity;
}
