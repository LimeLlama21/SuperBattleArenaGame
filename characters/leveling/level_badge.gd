class_name LevelBadge
extends RefCounted

## Helper for generating and updating circular level badges across healthbars, HUD, and scoreboard.

static func get_origin_color(origin_id: String) -> Color:
	# Differing design based on character origin hook.
	# For now, all look the same per user request ("I'll add assets later, have them all look the same for now")
	match origin_id.to_lower().strip_edges():
		"mortal", "divine", "monstrous", _:
			return Color(0.85, 0.75, 0.35, 1.0) # Sleek golden-amber metallic ring

static func get_origin_style(origin_id: String, size: Vector2) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	var radius = int(min(size.x, size.y) * 0.5)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	
	style.bg_color = Color(0.08, 0.10, 0.15, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = get_origin_color(origin_id)
	return style

static func create_badge(origin_id: String = "mortal", level: int = 1, size: Vector2 = Vector2(28, 28), font_size: int = 13) -> Control:
	var container = Control.new()
	container.name = "LevelBadge"
	container.custom_minimum_size = size
	container.size = size
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel = PanelContainer.new()
	panel.name = "BadgeCircle"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = get_origin_style(origin_id, size)
	panel.add_theme_stylebox_override("panel", style)
	container.add_child(panel)

	var label = Label.new()
	label.name = "LevelNumber"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = str(level)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(label)

	return container

static func update_badge(badge: Control, level: int, origin_id: String = "mortal") -> void:
	if not badge:
		return
	var lbl = badge.get_node_or_null("LevelNumber") as Label
	if lbl:
		lbl.text = str(level)
	var panel = badge.get_node_or_null("BadgeCircle") as PanelContainer
	if panel:
		panel.add_theme_stylebox_override("panel", get_origin_style(origin_id, badge.size))
