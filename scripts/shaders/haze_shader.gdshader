shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    // --- blur via mipmap LOD ---
    float lod    = progress * 4.5;
    vec4 blurred = textureLod(screen_texture, SCREEN_UV, lod);

    // --- chromatic aberration (channels drift apart as haze grows) ---
    float drift  = progress * 0.006;
    float r      = textureLod(screen_texture, SCREEN_UV + vec2( drift, 0.0), lod).r;
    float g      = textureLod(screen_texture, SCREEN_UV,                     lod).g;
    float b      = textureLod(screen_texture, SCREEN_UV + vec2(-drift, 0.0), lod).b;
    vec4 aberrated = vec4(r, g, b, blurred.a);

    // --- radial vignette closes in ---
    vec2  centered  = SCREEN_UV - vec2(0.5);
    float dist      = length(centered);
    float vig_inner = mix(0.75, 0.28, progress);   // shrinks inward
    float vig_outer = mix(1.10, 0.55, progress);
    float vignette  = smoothstep(vig_outer, vig_inner, dist);

    // --- desaturation + warm fog tint ---
    float grey   = dot(aberrated.rgb, vec3(0.299, 0.587, 0.114));
    vec3  tinted = mix(aberrated.rgb, vec3(grey) * vec3(0.95, 0.93, 1.02), progress * 0.55);

    COLOR = vec4(tinted * vignette, 1.0);
}