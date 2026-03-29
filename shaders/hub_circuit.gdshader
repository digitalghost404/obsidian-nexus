shader_type spatial;

uniform vec4 trace_color : source_color = vec4(0.06, 0.18, 0.65, 1.0);
uniform vec4 accent_color : source_color = vec4(0.8, 0.4, 0.05, 1.0);
uniform float emission_strength : hint_range(0.0, 4.0) = 2.0;
uniform float ring_count : hint_range(3.0, 15.0) = 8.0;
uniform float trace_detail : hint_range(10.0, 60.0) = 30.0;
uniform float rotation_speed : hint_range(0.0, 0.5) = 0.02;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    // Center the UV
    vec2 uv = UV * 2.0 - 1.0;
    float dist = length(uv);
    float angle = atan(uv.y, uv.x);

    // Ring traces — concentric
    float ring_mask = 0.0;
    bool on_accent_ring = false;
    for (float i = 0.0; i < 15.0; i++) {
        if (i >= ring_count) break;
        float r = 0.12 + i * (0.85 / ring_count);
        float ring_width = 0.008 + 0.004 * sin(i * 2.5);
        float ring = 1.0 - smoothstep(0.0, ring_width, abs(dist - r));

        // Break the ring into segments with gaps
        float seg_angle = angle + TIME * rotation_speed * (mod(i, 2.0) == 0.0 ? 1.0 : -1.0);
        float segments = trace_detail + i * 3.0;
        float seg = fract(seg_angle / 6.28318 * segments);
        float gap = hash(vec2(i, floor(seg_angle / 6.28318 * segments)));
        if (gap > 0.7) ring *= 0.0; // gap in the ring

        ring_mask = max(ring_mask, ring);
        if (ring > 0.5 && mod(i, 3.0) == 1.0) on_accent_ring = true;
    }

    // Radial traces — lines going outward from center
    float radial = 0.0;
    float num_radials = 24.0;
    for (float i = 0.0; i < 24.0; i++) {
        float target_angle = i * 6.28318 / num_radials;
        float angle_diff = abs(mod(angle - target_angle + 3.14159, 6.28318) - 3.14159);
        float line = 1.0 - smoothstep(0.0, 0.006, angle_diff * dist);

        // Only draw in certain radius ranges
        float r_hash = hash(vec2(i, 0.0));
        float r_start = 0.1 + r_hash * 0.2;
        float r_end = 0.6 + hash(vec2(i, 1.0)) * 0.35;
        if (dist > r_start && dist < r_end) {
            radial = max(radial, line);
        }
    }

    // Connection nodes — bright dots at ring/radial intersections
    float nodes = 0.0;
    for (float i = 0.0; i < 12.0; i++) {
        float node_angle = hash(vec2(i, 50.0)) * 6.28318;
        float node_dist = 0.15 + hash(vec2(i, 51.0)) * 0.7;
        vec2 node_pos = vec2(cos(node_angle), sin(node_angle)) * node_dist;
        float d = length(uv - node_pos);
        nodes = max(nodes, 1.0 - smoothstep(0.0, 0.015, d));
    }

    // Data pads — small rectangles scattered around
    float pads = 0.0;
    for (float i = 0.0; i < 8.0; i++) {
        float pad_angle = hash(vec2(i, 70.0)) * 6.28318;
        float pad_dist = 0.2 + hash(vec2(i, 71.0)) * 0.6;
        vec2 pad_center = vec2(cos(pad_angle), sin(pad_angle)) * pad_dist;
        vec2 d = abs(uv - pad_center);
        float pad = step(d.x, 0.02) * step(d.y, 0.012);
        pads = max(pads, pad);
    }

    // Compose
    float all_traces = max(ring_mask, max(radial, max(nodes, pads)));
    vec3 trace_col = on_accent_ring ? accent_color.rgb : trace_color.rgb;
    vec3 color = vec3(0.01, 0.012, 0.025); // Very dark base
    color = mix(color, trace_col, ring_mask * 0.9);
    color = mix(color, trace_color.rgb, radial * 0.6);
    color = mix(color, trace_col * 2.0, nodes);
    color = mix(color, accent_color.rgb * 1.5, pads);

    // Fade at edges
    float edge_fade = 1.0 - smoothstep(0.8, 1.0, dist);
    color *= edge_fade;

    ALBEDO = color;
    METALLIC = 0.9;
    ROUGHNESS = 0.08;
    EMISSION = color * emission_strength * edge_fade;
    ALPHA = edge_fade;
}
