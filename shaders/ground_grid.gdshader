shader_type spatial;
render_mode blend_add, unshaded;

uniform vec4 grid_color : source_color = vec4(0.08, 0.14, 0.55, 0.25);
uniform float grid_spacing : hint_range(1.0, 20.0) = 4.0;
uniform float line_width : hint_range(0.01, 0.2) = 0.03;
uniform float pulse_speed : hint_range(0.0, 2.0) = 0.2;

void fragment() {
	vec2 world_uv = UV * grid_spacing * 20.0;

	// Grid lines — thin
	vec2 grid = abs(fract(world_uv) - 0.5);
	float line_mask = min(grid.x, grid.y);
	float mask = 1.0 - smoothstep(0.0, line_width, line_mask);

	// Major grid every 5 cells — slightly brighter
	vec2 major_grid = abs(fract(world_uv / 5.0) - 0.5);
	float major_line = min(major_grid.x, major_grid.y);
	float major_mask = 1.0 - smoothstep(0.0, line_width * 1.5, major_line);
	mask = max(mask, major_mask * 1.5);

	// Very subtle pulse
	float pulse = sin(TIME * pulse_speed) * 0.08 + 0.92;

	// Distance fade — grid fades out at edges
	float dist = length(UV - 0.5) * 2.0;
	float fade = 1.0 - smoothstep(0.3, 1.0, dist);

	float alpha = mask * grid_color.a * pulse * fade;
	ALBEDO = grid_color.rgb;
	EMISSION = grid_color.rgb * 0.6 * pulse;
	ALPHA = alpha;
}
