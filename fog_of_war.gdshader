shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float fow_darkness : hint_range(0.0, 1.0) = 0.60;
uniform float fow_desaturation : hint_range(0.0, 1.0) = 0.85;
uniform vec4 fow_tint : source_color = vec4(0.65, 0.70, 0.80, 1.0);

void fragment() {
	vec4 screen_col = textureLod(screen_texture, SCREEN_UV, 0.0);
	// Mask texture from VisionSubViewport: 1.0 = Revealed vision, 0.0 = Fog of war
	float mask = texture(TEXTURE, UV).r;
	
	// Desaturate the background screen for the grayed-out fog look
	float gray = dot(screen_col.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desaturated = mix(screen_col.rgb, vec3(gray), fow_desaturation);
	
	// Apply subdued cool tint and brightness reduction so terrain is clearly visible but distinct
	vec3 fog_color = desaturated * fow_tint.rgb * fow_darkness;
	
	// Smoothly mix between grayed-out fog of war and full-color revealed vision
	COLOR = vec4(mix(fog_color, screen_col.rgb, mask), 1.0);
}
