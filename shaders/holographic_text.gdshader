shader_type spatial;
render_mode blend_mix, unshaded;

uniform sampler2D text_texture : hint_default_white;
uniform vec4 text_color : source_color = vec4(0.98, 0.72, 0.2, 1.0);
uniform float scan_line_density : hint_range(50.0, 500.0) = 200.0;
uniform float scan_line_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float jitter_amount : hint_range(0.0, 0.02) = 0.003;
uniform float flicker_speed : hint_range(0.0, 10.0) = 3.0;
uniform float flicker_intensity : hint_range(0.0, 0.5) = 0.1;
uniform float glow_strength : hint_range(0.0, 5.0) = 2.0;

float random(vec2 st) {
	return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	float line = floor(uv.y * scan_line_density);
	float jitter = (random(vec2(line, floor(TIME * 8.0))) - 0.5) * jitter_amount;
	uv.x += jitter;

	vec4 tex = texture(text_texture, uv);

	float scan = sin(uv.y * scan_line_density * 3.14159) * 0.5 + 0.5;
	scan = mix(1.0, scan, scan_line_intensity);

	float flicker = 1.0 - flicker_intensity * (sin(TIME * flicker_speed) * 0.5 + 0.5);
	flicker *= 1.0 - flicker_intensity * 0.5 * random(vec2(floor(TIME * 15.0), 0.0));

	float alpha = tex.a * scan * flicker;
	ALBEDO = text_color.rgb * tex.rgb;
	EMISSION = text_color.rgb * glow_strength * tex.rgb * scan * flicker;
	ALPHA = alpha * text_color.a;
}
