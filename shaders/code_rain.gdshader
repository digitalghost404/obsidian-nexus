shader_type spatial;
render_mode blend_add, unshaded;

uniform vec4 rain_color : source_color = vec4(0.1, 0.9, 0.3, 0.7);
uniform float scroll_speed : hint_range(0.1, 5.0) = 1.5;
uniform float columns : hint_range(5.0, 50.0) = 20.0;
uniform float brightness_variation : hint_range(0.0, 1.0) = 0.6;

float random(vec2 st) {
	return fract(sin(dot(st, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float col = floor(uv.x * columns);
	float row_speed = 0.5 + random(vec2(col, 0.0)) * scroll_speed;
	float row_offset = random(vec2(col, 1.0)) * 100.0;
	float scroll = uv.y + TIME * row_speed + row_offset;
	float row = floor(scroll * columns);
	float char_idx = random(vec2(col, row));
	float stream_pos = fract(scroll * columns);
	float brightness = (1.0 - stream_pos) * (0.4 + brightness_variation * random(vec2(col, floor(TIME))));
	float lead = step(0.9, 1.0 - stream_pos) * 2.0;
	float alpha = brightness * rain_color.a;
	alpha *= step(0.3, random(vec2(col, floor(TIME * 0.5))));
	ALBEDO = rain_color.rgb * (1.0 + lead);
	EMISSION = rain_color.rgb * (brightness + lead) * 2.0;
	ALPHA = alpha;
}
