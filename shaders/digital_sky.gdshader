shader_type sky;

// Digital sky — grid, data streams, horizon glow, distant structures

uniform vec4 horizon_color : source_color = vec4(0.025, 0.04, 0.14, 1.0);
uniform vec4 zenith_color : source_color = vec4(0.005, 0.008, 0.025, 1.0);
uniform vec4 grid_color : source_color = vec4(0.04, 0.08, 0.25, 1.0);
uniform vec4 stream_color : source_color = vec4(0.05, 0.12, 0.5, 1.0);

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void sky() {
    vec3 dir = EYEDIR;
    float elevation = dir.y;
    float azimuth = atan(dir.z, dir.x);

    // Base gradient — horizon bright, zenith dark
    float horizon_mask = 1.0 - abs(elevation);
    horizon_mask = pow(max(horizon_mask, 0.0), 0.6);
    vec3 sky = mix(zenith_color.rgb, horizon_color.rgb, horizon_mask);

    // Warm horizon glow band
    float glow = exp(-abs(elevation) * 10.0) * 0.5;
    sky += vec3(0.05, 0.025, 0.1) * glow;

    // Subtle orange accent on one side of horizon
    float side_glow = exp(-abs(elevation) * 8.0) * max(0.0, cos(azimuth)) * 0.15;
    sky += vec3(0.12, 0.05, 0.01) * side_glow;

    // Spherical grid lines
    float u = azimuth / 6.28318;
    float v = elevation * 0.5 + 0.5;
    vec2 grid_uv = vec2(u, v) * 25.0;
    vec2 grid_lines = abs(fract(grid_uv) - 0.5);
    float grid = min(grid_lines.x, grid_lines.y);
    float grid_mask = 1.0 - smoothstep(0.0, 0.015, grid);
    grid_mask *= smoothstep(-0.05, 0.15, elevation) * smoothstep(0.85, 0.35, elevation);
    sky += grid_color.rgb * grid_mask * 0.4;

    // Falling data streams in the sky
    float col_id = floor(u * 80.0);
    float stream_active = step(0.82, hash(vec2(col_id, 0.0)));
    float scroll = v * 12.0 + TIME * 0.3 * (0.5 + hash(vec2(col_id, 1.0)));
    float char_bright = (1.0 - fract(scroll)) * stream_active;
    char_bright *= smoothstep(0.0, 0.25, elevation) * smoothstep(0.9, 0.45, elevation);
    float stream_edge = abs(fract(u * 80.0) - 0.5);
    char_bright *= 1.0 - smoothstep(0.0, 0.06, stream_edge);
    sky += stream_color.rgb * char_bright * 0.5;

    // Distant horizon structures — silhouettes of far-off towers
    float struct_id = floor(azimuth * 12.0 / 6.28318);
    float struct_h = hash(vec2(struct_id, 6.0)) * 0.12 + 0.02;
    float struct_active = step(0.3, hash(vec2(struct_id, 5.0)));
    float on_struct = step(elevation, struct_h) * step(0.0, elevation) * struct_active;
    float struct_w = abs(fract(azimuth * 12.0 / 6.28318) - 0.5);
    on_struct *= 1.0 - smoothstep(0.0, 0.12, struct_w);
    sky += vec3(0.02, 0.03, 0.1) * on_struct;

    // Scattered "stars" — tiny bright data points
    vec2 star_uv = vec2(u * 200.0, v * 100.0);
    vec2 star_id = floor(star_uv);
    float star = step(0.992, hash(star_id));
    float star_flicker = 0.5 + 0.5 * sin(TIME * 2.0 + hash(star_id + vec2(1.0, 0.0)) * 20.0);
    star *= star_flicker * smoothstep(0.1, 0.3, elevation);
    sky += vec3(0.15, 0.2, 0.5) * star;

    COLOR = sky;
}
