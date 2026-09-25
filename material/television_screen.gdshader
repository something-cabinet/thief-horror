shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D base_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D screen_mask_texture : filter_linear, repeat_disable;
// x/y = upper-left, z/w = lower-right in the imported TV texture atlas.
uniform vec4 screen_rect = vec4(0.02, 0.05, 0.75, 0.87);
uniform float screen_power : hint_range(0.0, 1.0) = 0.0;


void fragment() {
	vec4 base = texture(base_texture, UV);
	float screen_mask = texture(screen_mask_texture, UV).r;
	vec2 local_uv = (UV - screen_rect.xy) / max(
		screen_rect.zw - screen_rect.xy,
		vec2(0.0001)
	);

	// The startup scanline spans the glass immediately, then the picture expands
	// vertically. The atlas-specific mask clips its ends to the real curved glass.
	float expanded_height = 0.5 * smoothstep(0.20, 0.88, screen_power);
	float vertical_distance = abs(local_uv.y - 0.5);
	float reveal = 1.0 - smoothstep(
		expanded_height,
		expanded_height + 0.018,
		vertical_distance
	);
	float powered_gate = smoothstep(0.0, 0.04, screen_power);
	reveal *= powered_gate;
	float line_width_mask = 1.0 - smoothstep(
		0.475,
		0.49,
		abs(local_uv.x - 0.5)
	);
	float line_phase = powered_gate * (1.0 - smoothstep(0.28, 0.44, screen_power));
	float startup_line = (1.0 - smoothstep(0.0, 0.020, vertical_distance))
		* line_width_mask * line_phase;
	float scanline = 0.982 + 0.018 * sin(local_uv.y * 680.0 + TIME * 1.7);
	float phosphor_flicker = 0.992 + 0.008 * sin(TIME * 37.0);
	vec3 powered_off_glass = base.rgb * 0.16 + vec3(0.002, 0.004, 0.006);
	vec3 phosphor_image = mix(base.rgb * 0.52, vec3(0.065, 0.105, 0.125), 0.24)
		* scanline * phosphor_flicker;
	vec3 powered_screen = phosphor_image * reveal;
	vec3 screen_color = mix(powered_off_glass, powered_screen, reveal)
		+ vec3(0.16, 0.24, 0.29) * startup_line;

	ALBEDO = mix(base.rgb, screen_color, screen_mask);
	EMISSION = (
		phosphor_image * reveal * 0.20
		+ vec3(0.16, 0.24, 0.29) * startup_line * 0.75
	) * screen_mask;
	ROUGHNESS = mix(0.62, 0.24, screen_mask);
	METALLIC = 0.0;
}
