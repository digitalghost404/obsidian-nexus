shader_type spatial;
render_mode blend_add, unshaded;

uniform vec4 beam_color : source_color = vec4(0.3, 0.4, 0.93, 0.5);
uniform float pulse_speed : hint_range(0.1, 5.0) = 2.0;
uniform float pulse_width : hint_range(0.05, 0.5) = 0.15;
uniform float glow_strength : hint_range(0.0, 5.0) = 2.0;
uniform float base_alpha : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	float pulse_pos = fract(UV.x - TIME * pulse_speed);
	float pulse = smoothstep(pulse_width, 0.0, abs(pulse_pos - 0.5));
	float edge_fade = smoothstep(0.0, 0.3, UV.y) * smoothstep(1.0, 0.7, UV.y);
	float alpha = (base_alpha + pulse * 0.6) * edge_fade;
	ALBEDO = beam_color.rgb;
	EMISSION = beam_color.rgb * glow_strength * (base_alpha + pulse);
	ALPHA = alpha * beam_color.a;
}
