shader_type canvas_item;
uniform bool incoming = false;
varying float world_x;
void vertex() {
	world_x = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).x;
}
void fragment() {
	// Change rooms at a narrow architectural seam. A wide cross-fade made
	// both furniture sets visible as transparent ghosts.
	float blend = smoothstep(2070.0, 2130.0, world_x);
	COLOR.a *= incoming ? blend : 1.0 - blend;
}
