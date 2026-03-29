shader_type spatial;
render_mode unshaded, cull_front;

// Digital sky dome — faint grid, data streams, distant glow horizon

uniform vec4 horizon_color : source_color = vec4(0.02, 0.04, 0.12, 1.0);
uniform vec4 zenith_color : source_color = vec4(0.003, 0.005, 0.015, 1.0);
uniform vec4 grid_color : source_color = vec4(0.03, 0.06, 0.2, 1.0);
uniform vec4 stream_color : source_color = vec4(0.04, 0.1, 0.4, 1.0);
uniform float grid_scale : hint_range(5.0, 50.0) = 20.0;
uniform float stream_speed : hint_range(0.0, 2.0) = 0.3;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    // Spherical UV from view direction
    vec3 dir = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 0.0)).xyz);
    float elevation = dir.y; // -1 (down) to 1 (up)
    float azimuth = atan(dir.z, dir.x);

    // Horizon gradient — bright at horizon, dark at zenith
    float horizon_mask = 1.0 - abs(elevation);
    horizon_mask = pow(horizon_mask, 0.5); // Wider gradient
    vec3 sky = mix(zenith_color.rgb, horizon_color.rgb, horizon_mask);

    // Horizon glow band — concentrated warm glow right at the horizon line
    float horizon_glow = exp(-abs(elevation) * 12.0) * 0.4;
    sky += vec3(0.04, 0.02, 0.08) * horizon_glow;

    // Spherical grid — faint lines across the sky
    float u = azimuth / 6.28318;
    float v = elevation * 0.5 + 0.5;
    vec2 grid_uv = vec2(u, v) * grid_scale;
    vec2 grid_lines = abs(fract(grid_uv) - 0.5);
    float grid = min(grid_lines.x, grid_lines.y);
    float grid_mask = 1.0 - smoothstep(0.0, 0.02, grid);
    // Fade grid near zenith and below horizon
    grid_mask *= smoothstep(-0.1, 0.1, elevation) * smoothstep(0.9, 0.4, elevation);
    sky += grid_color.rgb * grid_mask * 0.5;

    // Vertical data streams — thin bright lines falling in the sky
    float col_id = floor(u * 60.0);
    float stream_active = step(0.85, hash(vec2(col_id, 0.0)));
    float scroll = v * 10.0 + TIME * stream_speed * (0.5 + hash(vec2(col_id, 1.0)));
    float char_cell = fract(scroll);
    float brightness = (1.0 - char_cell) * stream_active;
    brightness *= smoothstep(0.0, 0.2, elevation) * smoothstep(0.95, 0.5, elevation);
    // Stream width
    float stream_edge = abs(fract(u * 60.0) - 0.5);
    brightness *= 1.0 - smoothstep(0.0, 0.08, stream_edge);
    sky += stream_color.rgb * brightness * 0.6;

    // Distant "structures" on the horizon — subtle vertical bars
    float struct_id = floor(azimuth * 8.0 / 6.28318);
    float struct_mask = step(0.4, hash(vec2(struct_id, 5.0)));
    float struct_height = hash(vec2(struct_id, 6.0)) * 0.15;
    float struct_line = step(elevation, struct_height) * step(0.0, elevation);
    float struct_width = abs(fract(azimuth * 8.0 / 6.28318) - 0.5);
    struct_line *= 1.0 - smoothstep(0.0, 0.15, struct_width);
    sky += vec3(0.015, 0.025, 0.08) * struct_line * struct_mask;

    ALBEDO = sky;
    EMISSION = sky * 1.5;
}
