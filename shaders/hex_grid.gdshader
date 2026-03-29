shader_type spatial;
render_mode blend_add, unshaded;

uniform vec4 line_color : source_color = vec4(0.3, 0.35, 0.93, 0.15);
uniform float scale : hint_range(0.1, 10.0) = 2.0;
uniform float line_width : hint_range(0.01, 0.1) = 0.03;
uniform float scroll_speed : hint_range(0.0, 1.0) = 0.05;

float hex_dist(vec2 p) {
	p = abs(p);
	return max(dot(p, normalize(vec2(1.0, 1.73))), p.x);
}

vec4 hex_coords(vec2 uv) {
	vec2 r = vec2(1.0, 1.73);
	vec2 h = r * 0.5;
	vec2 a = mod(uv, r) - h;
	vec2 b = mod(uv - h, r) - h;
	vec2 gv = length(a) < length(b) ? a : b;
	float dist = hex_dist(gv);
	return vec4(gv, dist, 0.0);
}

void fragment() {
	vec2 uv = UV * scale;
	uv.y += TIME * scroll_speed;
	vec4 hc = hex_coords(uv);
	float edge = smoothstep(0.5 - line_width, 0.5, hc.z);
	float alpha = (1.0 - edge) * line_color.a;
	ALBEDO = line_color.rgb;
	ALPHA = alpha;
}
