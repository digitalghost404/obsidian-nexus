shader_type spatial;
render_mode blend_mix;

uniform vec4 panel_color : source_color = vec4(0.02, 0.03, 0.07, 1.0);
uniform vec4 line_color : source_color = vec4(0.05, 0.12, 0.45, 1.0);
uniform vec4 accent_color : source_color = vec4(0.65, 0.3, 0.04, 1.0);
uniform float panel_scale : hint_range(1.0, 10.0) = 4.0;
uniform float scroll_speed : hint_range(0.0, 0.5) = 0.05;
uniform float emission_strength : hint_range(0.0, 3.0) = 1.2;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float box(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

void fragment() {
    vec2 uv = UV * panel_scale;
    uv.y += TIME * scroll_speed;

    // Panel grid — rectangular panels (wider than tall)
    vec2 panel_size = vec2(1.0, 0.6);
    vec2 panel_id = floor(uv / panel_size);
    vec2 panel_uv = fract(uv / panel_size);

    // Panel border
    float border = 0.0;
    float bw = 0.02;
    border = max(border, 1.0 - smoothstep(0.0, bw, panel_uv.x));
    border = max(border, 1.0 - smoothstep(0.0, bw, 1.0 - panel_uv.x));
    border = max(border, 1.0 - smoothstep(0.0, bw, panel_uv.y));
    border = max(border, 1.0 - smoothstep(0.0, bw, 1.0 - panel_uv.y));

    // Internal data lines — horizontal thin lines
    float data_lines = 0.0;
    float h = hash(panel_id);
    int num_lines = int(h * 4.0) + 3;
    for (int i = 0; i < 6; i++) {
        if (i >= num_lines) break;
        float y_pos = 0.1 + float(i) * 0.14;
        float line_h = hash(panel_id + vec2(float(i), 0.0));
        float x_start = 0.08 + line_h * 0.15;
        float x_end = 0.6 + hash(panel_id + vec2(float(i), 1.0)) * 0.32;
        if (panel_uv.x > x_start && panel_uv.x < x_end) {
            data_lines = max(data_lines, 1.0 - smoothstep(0.0, 0.008, abs(panel_uv.y - y_pos)));
        }
    }

    // Small accent rectangles (data readouts) — 1-2 per panel
    float readouts = 0.0;
    int num_readouts = int(hash(panel_id + vec2(50.0, 50.0)) * 2.0) + 1;
    for (int i = 0; i < 2; i++) {
        if (i >= num_readouts) break;
        vec2 r_pos = vec2(
            0.65 + hash(panel_id + vec2(float(i) + 30.0, 0.0)) * 0.25,
            0.2 + hash(panel_id + vec2(0.0, float(i) + 30.0)) * 0.5
        );
        vec2 r_size = vec2(0.06 + hash(panel_id + vec2(float(i) + 40.0, 0.0)) * 0.08, 0.04);
        float d = box(panel_uv - r_pos, r_size);
        readouts = max(readouts, 1.0 - smoothstep(0.0, 0.004, d));
    }

    // Corner indicators — small L-shapes in corners
    float corners = 0.0;
    float cl = 0.06;
    float cw = 0.01;
    // Top-left
    if (panel_uv.x < cl + 0.05 && panel_uv.y < cw + 0.05) {
        corners = max(corners, 1.0 - smoothstep(0.0, cw, min(panel_uv.y - 0.05, panel_uv.x - 0.05)));
    }

    // Is this an accent panel? ~15%
    bool is_accent = hash(panel_id + vec2(77.0, 77.0)) > 0.85;
    vec4 active_line_color = is_accent ? accent_color : line_color;

    vec3 color = panel_color.rgb;
    color = mix(color, line_color.rgb, border * 0.7);
    color = mix(color, active_line_color.rgb, data_lines);
    color = mix(color, accent_color.rgb, readouts);
    color = mix(color, line_color.rgb * 0.8, corners);

    ALBEDO = color;
    METALLIC = 0.7;
    ROUGHNESS = 0.2;
    EMISSION = (active_line_color.rgb * (border * 0.3 + data_lines * 0.8) + accent_color.rgb * readouts * 1.5) * emission_strength;
}
