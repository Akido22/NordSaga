// Перекраска по палитре, как pyxel.pal(): цвет src[i] заменяется на dst[i].
// flash — вспышка удара: все непрозрачные пиксели одного цвета.
shader_type canvas_item;

uniform vec4 src[16];
uniform vec4 dst[16];
uniform int count = 0;
uniform bool flash = false;
uniform vec4 flash_color : source_color = vec4(0.957, 0.957, 0.957, 1.0);

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	for (int i = 0; i < count; i++) {
		if (distance(c.rgb, src[i].rgb) < 0.01) {
			c.rgb = dst[i].rgb;
			break;
		}
	}
	if (flash && c.a > 0.0) {
		c.rgb = flash_color.rgb;
	}
	COLOR = c * modulate;
}
