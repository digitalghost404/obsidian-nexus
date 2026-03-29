shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.01, 0.014, 0.03, 1.0);
uniform vec4 trace_color : source_color = vec4(0.08, 0.22, 0.75, 1.0);
uniform vec4 accent_color : source_color = vec4(0.9, 0.45, 0.06, 1.0);
uniform vec4 seam_color : source_color = vec4(0.04, 0.1, 0.35, 1.0);
uniform vec4 pulse_color : source_color = vec4(0.5, 0.85, 1.0, 1.0);
uniform float tile_scale : hint_range(1.0, 20.0) = 8.0;
uniform float trace_width : hint_range(0.005, 0.05) = 0.025;
uniform float seam_width : hint_range(0.005, 0.03) = 0.01;
uniform float emission_strength : hint_range(0.0, 8.0) = 3.0;
uniform float pulse_speed : hint_range(0.1, 5.0) = 1.8;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash1(float n) {
    return fract(sin(n) * 43758.5453);
}

float box(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

void fragment() {
    vec2 uv = UV * tile_scale;
    vec2 tile_id = floor(uv);
    vec2 tile_uv = fract(uv);

    float h = hash(tile_id);
    float h2 = hash(tile_id + vec2(13.7, 27.3));

    // --- Seam lines — faint glow between tiles ---
    float seam_x = smoothstep(0.0, seam_width, tile_uv.x) * smoothstep(0.0, seam_width, 1.0 - tile_uv.x);
    float seam_y = smoothstep(0.0, seam_width, tile_uv.y) * smoothstep(0.0, seam_width, 1.0 - tile_uv.y);
    float seam_mask = seam_x * seam_y;
    // Seam glow: the inverse (where seam_mask is 0 we are on the seam)
    float on_seam = 1.0 - seam_mask;

    // --- Grid intersection nodes — bright dots at tile corners ---
    float node_x = max(
        1.0 - smoothstep(0.0, 0.018, length(tile_uv - vec2(0.0, 0.0))),
        1.0 - smoothstep(0.0, 0.018, length(tile_uv - vec2(1.0, 0.0)))
    );
    node_x = max(node_x, max(
        1.0 - smoothstep(0.0, 0.018, length(tile_uv - vec2(0.0, 1.0))),
        1.0 - smoothstep(0.0, 0.018, length(tile_uv - vec2(1.0, 1.0)))
    ));

    // --- Circuit traces — horizontal ---
    float trace = 0.0;
    int h_traces = int(h * 3.0) + 3;   // 3–5 per tile
    for (int i = 0; i < 5; i++) {
        if (i >= h_traces) break;
        float y_pos = 0.1 + float(i) * 0.18 + hash(tile_id + vec2(float(i), 0.5)) * 0.06;
        float x_start = hash(tile_id + vec2(float(i), 1.0)) * 0.25;
        float x_end   = 0.75 + hash(tile_id + vec2(float(i), 2.0)) * 0.25;
        if (tile_uv.x > x_start && tile_uv.x < x_end) {
            float t = 1.0 - smoothstep(0.0, trace_width, abs(tile_uv.y - y_pos));
            trace = max(trace, t);
        }
    }

    // --- Circuit traces — vertical ---
    int v_traces = int(hash(tile_id + vec2(5.0, 5.0)) * 2.0) + 3;  // 3–4 per tile
    for (int i = 0; i < 5; i++) {
        if (i >= v_traces) break;
        float x_pos   = 0.1 + float(i) * 0.2 + hash(tile_id + vec2(0.0, float(i) + 10.0)) * 0.08;
        float y_start = hash(tile_id + vec2(1.0, float(i) + 10.0)) * 0.25;
        float y_end   = 0.75 + hash(tile_id + vec2(2.0, float(i) + 10.0)) * 0.25;
        if (tile_uv.y > y_start && tile_uv.y < y_end) {
            float t = 1.0 - smoothstep(0.0, trace_width, abs(tile_uv.x - x_pos));
            trace = max(trace, t);
        }
    }

    // --- Animated data pulses traveling along horizontal traces ---
    float pulse = 0.0;
    for (int i = 0; i < 5; i++) {
        if (i >= h_traces) break;
        float y_pos   = 0.1 + float(i) * 0.18 + hash(tile_id + vec2(float(i), 0.5)) * 0.06;
        float x_start = hash(tile_id + vec2(float(i), 1.0)) * 0.25;
        float x_end   = 0.75 + hash(tile_id + vec2(float(i), 2.0)) * 0.25;

        // Each trace gets its own phase offset so they don't all pulse together
        float phase  = hash1(hash(tile_id) * 17.3 + float(i) * 5.7) * 6.283;
        float speed  = pulse_speed * (0.6 + hash(tile_id + vec2(float(i), 99.0)) * 0.8);
        float t_norm = fract((TIME * speed + phase) / 6.283);
        float pulse_x = x_start + t_norm * (x_end - x_start);

        float on_trace_y = 1.0 - smoothstep(0.0, trace_width * 1.5, abs(tile_uv.y - y_pos));
        float dot_x      = 1.0 - smoothstep(0.0, 0.022, abs(tile_uv.x - pulse_x));
        pulse = max(pulse, on_trace_y * dot_x);
    }

    // --- Connection pads — 5 per tile ---
    float pad = 0.0;
    for (int i = 0; i < 5; i++) {
        vec2 pad_pos = vec2(
            0.15 + hash(tile_id + vec2(float(i) + 20.0, 0.0)) * 0.7,
            0.15 + hash(tile_id + vec2(0.0, float(i) + 20.0)) * 0.7
        );
        float d = box(tile_uv - pad_pos, vec2(0.028, 0.018));
        pad = max(pad, 1.0 - smoothstep(0.0, 0.004, d));
    }

    // --- Accent tile decision (~25% of tiles) ---
    bool is_accent = hash(tile_id + vec2(99.0, 99.0)) > 0.75;
    vec4 active_color = is_accent ? accent_color : trace_color;

    // --- Compose colour ---
    vec3 color = base_color.rgb;

    // Seam glow (faint but visible)
    color = mix(color, seam_color.rgb * 1.5, on_seam * 0.35);

    // Grid node dots
    color = mix(color, pulse_color.rgb, node_x * 0.8);

    // Traces (only inside the tile, not on seams)
    color = mix(color, active_color.rgb, trace * seam_mask);

    // Pads
    color = mix(color, active_color.rgb * 2.5, pad * seam_mask);

    // Pulse dots — bright white-blue flash
    color = mix(color, pulse_color.rgb, pulse * seam_mask);

    ALBEDO = color;
    METALLIC = 0.9;
    ROUGHNESS = 0.08;

    // --- Emission ---
    vec3 emit = vec3(0.0);
    emit += seam_color.rgb * on_seam * 0.6;                        // seam glow
    emit += pulse_color.rgb * node_x * 2.0;                        // node dots
    emit += active_color.rgb * trace * seam_mask * 1.2;            // trace glow
    emit += active_color.rgb * pad   * seam_mask * 2.5;            // pad glow
    emit += pulse_color.rgb  * pulse * seam_mask * 4.0;            // pulse bright flash
    EMISSION = emit * emission_strength;
}
