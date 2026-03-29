shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float aberration_strength : hint_range(0.0, 0.05) = 0.02;
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.05;

void fragment() {
	vec2 uv = UV;
	float center_dist = length(uv - vec2(0.5));
	vec2 distort = (uv - vec2(0.5)) * distortion_strength * progress * center_dist;
	uv += distort;
	float aberration = aberration_strength * progress;
	float r = texture(TEXTURE, uv + vec2(aberration, 0.0)).r;
	float g = texture(TEXTURE, uv).g;
	float b = texture(TEXTURE, uv - vec2(aberration, 0.0)).b;
	float a = texture(TEXTURE, uv).a;
	float flash = smoothstep(0.3, 0.5, progress) * smoothstep(0.7, 0.5, progress) * 0.5;
	COLOR = vec4(r + flash, g + flash, b + flash, a);
}
