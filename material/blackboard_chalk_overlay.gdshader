shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D chalk_texture : filter_linear_mipmap_anisotropic;
uniform vec4 chalk_color : source_color = vec4(0.93, 0.91, 0.78, 0.78);


void fragment() {
	vec2 texel = 1.15 / vec2(textureSize(chalk_texture, 0));
	float chalk_alpha = texture(chalk_texture, UV).r;
	chalk_alpha = min(chalk_alpha, texture(chalk_texture, UV + vec2(texel.x, 0.0)).r);
	chalk_alpha = min(chalk_alpha, texture(chalk_texture, UV - vec2(texel.x, 0.0)).r);
	chalk_alpha = min(chalk_alpha, texture(chalk_texture, UV + vec2(0.0, texel.y)).r);
	chalk_alpha = min(chalk_alpha, texture(chalk_texture, UV - vec2(0.0, texel.y)).r);
	chalk_alpha = smoothstep(0.08, 0.72, chalk_alpha);
	ALBEDO = chalk_color.rgb;
	ALPHA = chalk_alpha * chalk_color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.01;
}
