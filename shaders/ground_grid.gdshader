shader_type spatial;
render_mode blend_add, unshaded;

uniform vec4 grid_color : source_color = vec4(0.15, 0.25, 0.8, 0.4);
uniform float grid_spacing : hint_range(1.0, 20.0) = 4.0;
uniform float line_width : hint_range(0.01, 0.2) = 0.04;
uniform float fade_distance : hint_range(10.0, 200.0) = 80.0;
uniform float pulse_speed : hint_range(0.0, 2.0) = 0.3;

void fragment() {
	vec2 world_uv = UV * grid_spacing * 20.0;

	// Grid lines
	vec2 grid = abs(fract(world_uv) - 0.5);
	float line = min(grid.x, grid.y);
	float mask = 1.0 - smoothstep(0.0, line_width, line);

	// Subtle pulse
	float pulse = sin(TIME * pulse_speed) * 0.15 + 0.85;

	// Distance fade from center
	float dist = length(UV - 0.5) * 2.0;
	float fade = 1.0 - smoothstep(0.0, 1.0, dist);

	float alpha = mask * grid_color.a * pulse * fade;
	ALBEDO = grid_color.rgb;
	EMISSION = grid_color.rgb * 1.5 * pulse;
	ALPHA = alpha;
}
