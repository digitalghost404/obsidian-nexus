shader_type spatial;
render_mode unshaded;

uniform vec4 cold_color : source_color = vec4(0.14, 0.33, 0.93, 1.0);
uniform vec4 warm_color : source_color = vec4(0.98, 0.58, 0.09, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform float temperature : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.0;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float emission_strength : hint_range(0.0, 10.0) = 2.0;

void fragment() {
	vec4 base_color;
	if (temperature < 0.5) {
		base_color = mix(cold_color, warm_color, temperature * 2.0);
	} else {
		base_color = mix(warm_color, hot_color, (temperature - 0.5) * 2.0);
	}
	float pulse = sin(TIME * pulse_speed) * pulse_intensity + 1.0;
	ALBEDO = base_color.rgb;
	EMISSION = base_color.rgb * emission_strength * pulse;
	ALPHA = base_color.a;
}
