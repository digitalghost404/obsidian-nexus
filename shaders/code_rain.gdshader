shader_type spatial;
render_mode blend_add, unshaded, cull_disabled;

uniform vec4 rain_color : source_color = vec4(0.1, 0.9, 0.3, 0.7);
uniform float scroll_speed : hint_range(0.1, 5.0) = 1.5;
uniform float columns : hint_range(5.0, 80.0) = 40.0;
uniform float brightness_variation : hint_range(0.0, 1.0) = 0.6;
uniform float char_rows : hint_range(10.0, 100.0) = 50.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Procedural glyph — generates a pseudo-character shape within a cell
float glyph(vec2 cell_uv, float char_seed) {
	float g = 0.0;
	// Random horizontal bars (like kanji/code characters)
	int num_bars = int(char_seed * 4.0) + 2;
	for (int i = 0; i < 5; i++) {
		if (i >= num_bars) break;
		float y = 0.15 + float(i) * 0.18;
		float x_start = hash(vec2(char_seed, float(i) + 10.0)) * 0.3 + 0.1;
		float x_end = x_start + 0.3 + hash(vec2(char_seed, float(i) + 20.0)) * 0.3;
		if (cell_uv.x > x_start && cell_uv.x < x_end) {
			g = max(g, 1.0 - smoothstep(0.0, 0.06, abs(cell_uv.y - y)));
		}
	}
	// Random vertical strokes
	int num_vert = int(hash(vec2(char_seed, 99.0)) * 3.0) + 1;
	for (int i = 0; i < 3; i++) {
		if (i >= num_vert) break;
		float x = 0.2 + float(i) * 0.25 + hash(vec2(char_seed, float(i) + 30.0)) * 0.1;
		float y_start = hash(vec2(char_seed, float(i) + 40.0)) * 0.2;
		float y_end = 0.7 + hash(vec2(char_seed, float(i) + 50.0)) * 0.3;
		if (cell_uv.y > y_start && cell_uv.y < y_end) {
			g = max(g, 1.0 - smoothstep(0.0, 0.06, abs(cell_uv.x - x)));
		}
	}
	return g;
}

void fragment() {
	vec2 uv = UV;

	// Column and row grid
	float col_id = floor(uv.x * columns);
	float col_uv_x = fract(uv.x * columns);

	// Per-column scroll speed and offset
	float col_speed = 0.4 + hash(vec2(col_id, 0.0)) * scroll_speed;
	float col_offset = hash(vec2(col_id, 1.0)) * 50.0;

	// Scrolling Y — each column moves independently
	float scroll_y = uv.y * char_rows + TIME * col_speed * char_rows * 0.1 + col_offset;
	float row_id = floor(scroll_y);
	float cell_uv_y = fract(scroll_y);

	// Character seed — changes per cell
	float char_seed = hash(vec2(col_id, row_id));

	// Render the glyph
	vec2 cell_uv = vec2(col_uv_x, cell_uv_y);
	float g = glyph(cell_uv, char_seed);

	// Stream fade — characters near the "head" of a stream are brighter
	// Create streams of ~8-15 characters with gaps
	float stream_phase = hash(vec2(col_id, 2.0)) * 100.0;
	float stream_scroll = TIME * col_speed * 0.5 + stream_phase;
	float stream_pos = fract(stream_scroll + uv.y * 2.0);
	float stream_length = 0.3 + hash(vec2(col_id, 3.0)) * 0.4;
	float in_stream = smoothstep(stream_length, stream_length - 0.05, stream_pos) * smoothstep(0.0, 0.02, stream_pos);

	// Leading character is bright white
	float is_lead = smoothstep(0.03, 0.0, stream_pos) * in_stream;

	// Character change animation — some chars flicker/change
	float flicker = step(0.92, hash(vec2(col_id, row_id + floor(TIME * 8.0))));
	float char_visible = g * in_stream;

	// Brightness falloff along stream (head bright, tail dim)
	float stream_brightness = (1.0 - stream_pos / stream_length) * in_stream;
	stream_brightness = max(stream_brightness, 0.0);

	// Random column activity — some columns are off
	float col_active = step(0.15, hash(vec2(col_id, 4.0)));

	float final_alpha = char_visible * stream_brightness * rain_color.a * col_active;
	final_alpha = max(final_alpha, is_lead * 0.8 * col_active * g);

	// Lead character is whiter
	vec3 color = rain_color.rgb;
	color = mix(color, vec3(0.7, 0.9, 1.0), is_lead * 0.6);

	ALBEDO = color;
	EMISSION = color * (stream_brightness + is_lead * 3.0) * 2.0 * col_active;
	ALPHA = final_alpha;
}
