shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur_radius : hint_range(0.0, 8.0) = 3.0;

void fragment() {
	vec3 blurred = vec3(0.0);
	float total_weight = 0.0;
	// A small Gaussian kernel works with the project's Compatibility renderer.
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 offset = vec2(float(x), float(y));
			float weight = exp(-0.5 * dot(offset, offset));
			vec2 uv = clamp(SCREEN_UV + offset * SCREEN_PIXEL_SIZE * blur_radius, vec2(0.0), vec2(1.0));
			blurred += texture(screen_texture, uv).rgb * weight;
			total_weight += weight;
		}
	}
	COLOR = vec4(blurred / total_weight, 1.0);
}
