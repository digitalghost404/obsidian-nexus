shader_type sky;

void sky() {
    vec3 dir = EYEDIR;
    float elevation = dir.y;
    float azimuth = atan(dir.z, dir.x);

    // Base gradient — deep blue at zenith, brighter blue-purple at horizon
    float h = 1.0 - abs(elevation);
    h = pow(max(h, 0.0), 0.5);
    vec3 sky = mix(vec3(0.006, 0.009, 0.025), vec3(0.035, 0.05, 0.16), h);

    // Warm horizon glow band
    float glow = exp(-abs(elevation) * 8.0);
    sky += vec3(0.05, 0.025, 0.1) * glow;

    // Orange accent on one side
    float side = exp(-abs(elevation) * 6.0) * max(0.0, cos(azimuth)) * 0.2;
    sky += vec3(0.15, 0.06, 0.02) * side;

    // Grid lines across the sky
    float u = azimuth / 6.28318;
    float v = elevation * 0.5 + 0.5;
    vec2 guv = vec2(u, v) * 20.0;
    vec2 gl = abs(fract(guv) - 0.5);
    float grid = 1.0 - smoothstep(0.0, 0.02, min(gl.x, gl.y));
    grid *= smoothstep(-0.05, 0.1, elevation) * smoothstep(0.85, 0.4, elevation);
    sky += vec3(0.04, 0.07, 0.22) * grid * 0.5;

    // Data streams falling in sky
    float col_id = floor(u * 60.0);
    float active = step(0.8, fract(sin(col_id * 127.1) * 43758.5));
    float scroll = v * 10.0 + TIME * 0.25 * (0.5 + fract(sin(col_id * 311.7) * 43758.5));
    float bright = (1.0 - fract(scroll)) * active;
    bright *= smoothstep(0.05, 0.2, elevation) * smoothstep(0.9, 0.5, elevation);
    float edge = abs(fract(u * 60.0) - 0.5);
    bright *= 1.0 - smoothstep(0.0, 0.07, edge);
    sky += vec3(0.06, 0.12, 0.45) * bright * 0.5;

    // Flickering data points (stars)
    vec2 star_id = floor(vec2(u * 150.0, v * 80.0));
    float star = step(0.99, fract(sin(dot(star_id, vec2(127.1, 311.7))) * 43758.5));
    float flicker = 0.5 + 0.5 * sin(TIME * 3.0 + fract(sin(star_id.x * 43.7) * 100.0) * 20.0);
    star *= flicker * smoothstep(0.1, 0.3, elevation);
    sky += vec3(0.12, 0.18, 0.5) * star;

    COLOR = sky;
}
