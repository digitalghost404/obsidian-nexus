shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.015, 0.02, 0.04, 1.0);
uniform vec4 trace_color : source_color = vec4(0.06, 0.15, 0.55, 1.0);
uniform vec4 accent_color : source_color = vec4(0.7, 0.35, 0.05, 1.0);
uniform float tile_scale : hint_range(1.0, 20.0) = 8.0;
uniform float trace_width : hint_range(0.005, 0.05) = 0.015;
uniform float seam_width : hint_range(0.005, 0.03) = 0.008;
uniform float emission_strength : hint_range(0.0, 3.0) = 1.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float box(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

void fragment() {
    vec2 uv = UV * tile_scale;
    vec2 tile_id = floor(uv);
    vec2 tile_uv = fract(uv);

    // Tile seams
    float seam_x = smoothstep(0.0, seam_width, tile_uv.x) * smoothstep(0.0, seam_width, 1.0 - tile_uv.x);
    float seam_y = smoothstep(0.0, seam_width, tile_uv.y) * smoothstep(0.0, seam_width, 1.0 - tile_uv.y);
    float seam = seam_x * seam_y;

    // Circuit traces within each tile — procedural pattern
    float trace = 0.0;
    float h = hash(tile_id);

    // Horizontal traces (2-4 per tile based on hash)
    int h_traces = int(h * 3.0) + 2;
    for (int i = 0; i < 4; i++) {
        if (i >= h_traces) break;
        float y_pos = 0.15 + float(i) * 0.22 + hash(tile_id + vec2(float(i), 0.0)) * 0.08;
        float x_start = hash(tile_id + vec2(float(i), 1.0)) * 0.3;
        float x_end = 0.7 + hash(tile_id + vec2(float(i), 2.0)) * 0.3;
        if (tile_uv.x > x_start && tile_uv.x < x_end) {
            trace = max(trace, 1.0 - smoothstep(0.0, trace_width, abs(tile_uv.y - y_pos)));
        }
    }

    // Vertical traces (2-3 per tile)
    int v_traces = int(hash(tile_id + vec2(5.0, 5.0)) * 2.0) + 2;
    for (int i = 0; i < 3; i++) {
        if (i >= v_traces) break;
        float x_pos = 0.15 + float(i) * 0.3 + hash(tile_id + vec2(0.0, float(i) + 10.0)) * 0.1;
        float y_start = hash(tile_id + vec2(1.0, float(i) + 10.0)) * 0.3;
        float y_end = 0.7 + hash(tile_id + vec2(2.0, float(i) + 10.0)) * 0.3;
        if (tile_uv.y > y_start && tile_uv.y < y_end) {
            trace = max(trace, 1.0 - smoothstep(0.0, trace_width, abs(tile_uv.x - x_pos)));
        }
    }

    // Connection pads at trace intersections — small bright rectangles
    float pad = 0.0;
    for (int i = 0; i < 3; i++) {
        vec2 pad_pos = vec2(
            0.2 + hash(tile_id + vec2(float(i) + 20.0, 0.0)) * 0.6,
            0.2 + hash(tile_id + vec2(0.0, float(i) + 20.0)) * 0.6
        );
        float d = box(tile_uv - pad_pos, vec2(0.025, 0.015));
        pad = max(pad, 1.0 - smoothstep(0.0, 0.003, d));
    }

    // Determine if this tile has accent (orange) traces — ~20% of tiles
    bool is_accent = hash(tile_id + vec2(99.0, 99.0)) > 0.8;
    vec4 active_color = is_accent ? accent_color : trace_color;

    // Compose
    vec3 color = base_color.rgb;
    color = mix(color, active_color.rgb, trace * seam);
    color = mix(color, active_color.rgb * 2.0, pad * seam);

    // Seam darkening
    color *= (0.4 + 0.6 * seam);

    ALBEDO = color;
    METALLIC = 0.85;
    ROUGHNESS = 0.12;
    EMISSION = (active_color.rgb * trace * seam + active_color.rgb * 2.0 * pad * seam) * emission_strength;
}
