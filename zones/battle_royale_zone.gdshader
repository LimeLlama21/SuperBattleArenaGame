shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque;

uniform vec4 base_color : source_color = vec4(0.12, 0.65, 1.0, 0.35);
uniform vec4 rim_color : source_color = vec4(0.45, 0.95, 1.0, 0.9);
uniform vec4 warning_color : source_color = vec4(1.0, 0.35, 0.1, 0.85);

uniform float rim_power : hint_range(0.5, 6.0) = 2.2;
uniform float scanline_speed : hint_range(0.0, 10.0) = 1.5;
uniform float scanline_frequency : hint_range(1.0, 40.0) = 12.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.5;
uniform float warning_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float height_fade_range : hint_range(0.01, 0.5) = 0.15;

void fragment() {
	// Vertical gradient fading at bottom and top of the cylinder
	float edge_fade_bottom = smoothstep(0.0, height_fade_range, UV.y);
	float edge_fade_top = smoothstep(1.0, 1.0 - height_fade_range, UV.y);
	float vertical_mask = edge_fade_bottom * edge_fade_top;
	
	// Animated upward scanlines / energy waves
	float wave1 = sin((UV.y * scanline_frequency) - (TIME * scanline_speed));
	float wave2 = cos((UV.x * 24.0) + (TIME * scanline_speed * 0.7));
	float scanline = clamp((wave1 * 0.5 + 0.5) * (wave2 * 0.25 + 0.75), 0.0, 1.0);
	
	// Pulsing intensity
	float pulse = 0.85 + 0.15 * sin(TIME * pulse_speed);
	
	// Fresnel rim effect (visible from both inside and outside due to cull_disabled)
	vec3 view_dir = normalize(VIEW);
	vec3 norm = normalize(NORMAL);
	float fresnel = pow(1.0 - abs(dot(norm, view_dir)), rim_power);
	
	// Dynamic warning blend
	vec4 current_base = mix(base_color, warning_color, warning_intensity);
	vec4 current_rim = mix(rim_color, warning_color, warning_intensity);
	
	// Combine emission and albedo
	vec3 final_color = mix(current_base.rgb, current_rim.rgb, fresnel * 0.7 + scanline * 0.3);
	float final_alpha = (current_base.a + fresnel * current_rim.a + scanline * 0.18) * vertical_mask * pulse;
	final_alpha = clamp(final_alpha, 0.0, 0.95);
	
	ALBEDO = final_color;
	EMISSION = final_color * (1.5 + warning_intensity * 2.0);
	ALPHA = final_alpha;
}
