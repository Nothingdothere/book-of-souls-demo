shader_type canvas_item;

uniform sampler2D base_frame : source_color, filter_linear;

void fragment() {
	vec4 page_turn = texture(TEXTURE, UV);
	vec4 still_book = texture(base_frame, UV);
	float difference = max(
		max(abs(page_turn.r - still_book.r), abs(page_turn.g - still_book.g)),
		max(abs(page_turn.b - still_book.b), abs(page_turn.a - still_book.a))
	);
	// The supplied animation frames contain a complete low-resolution book.
	// Keep only pixels that actually belong to the moving sheet.
	if (difference < 0.018 || page_turn.a < 0.02) {
		discard;
	}
	page_turn.a *= smoothstep(0.018, 0.075, difference);
	COLOR = page_turn * COLOR;
}
