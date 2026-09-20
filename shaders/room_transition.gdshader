shader_type canvas_item;
uniform bool incoming = false;
varying float world_x;
void vertex() {
	world_x = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).x;
}
void fragment() {
	float blend = smoothstep(1500.0, 2600.0, world_x);
	COLOR.a *= incoming ? blend : 1.0 - blend;
}
