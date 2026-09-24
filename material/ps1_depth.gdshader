shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, cull_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

uniform float depth_density = 0.075;
uniform vec2 far_resolution = vec2(256.0, 144.0);
uniform float pixel_mix = 0.95;
uniform float color_steps = 18.0;
uniform float dither_strength = 1.0;
uniform float desaturation = 0.24;
uniform float haze_strength = 0.4;
uniform vec3 haze_color : source_color = vec3(0.035, 0.045, 0.065);
uniform float chromatic_offset = 1.1;
uniform float motion_amount = 0.0;
uniform float edge_glitch_pixels = 4.2;
uniform float edge_glitch_rate = 20.0;


float interleaved_noise(vec2 pixel) {
	return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}


float linear_depth_at(vec2 uv, mat4 inverse_projection) {
	float raw_depth = texture(depth_texture, uv).r;
	vec3 ndc = vec3(uv * 2.0 - 1.0, raw_depth);
	vec4 view_position = inverse_projection * vec4(ndc, 1.0);
	return -view_position.z / view_position.w;
}


void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}


void fragment() {
	vec2 source_size = vec2(textureSize(screen_texture, 0));
	vec2 edge_texel = vec2(1.5) / source_size;
	float linear_depth = linear_depth_at(SCREEN_UV, INV_PROJECTION_MATRIX);
	float depth_amount = 1.0 - exp(-max(linear_depth, 0.0) * depth_density);

	float left_depth = linear_depth_at(clamp(SCREEN_UV - vec2(edge_texel.x, 0.0), vec2(0.0), vec2(1.0)), INV_PROJECTION_MATRIX);
	float right_depth = linear_depth_at(clamp(SCREEN_UV + vec2(edge_texel.x, 0.0), vec2(0.0), vec2(1.0)), INV_PROJECTION_MATRIX);
	float up_depth = linear_depth_at(clamp(SCREEN_UV - vec2(0.0, edge_texel.y), vec2(0.0), vec2(1.0)), INV_PROJECTION_MATRIX);
	float down_depth = linear_depth_at(clamp(SCREEN_UV + vec2(0.0, edge_texel.y), vec2(0.0), vec2(1.0)), INV_PROJECTION_MATRIX);
	float depth_delta = max(
		max(abs(linear_depth - left_depth), abs(linear_depth - right_depth)),
		max(abs(linear_depth - up_depth), abs(linear_depth - down_depth))
	) / max(linear_depth, 0.5);
	float depth_edge = smoothstep(0.012, 0.075, depth_delta);

	float center_luma = dot(texture(screen_texture, SCREEN_UV).rgb, vec3(0.299, 0.587, 0.114));
	float side_luma = dot(texture(screen_texture, clamp(SCREEN_UV + vec2(edge_texel.x, 0.0), vec2(0.0), vec2(1.0))).rgb, vec3(0.299, 0.587, 0.114));
	float color_edge = smoothstep(0.09, 0.28, abs(center_luma - side_luma));
	float edge = max(depth_edge, color_edge * 0.55);

	float time_step = floor(TIME * edge_glitch_rate);
	float row = floor(SCREEN_UV.y * 180.0);
	float row_noise = interleaved_noise(vec2(row, time_step)) * 2.0 - 1.0;
	float column_noise = interleaved_noise(vec2(floor(SCREEN_UV.x * 90.0), time_step + 17.0)) * 2.0 - 1.0;
	vec2 glitch_offset = vec2(row_noise, column_noise * 0.3) * edge_glitch_pixels / source_size;
	glitch_offset *= edge * motion_amount * mix(0.55, 1.0, depth_amount);
	vec2 sample_uv = clamp(SCREEN_UV + glitch_offset, vec2(0.0), vec2(1.0));

	vec3 original = texture(screen_texture, sample_uv).rgb;
	vec2 coarse_uv = (floor(sample_uv * far_resolution) + 0.5) / far_resolution;
	vec2 fringe = vec2(chromatic_offset / source_size.x, 0.0) * depth_amount;

	vec3 degraded = texture(screen_texture, coarse_uv).rgb;
	degraded.r = texture(screen_texture, coarse_uv + fringe).r;
	degraded.b = texture(screen_texture, coarse_uv - fringe).b;

	float noise = interleaved_noise(floor(sample_uv * source_size)) - 0.5;
	degraded = floor(degraded * color_steps + noise * dither_strength) / color_steps;
	float luma = dot(degraded, vec3(0.299, 0.587, 0.114));
	degraded = mix(degraded, vec3(luma), desaturation * depth_amount);
	degraded = mix(degraded, haze_color, haze_strength * depth_amount);

	ALBEDO = mix(original, degraded, depth_amount * pixel_mix);
}
