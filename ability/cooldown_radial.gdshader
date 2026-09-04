shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 overlay_color : source_color = vec4(0.04, 0.05, 0.08, 0.76);
uniform vec4 sweep_line_color : source_color = vec4(0.9, 0.95, 1.0, 0.95);
uniform float line_thickness : hint_range(0.001, 0.05) = 0.012;

void fragment() {
	vec2 centered = UV - vec2(0.5, 0.5);
	// atan(x, -y) -> 0 at top (0, -0.5), positive clockwise up to PI, negative counter-clockwise down to -PI
	float angle = atan(centered.x, -centered.y);
	if (angle < 0.0) {
		angle += 6.28318530718;
	}
	float norm_angle = angle / 6.28318530718; // 0.0 to 1.0 clockwise starting from top

	if (progress > 0.001) {
		if (norm_angle <= progress) {
			vec4 col = overlay_color;
			float diff = abs(norm_angle - progress);
			if (diff < line_thickness) {
				float t = 1.0 - (diff / line_thickness);
				col = mix(col, sweep_line_color, t * 0.9);
			}
			COLOR = col;
		} else {
			COLOR = vec4(0.0, 0.0, 0.0, 0.0);
		}
	} else {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	}
}
