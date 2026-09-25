shader_type canvas_item;
render_mode unshaded;

uniform vec4 outline_color : source_color = vec4(1.0);
uniform float thickness = 2.0;


void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(TEXTURE, 0));
	float center = texture(TEXTURE, UV).a;
	float nearby = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			nearby = max(nearby, texture(TEXTURE, UV + vec2(float(x), float(y)) * texel * thickness).a);
		}
	}
	float outline = nearby * (1.0 - center);
	COLOR = vec4(outline_color.rgb, outline_color.a * outline);
}
