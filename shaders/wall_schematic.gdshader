shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform vec4 panel_color : source_color = vec4(0.015, 0.022, 0.055, 1.0);
uniform vec4 line_color : source_color = vec4(0.07, 0.18, 0.6, 1.0);
uniform vec4 accent_color : source_color = vec4(0.75, 0.35, 0.04, 1.0);
uniform float panel_scale : hint_range(1.0, 10.0) = 4.0;
uniform float scroll_speed : hint_range(0.0, 0.5) = 0.05;
uniform float emission_strength : hint_range(0.0, 5.0) = 1.5;

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

    // Panel border — thicker and brighter
    float border = 0.0;
    float bw = 0.032;  // thicker than before
    border = max(border, 1.0 - smoothstep(0.0, bw, panel_uv.x));
    border = max(border, 1.0 - smoothstep(0.0, bw, 1.0 - panel_uv.x));
    border = max(border, 1.0 - smoothstep(0.0, bw, panel_uv.y));
    border = max(border, 1.0 - smoothstep(0.0, bw, 1.0 - panel_uv.y));

    // Internal data lines — horizontal thin lines, more of them
    float data_lines = 0.0;
    float h = hash(panel_id);
    int num_lines = int(h * 4.0) + 4;   // 4–7 lines per panel
    for (int i = 0; i < 7; i++) {
        if (i >= num_lines) break;
        float y_pos = 0.08 + float(i) * 0.12;
        float line_h = hash(panel_id + vec2(float(i), 0.0));
        float x_start = 0.06 + line_h * 0.12;
        float x_end = 0.55 + hash(panel_id + vec2(float(i), 1.0)) * 0.38;
        if (panel_uv.x > x_start && panel_uv.x < x_end) {
            data_lines = max(data_lines, 1.0 - smoothstep(0.0, 0.01, abs(panel_uv.y - y_pos)));
        }
    }

    // Small accent rectangles (data readouts) — 1-3 per panel
    float readouts = 0.0;
    int num_readouts = int(hash(panel_id + vec2(50.0, 50.0)) * 2.0) + 2;
    for (int i = 0; i < 3; i++) {
        if (i >= num_readouts) break;
        vec2 r_pos = vec2(
            0.62 + hash(panel_id + vec2(float(i) + 30.0, 0.0)) * 0.3,
            0.15 + hash(panel_id + vec2(0.0, float(i) + 30.0)) * 0.6
        );
        vec2 r_size = vec2(0.07 + hash(panel_id + vec2(float(i) + 40.0, 0.0)) * 0.09, 0.05);
        float d = box(panel_uv - r_pos, r_size);
        readouts = max(readouts, 1.0 - smoothstep(0.0, 0.005, d));
    }

    // Corner indicators — L-shapes at all four corners
    float corners = 0.0;
    float cl = 0.08;
    float cw = 0.012;
    // Top-left
    float tl_h = step(panel_uv.x, cl) * step(panel_uv.y, cw);
    float tl_v = step(panel_uv.x, cw) * step(panel_uv.y, cl);
    corners = max(corners, max(tl_h, tl_v));
    // Top-right
    float tr_h = step(1.0 - cl, panel_uv.x) * step(panel_uv.y, cw);
    float tr_v = step(1.0 - cw, panel_uv.x) * step(panel_uv.y, cl);
    corners = max(corners, max(tr_h, tr_v));
    // Bottom-left
    float bl_h = step(panel_uv.x, cl) * step(1.0 - cw, panel_uv.y);
    float bl_v = step(panel_uv.x, cw) * step(1.0 - cl, panel_uv.y);
    corners = max(corners, max(bl_h, bl_v));
    // Bottom-right
    float br_h = step(1.0 - cl, panel_uv.x) * step(1.0 - cw, panel_uv.y);
    float br_v = step(1.0 - cw, panel_uv.x) * step(1.0 - cl, panel_uv.y);
    corners = max(corners, max(br_h, br_v));

    // Accent panel? ~20%
    bool is_accent = hash(panel_id + vec2(77.0, 77.0)) > 0.8;
    vec4 active_line_color = is_accent ? accent_color : line_color;

    vec3 color = panel_color.rgb;
    color = mix(color, line_color.rgb, border * 0.85);
    color = mix(color, active_line_color.rgb, data_lines);
    color = mix(color, accent_color.rgb, readouts);
    color = mix(color, line_color.rgb, corners);

    ALBEDO = color;
    METALLIC = 0.75;
    ROUGHNESS = 0.18;
    EMISSION = (
        line_color.rgb     * (border * 0.5 + data_lines * 1.0 + corners * 0.8) +
        accent_color.rgb   * readouts * 2.0
    ) * emission_strength;
}
