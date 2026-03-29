shader_type spatial;

// Data tower surface — server rack panel aesthetic with scrolling data lines,
// indicator lights, panel segments, and circuit traces

uniform vec4 base_color : source_color = vec4(0.015, 0.02, 0.05, 1.0);
uniform vec4 trace_color : source_color = vec4(0.06, 0.15, 0.55, 1.0);
uniform vec4 accent_color : source_color = vec4(0.7, 0.35, 0.05, 1.0);
uniform float temperature : hint_range(0.0, 1.0) = 0.0;
uniform float emission_strength : hint_range(0.0, 5.0) = 1.5;
uniform float panel_density : hint_range(2.0, 12.0) = 6.0;
uniform float data_scroll_speed : hint_range(0.0, 2.0) = 0.3;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float box(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

void fragment() {
    vec2 uv = UV;

    // Panel grid — horizontal panels stacked vertically (like server rack units)
    vec2 panel_size = vec2(1.0, 1.0 / panel_density);
    vec2 panel_id = floor(uv / panel_size);
    vec2 panel_uv = fract(uv / panel_size);
    float ph = hash(panel_id);

    // Panel type: 0=data lines, 1=indicator lights, 2=circuit traces
    int panel_type = int(ph * 3.0);

    // Panel border — thin dark gap between panels
    float border_h = 1.0 - smoothstep(0.0, 0.015, panel_uv.y) * smoothstep(0.0, 0.015, 1.0 - panel_uv.y);
    float border_v = 1.0 - smoothstep(0.0, 0.008, panel_uv.x) * smoothstep(0.0, 0.008, 1.0 - panel_uv.x);
    float border = max(border_h, border_v);

    // Color blending based on temperature
    vec4 active_color = mix(trace_color, accent_color, temperature);

    float detail = 0.0;
    float accent_detail = 0.0;

    if (panel_type == 0) {
        // DATA LINES — horizontal scrolling thin lines
        float scroll = TIME * data_scroll_speed * (hash(panel_id + vec2(5.0, 0.0)) - 0.5) * 2.0;
        int num_lines = int(ph * 3.0) + 3;
        for (int i = 0; i < 5; i++) {
            if (i >= num_lines) break;
            float y = 0.1 + float(i) * 0.2;
            float x_start = fract(hash(panel_id + vec2(float(i), 10.0)) + scroll);
            float x_len = 0.15 + hash(panel_id + vec2(float(i), 11.0)) * 0.35;
            float x_end = x_start + x_len;
            // Wrap around
            bool on_line = (panel_uv.x > x_start && panel_uv.x < x_end) ||
                          (x_end > 1.0 && panel_uv.x < x_end - 1.0);
            if (on_line) {
                detail = max(detail, 1.0 - smoothstep(0.0, 0.025, abs(panel_uv.y - y)));
            }
        }
    } else if (panel_type == 1) {
        // INDICATOR LIGHTS — small glowing dots/rectangles
        int num_indicators = int(hash(panel_id + vec2(20.0, 0.0)) * 6.0) + 3;
        for (int i = 0; i < 8; i++) {
            if (i >= num_indicators) break;
            vec2 ind_pos = vec2(
                0.05 + float(i) * (0.9 / float(num_indicators)),
                0.4 + hash(panel_id + vec2(float(i), 25.0)) * 0.2
            );
            float d = box(panel_uv - ind_pos, vec2(0.02, 0.08));
            float ind = 1.0 - smoothstep(0.0, 0.005, d);
            // Some indicators are accent colored
            if (hash(panel_id + vec2(float(i), 30.0)) > 0.6) {
                accent_detail = max(accent_detail, ind);
            } else {
                detail = max(detail, ind);
            }
        }
        // Blink some indicators
        float blink = step(0.5, sin(TIME * 2.0 + ph * 6.28));
        accent_detail *= (0.5 + 0.5 * blink);
    } else {
        // CIRCUIT TRACES — small PCB-like pattern within panel
        // Horizontal traces
        for (int i = 0; i < 3; i++) {
            float y = 0.2 + float(i) * 0.3;
            float x_s = hash(panel_id + vec2(float(i), 40.0)) * 0.2;
            float x_e = 0.8 + hash(panel_id + vec2(float(i), 41.0)) * 0.2;
            if (panel_uv.x > x_s && panel_uv.x < x_e) {
                detail = max(detail, 1.0 - smoothstep(0.0, 0.015, abs(panel_uv.y - y)));
            }
        }
        // Vertical traces
        for (int i = 0; i < 2; i++) {
            float x = 0.3 + float(i) * 0.4;
            detail = max(detail, 1.0 - smoothstep(0.0, 0.015, abs(panel_uv.x - x)));
        }
        // Corner pads
        for (int i = 0; i < 4; i++) {
            vec2 cp = vec2(
                0.15 + hash(panel_id + vec2(float(i), 50.0)) * 0.7,
                0.15 + hash(panel_id + vec2(float(i), 51.0)) * 0.7
            );
            float d = box(panel_uv - cp, vec2(0.02, 0.015));
            detail = max(detail, 1.0 - smoothstep(0.0, 0.003, d));
        }
    }

    // Compose
    vec3 color = base_color.rgb;
    float inside = (1.0 - border);
    color = mix(color, active_color.rgb, detail * inside);
    color = mix(color, accent_color.rgb * 1.5, accent_detail * inside);
    // Border gets a subtle trace color line
    color = mix(color, active_color.rgb * 0.3, border * 0.5);

    ALBEDO = color;
    METALLIC = 0.85;
    ROUGHNESS = 0.12;
    EMISSION = (active_color.rgb * detail * inside + accent_color.rgb * accent_detail * inside * 2.0 + active_color.rgb * border * 0.15) * emission_strength;
}
