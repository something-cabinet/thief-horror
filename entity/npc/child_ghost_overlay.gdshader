shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec4 ghost_color : source_color = vec4(0.35, 0.72, 0.90, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.22;

void fragment() {
	float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 2.2);
	float scan = 0.78 + 0.22 * sin((VERTEX.y - TIME * 0.34) * 70.0);
	float pulse = 0.86 + 0.14 * sin(TIME * 2.1);
	ALBEDO = ghost_color.rgb;
	EMISSION = ghost_color.rgb * (0.35 + rim * 1.8) * scan;
	ALPHA = opacity * pulse * (0.35 + rim * 0.9) * scan;
}
