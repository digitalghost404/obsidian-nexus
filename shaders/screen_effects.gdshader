shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float vignette_radius : hint_range(0.0, 2.0) = 0.85;
uniform float aberration_amount : hint_range(0.0, 0.01) = 0.0015;
uniform float scan_line_amount : hint_range(0.0, 0.5) = 0.03;

void fragment() {
	vec2 uv = SCREEN_UV;

	// Chromatic aberration — stronger at edges
	float dist = length(uv - vec2(0.5)) * 2.0;
	float aberration = aberration_amount * dist * dist;

	float r = texture(screen_texture, uv + vec2(aberration, 0.0)).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - vec2(aberration, 0.0)).b;

	vec3 color = vec3(r, g, b);

	// Vignette — darken edges
	float vignette = smoothstep(vignette_radius + 0.4, vignette_radius, dist);
	color *= mix(1.0 - vignette_strength, 1.0, vignette);

	// Subtle scan lines — CRT feel
	float scan = sin(uv.y * 800.0) * 0.5 + 0.5;
	color *= 1.0 - scan_line_amount * (1.0 - scan);

	COLOR = vec4(color, 1.0);
}
