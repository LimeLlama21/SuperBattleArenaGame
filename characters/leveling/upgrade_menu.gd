class_name UpgradeMenu
extends CanvasLayer

const UpgradeTreesClass = preload("res://characters/leveling/upgrade_trees.gd")
const OriginRegistryClass = preload("res://characters/leveling/origins/origin_registry.gd")
const CharacterOriginClass = preload("res://characters/leveling/origins/character_origin.gd")

## Upgrade Menu for character leveling
## Displays three vertical slices: Resilience (Left), Fervor (Middle), Cunning (Right)
## Each slice has a distinct colored border matching its branch theme.
## Each slice features 3 small portraits stacked vertically with ample empty space.
## Vertical layout: Bottom is Tier 1, Middle is Tier 2, Top is Tier 3 (climbing progression).
## Enforces sequential tier selection: Tier N requires all prior tiers (1..N-1) in that branch.
## Underneath each portrait is a dedicated text box for the upgrade name (blank by default).
## Dynamically populates based on character origin (mortal, divine, monstrous).

signal upgrade_selected(origin: String, branch: String, tier: int, upgrade_data: Dictionary)
signal menu_opened(origin: String)
signal menu_closed

@export var current_origin: String = "mortal":
	set(value):
		current_origin = value.to_lower().strip_edges()
		if is_node_ready():
			refresh_menu()

# Node References
var root_control: Control
var backdrop: ColorRect
var main_panel: PanelContainer
var origin_label: Label
var origin_tabs_container: HBoxContainer
var strips_container: HBoxContainer
var close_btn: Button
var target_player: Node = null

# Progression tracking: origin_id -> { "resilience": 0..3, "fervor": 0..3, "cunning": 0..3 }
# 0 = none unlocked, 1 = Tier 1 unlocked, 2 = Tiers 1 & 2 unlocked, 3 = all 3 unlocked
var origin_branch_progress: Dictionary = {
	"mortal": { "resilience": 0, "fervor": 0, "cunning": 0 },
	"divine": { "resilience": 0, "fervor": 0, "cunning": 0 },
	"monstrous": { "resilience": 0, "fervor": 0, "cunning": 0 }
}

# Dictionaries holding UI elements and portrait slots for each branch
var branch_columns: Dictionary = {} # branch_name -> VBoxContainer
var portrait_nodes: Dictionary = {} # branch_name -> { tier: TextureRect }
var portrait_placeholders: Dictionary = {} # branch_name -> { tier: Label }
var portrait_frames: Dictionary = {} # branch_name -> { tier: PanelContainer }
var portrait_name_labels: Dictionary = {} # branch_name -> { tier: Label }
var portrait_name_boxes: Dictionary = {} # branch_name -> { tier: PanelContainer }

func _ready() -> void:
	layer = 15
	_build_ui_structure()
	refresh_menu()
	# By default, start hidden unless explicitly opened
	hide_menu()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func open(origin_id: String = "", player: Node = null) -> void:
	if player != null:
		target_player = player
	if not origin_id.is_empty():
		current_origin = origin_id
	elif is_instance_valid(target_player) and "character_origin" in target_player and not str(target_player.character_origin).is_empty():
		current_origin = str(target_player.character_origin)
	else:
		refresh_menu()
	show()
	menu_opened.emit(current_origin)
	
	# Update UI State Machine overlay if available
	var uism = get_node_or_null("/root/UIStateMachine")
	if uism and uism.has_method("set_overlay"):
		uism.set_overlay("upgrade_menu", true)

func close() -> void:
	hide_menu()
	menu_closed.emit()
	
	var uism = get_node_or_null("/root/UIStateMachine")
	if uism and uism.has_method("set_overlay"):
		uism.set_overlay("upgrade_menu", false)

func hide_menu() -> void:
	hide()

func set_origin(origin_id: String) -> void:
	current_origin = origin_id

# --- Progression State Management ---

func get_branch_tier(origin_id: String, branch_name: String) -> int:
	var o_key = origin_id.to_lower().strip_edges()
	var b_key = branch_name.to_lower().strip_edges()
	return origin_branch_progress.get(o_key, {}).get(b_key, 0)

func set_branch_tier(origin_id: String, branch_name: String, tier_level: int) -> void:
	var o_key = origin_id.to_lower().strip_edges()
	var b_key = branch_name.to_lower().strip_edges()
	if not origin_branch_progress.has(o_key):
		origin_branch_progress[o_key] = { "resilience": 0, "fervor": 0, "cunning": 0 }
	origin_branch_progress[o_key][b_key] = clamp(tier_level, 0, 3)
	refresh_menu()

func reset_upgrades(origin_id: String = "") -> void:
	if origin_id.is_empty():
		for key in origin_branch_progress:
			origin_branch_progress[key] = { "resilience": 0, "fervor": 0, "cunning": 0 }
	else:
		var o_key = origin_id.to_lower().strip_edges()
		if origin_branch_progress.has(o_key):
			origin_branch_progress[o_key] = { "resilience": 0, "fervor": 0, "cunning": 0 }
	refresh_menu()

func is_tier_unlocked(branch_name: String, tier: int) -> bool:
	return get_branch_tier(current_origin, branch_name) >= tier

func can_unlock_tier(branch_name: String, tier: int) -> bool:
	return get_branch_tier(current_origin, branch_name) == (tier - 1)

# --- Asset & Name Helpers ---

## Assigns a texture asset to a specific branch tier portrait (for future assets)
func set_upgrade_portrait(branch_name: String, tier: int, texture: Texture2D) -> void:
	var b_key = branch_name.to_lower().strip_edges()
	if portrait_nodes.has(b_key) and portrait_nodes[b_key].has(tier):
		var tex_rect: TextureRect = portrait_nodes[b_key][tier]
		var placeholder: Label = portrait_placeholders.get(b_key, {}).get(tier, null)
		if tex_rect:
			tex_rect.texture = texture
			tex_rect.visible = (texture != null)
		if placeholder:
			placeholder.visible = (texture == null)

## Returns the TextureRect node for a specific portrait slot
func get_upgrade_portrait(branch_name: String, tier: int) -> TextureRect:
	var b_key = branch_name.to_lower().strip_edges()
	if portrait_nodes.has(b_key) and portrait_nodes[b_key].has(tier):
		return portrait_nodes[b_key][tier]
	return null

## Sets the name in the text box underneath a specific portrait
func set_upgrade_name(branch_name: String, tier: int, name_text: String) -> void:
	var b_key = branch_name.to_lower().strip_edges()
	if portrait_name_labels.has(b_key) and portrait_name_labels[b_key].has(tier):
		var lbl: Label = portrait_name_labels[b_key][tier]
		if lbl:
			lbl.text = name_text

## Returns the current text from the name text box
func get_upgrade_name(branch_name: String, tier: int) -> String:
	var b_key = branch_name.to_lower().strip_edges()
	if portrait_name_labels.has(b_key) and portrait_name_labels[b_key].has(tier):
		var lbl: Label = portrait_name_labels[b_key][tier]
		if lbl:
			return lbl.text
	return ""

# --- Menu Refresh & Construction ---

## Rebuilds/updates the 3 vertical strips based on the current origin's tree
func refresh_menu() -> void:
	if not strips_container:
		return
	
	var origin_key = current_origin.to_lower().strip_edges()
	var origin_res = OriginRegistryClass.get_origin(origin_key)
	var origin_title = origin_res.display_name.to_upper() if origin_res else origin_key.capitalize()
	
	if origin_label:
		origin_label.text = "ORIGIN TREE: %s" % origin_title
		if origin_res:
			origin_label.modulate = origin_res.theme_color
		else:
			origin_label.modulate = Color.WHITE
			
	_update_origin_tab_styles()
	
	var tree_data = UpgradeTreesClass.get_tree(origin_key)
	
	portrait_nodes.clear()
	portrait_placeholders.clear()
	portrait_frames.clear()
	portrait_name_labels.clear()
	portrait_name_boxes.clear()
	
	for branch_name in UpgradeTreesClass.BRANCHES:
		var column = branch_columns.get(branch_name)
		if not column:
			continue
		
		var branch_upgrades: Array = tree_data.get(branch_name, [])
		var cards_vbox = column.get_node_or_null("CardsVBox")
		if not cards_vbox:
			continue
		
		# Clear existing slots in this strip
		for child in cards_vbox.get_children():
			child.queue_free()
		
		# Top flexible spacer for generous empty space
		var top_spacer = Control.new()
		top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cards_vbox.add_child(top_spacer)
		
		# Build 3 sequential small portrait slots with name boxes:
		# Top: Tier 3 (Capstone)
		# Middle: Tier 2
		# Bottom: Tier 1 (Starting Tier)
		for tier in [3, 2, 1]:
			var upgrade_data: Dictionary = {}
			var tier_idx = tier - 1
			if tier_idx < branch_upgrades.size():
				upgrade_data = branch_upgrades[tier_idx]
			else:
				upgrade_data = {
					"id": "%s_%s_%d" % [origin_key, branch_name, tier],
					"tier": tier,
					"name": "%s Tier %d" % [branch_name.capitalize(), tier],
					"description": "Upgrade placeholder"
				}
			
			var portrait_slot = _create_portrait_slot(branch_name, tier, upgrade_data)
			cards_vbox.add_child(portrait_slot)
			
			# Connector vertical line pointing upwards between tiers
			if tier > 1:
				var connector = _create_tier_connector(branch_name, tier - 1)
				cards_vbox.add_child(connector)
		
		# Bottom flexible spacer for generous empty space
		var bottom_spacer = Control.new()
		bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cards_vbox.add_child(bottom_spacer)

func _create_portrait_slot(branch_name: String, tier: int, upgrade_data: Dictionary) -> Control:
	var meta = UpgradeTreesClass.get_branch_metadata(branch_name)
	var branch_color: Color = meta.get("color", Color.WHITE)
	
	var current_unlocked = get_branch_tier(current_origin, branch_name)
	var is_acquired = (tier <= current_unlocked)
	var is_available = (tier == current_unlocked + 1)
	var is_locked = (tier > current_unlocked + 1)
	
	# CenterContainer ensures the portrait & text box take up a compact footprint with wide margins
	var center = CenterContainer.new()
	center.name = "PortraitCenter_T%d" % tier
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Vertical container stacking the portrait frame above its name text box
	var slot_vbox = VBoxContainer.new()
	slot_vbox.name = "SlotVBox_T%d" % tier
	slot_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_vbox.add_theme_constant_override("separation", 6)
	center.add_child(slot_vbox)
	
	# 1. The small portrait frame (64x64)
	var frame = PanelContainer.new()
	frame.name = "PortraitFrame_T%d" % tier
	frame.custom_minimum_size = Vector2(64, 64)
	frame.pivot_offset = Vector2(32, 32)
	
	# Frame styling based on progression state (Acquired / Available / Locked)
	var frame_style = StyleBoxFlat.new()
	frame_style.corner_radius_top_left = 8
	frame_style.corner_radius_top_right = 8
	frame_style.corner_radius_bottom_left = 8
	frame_style.corner_radius_bottom_right = 8
	frame_style.content_margin_left = 4
	frame_style.content_margin_top = 4
	frame_style.content_margin_right = 4
	frame_style.content_margin_bottom = 4
	
	var hover_style: StyleBoxFlat = null
	
	if is_acquired:
		# Acquired: Radiant branch glow, brighter background
		frame_style.bg_color = branch_color.lerp(Color.BLACK, 0.72)
		frame_style.border_color = branch_color.lightened(0.25)
		frame_style.border_width_left = 3
		frame_style.border_width_top = 3
		frame_style.border_width_right = 3
		frame_style.border_width_bottom = 3
		frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		hover_style = frame_style.duplicate() as StyleBoxFlat
		hover_style.border_color = branch_color.lightened(0.4)
		hover_style.bg_color = branch_color.lerp(Color.BLACK, 0.65)
	elif is_available:
		# Available: Ready to select, pulsing accent
		frame_style.bg_color = Color(0.08, 0.10, 0.16, 0.95)
		frame_style.border_color = branch_color
		frame_style.border_width_left = 2
		frame_style.border_width_top = 2
		frame_style.border_width_right = 2
		frame_style.border_width_bottom = 2
		frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		hover_style = frame_style.duplicate() as StyleBoxFlat
		hover_style.bg_color = Color(0.14, 0.18, 0.28, 0.98)
		hover_style.border_color = branch_color.lightened(0.35)
		hover_style.border_width_left = 3
		hover_style.border_width_top = 3
		hover_style.border_width_right = 3
		hover_style.border_width_bottom = 3
	else:
		# Locked: Dimmed, requires prior tier
		frame_style.bg_color = Color(0.04, 0.05, 0.08, 0.85)
		frame_style.border_color = branch_color.lerp(Color.BLACK, 0.7)
		frame_style.border_width_left = 1
		frame_style.border_width_top = 1
		frame_style.border_width_right = 1
		frame_style.border_width_bottom = 1
		frame.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		frame.modulate = Color(0.7, 0.7, 0.75, 0.8)
		
		hover_style = frame_style.duplicate() as StyleBoxFlat
		hover_style.border_color = Color(0.6, 0.2, 0.2, 0.8) # Red-tinted lock indicator on hover
	
	frame.add_theme_stylebox_override("panel", frame_style)
	
	# Inner stack: TextureRect for asset, or Placeholder Glyph / Tier
	var inner_box = CenterContainer.new()
	inner_box.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.add_child(inner_box)
	
	# TextureRect for future actual asset
	var portrait_tex = TextureRect.new()
	portrait_tex.name = "PortraitTexture"
	portrait_tex.custom_minimum_size = Vector2(56, 56)
	portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_tex.mouse_filter = Control.MOUSE_FILTER_PASS
	inner_box.add_child(portrait_tex)
	
	# Placeholder label/icon (visible when texture is null)
	var roman_numerals = ["I", "II", "III"]
	var roman = roman_numerals[clamp(tier - 1, 0, 2)]
	
	var placeholder_label = Label.new()
	placeholder_label.name = "PlaceholderLabel"
	placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder_label.add_theme_font_size_override("font_size", 20)
	placeholder_label.mouse_filter = Control.MOUSE_FILTER_PASS
	
	if is_acquired:
		placeholder_label.text = "✓"
		placeholder_label.add_theme_color_override("font_color", branch_color.lightened(0.35))
	elif is_available:
		placeholder_label.text = roman
		placeholder_label.add_theme_color_override("font_color", branch_color)
	else:
		placeholder_label.text = "🔒"
		placeholder_label.add_theme_font_size_override("font_size", 16)
		placeholder_label.add_theme_color_override("font_color", Color(0.55, 0.60, 0.68))
		
	inner_box.add_child(placeholder_label)
	
	# Check if asset provided in upgrade_data
	var asset = upgrade_data.get("icon", upgrade_data.get("portrait", null))
	if asset is Texture2D:
		portrait_tex.texture = asset
		portrait_tex.visible = true
		placeholder_label.visible = false
	else:
		portrait_tex.texture = null
		portrait_tex.visible = false
		placeholder_label.visible = true
	
	# Small Tier Corner Tag
	var tier_tag = Label.new()
	tier_tag.text = roman
	tier_tag.add_theme_font_size_override("font_size", 9)
	if is_acquired:
		tier_tag.add_theme_color_override("font_color", branch_color.lightened(0.35))
	elif is_available:
		tier_tag.add_theme_color_override("font_color", branch_color.lightened(0.2))
	else:
		tier_tag.add_theme_color_override("font_color", Color(0.45, 0.50, 0.58))
	tier_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tier_tag.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	tier_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(tier_tag)
	
	# Tooltip with upgrade info and lock status
	var up_name = upgrade_data.get("name", "%s Tier %d" % [branch_name.capitalize(), tier])
	var up_desc = upgrade_data.get("description", "Upgrade placeholder.")
	if is_acquired:
		frame.tooltip_text = "[ACQUIRED] %s - Tier %s\n%s\n%s" % [branch_name.to_upper(), roman, up_name, up_desc]
	elif is_available:
		frame.tooltip_text = "[AVAILABLE - Click to Unlock] %s - Tier %s\n%s\n%s" % [branch_name.to_upper(), roman, up_name, up_desc]
	else:
		frame.tooltip_text = "[LOCKED - Requires Tier %d First] %s - Tier %s\n%s\n%s" % [tier - 1, branch_name.to_upper(), roman, up_name, up_desc]
	
	slot_vbox.add_child(frame)
	
	# 2. Text box for the name underneath the portrait (blank for now)
	var name_box = PanelContainer.new()
	name_box.name = "NameBox_T%d" % tier
	name_box.custom_minimum_size = Vector2(110, 22)
	name_box.mouse_default_cursor_shape = frame.mouse_default_cursor_shape
	
	var name_box_style = StyleBoxFlat.new()
	name_box_style.corner_radius_top_left = 4
	name_box_style.corner_radius_top_right = 4
	name_box_style.corner_radius_bottom_left = 4
	name_box_style.corner_radius_bottom_right = 4
	name_box_style.content_margin_left = 6
	name_box_style.content_margin_right = 6
	name_box_style.content_margin_top = 2
	name_box_style.content_margin_bottom = 2
	
	var name_box_hover_style = name_box_style.duplicate() as StyleBoxFlat
	
	if is_acquired:
		name_box_style.bg_color = branch_color.lerp(Color.BLACK, 0.8)
		name_box_style.border_color = branch_color
		name_box_style.border_width_left = 1
		name_box_style.border_width_top = 1
		name_box_style.border_width_right = 1
		name_box_style.border_width_bottom = 1
		name_box_hover_style.border_color = branch_color.lightened(0.3)
	elif is_available:
		name_box_style.bg_color = Color(0.06, 0.08, 0.13, 0.90)
		name_box_style.border_color = branch_color.lerp(Color.BLACK, 0.45)
		name_box_style.border_width_left = 1
		name_box_style.border_width_top = 1
		name_box_style.border_width_right = 1
		name_box_style.border_width_bottom = 1
		name_box_hover_style.border_color = branch_color
		name_box_hover_style.bg_color = Color(0.10, 0.13, 0.20, 0.95)
	else:
		name_box_style.bg_color = Color(0.04, 0.05, 0.08, 0.80)
		name_box_style.border_color = branch_color.lerp(Color.BLACK, 0.75)
		name_box_style.border_width_left = 1
		name_box_style.border_width_top = 1
		name_box_style.border_width_right = 1
		name_box_style.border_width_bottom = 1
		name_box_hover_style.border_color = Color(0.5, 0.2, 0.2, 0.8)
	
	name_box.add_theme_stylebox_override("panel", name_box_style)
	
	var name_label = Label.new()
	name_label.name = "NameLabel"
	var up_id_check = upgrade_data.get("id", "")
	var up_name_check = upgrade_data.get("name", "")
	if up_id_check == "atalantas_stride" or up_name_check == "Atalanta's Stride" or up_id_check == "quick_feet" or up_name_check == "Quick Feet":
		name_label.text = "Atalanta's Stride"
	elif up_id_check == "ascetic_touch" or up_name_check == "Ascetic Touch" or up_id_check == "spellthief" or up_name_check == "Spellthief":
		name_label.text = "Ascetic Touch"
	elif up_id_check == "hymn_of_the_underworld" or up_name_check == "Hymn of the Underworld":
		name_label.text = "Hymn of the Underworld"
	else:
		name_label.text = "" # Left blank for now for placeholder upgrades as requested
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.97))
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	name_box.add_child(name_label)
	
	slot_vbox.add_child(name_box)
	
	# Store references
	if not portrait_nodes.has(branch_name):
		portrait_nodes[branch_name] = {}
	portrait_nodes[branch_name][tier] = portrait_tex
	
	if not portrait_placeholders.has(branch_name):
		portrait_placeholders[branch_name] = {}
	portrait_placeholders[branch_name][tier] = placeholder_label
	
	if not portrait_frames.has(branch_name):
		portrait_frames[branch_name] = {}
	portrait_frames[branch_name][tier] = frame
	
	if not portrait_name_labels.has(branch_name):
		portrait_name_labels[branch_name] = {}
	portrait_name_labels[branch_name][tier] = name_label
	
	if not portrait_name_boxes.has(branch_name):
		portrait_name_boxes[branch_name] = {}
	portrait_name_boxes[branch_name][tier] = name_box
	
	# Hover & Click Interactivity on Frame
	frame.mouse_entered.connect(func():
		frame.add_theme_stylebox_override("panel", hover_style)
		name_box.add_theme_stylebox_override("panel", name_box_hover_style)
		if not is_locked:
			var tw = frame.create_tween()
			tw.tween_property(frame, "scale", Vector2(1.08, 1.08), 0.1)
	)
	frame.mouse_exited.connect(func():
		frame.add_theme_stylebox_override("panel", frame_style)
		name_box.add_theme_stylebox_override("panel", name_box_style)
		if not is_locked:
			var tw = frame.create_tween()
			tw.tween_property(frame, "scale", Vector2(1.0, 1.0), 0.1)
	)
	frame.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_upgrade_card_clicked(current_origin, branch_name, tier, upgrade_data)
	)
	
	# Hover & Click Interactivity on Name Box
	name_box.mouse_entered.connect(func():
		frame.add_theme_stylebox_override("panel", hover_style)
		name_box.add_theme_stylebox_override("panel", name_box_hover_style)
	)
	name_box.mouse_exited.connect(func():
		frame.add_theme_stylebox_override("panel", frame_style)
		name_box.add_theme_stylebox_override("panel", name_box_style)
	)
	name_box.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_upgrade_card_clicked(current_origin, branch_name, tier, upgrade_data)
	)
	
	return center

func _create_tier_connector(branch_name: String, lower_tier: int) -> Control:
	var meta = UpgradeTreesClass.get_branch_metadata(branch_name)
	var branch_color: Color = meta.get("color", Color.WHITE)
	var current_tier = get_branch_tier(current_origin, branch_name)
	
	# Progress indicates whether the path upwards from lower_tier to (lower_tier + 1) is active
	var is_path_completed = (current_tier >= lower_tier + 1)
	var is_path_reachable = (current_tier >= lower_tier)
	
	var container = CenterContainer.new()
	container.custom_minimum_size = Vector2(0, 26)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var line_box = VBoxContainer.new()
	line_box.alignment = BoxContainer.ALIGNMENT_CENTER
	line_box.add_theme_constant_override("separation", 2)
	line_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(line_box)
	
	# Upward pointing arrow (climbing progression: Tier 1 at bottom -> Tier 3 at top)
	var arrow = Label.new()
	arrow.text = "▲"
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.add_theme_font_size_override("font_size", 9)
	if is_path_completed:
		arrow.add_theme_color_override("font_color", branch_color.lightened(0.35))
	elif is_path_reachable:
		arrow.add_theme_color_override("font_color", branch_color)
	else:
		arrow.add_theme_color_override("font_color", branch_color.lerp(Color.BLACK, 0.7))
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_box.add_child(arrow)
	
	var line = ColorRect.new()
	line.custom_minimum_size = Vector2(2, 14)
	if is_path_completed:
		line.color = branch_color.lightened(0.25)
	elif is_path_reachable:
		line.color = branch_color
	else:
		line.color = branch_color.lerp(Color.BLACK, 0.7)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_box.add_child(line)
	
	return container

func _on_upgrade_card_clicked(origin: String, branch: String, tier: int, data: Dictionary) -> void:
	var current_tier = get_branch_tier(origin, branch)
	
	if tier <= current_tier:
		# Already unlocked/acquired; emit inspection/info signal if needed
		return
	
	if tier == current_tier + 1:
		# Valid sequential progression: unlock this tier!
		set_branch_tier(origin, branch, tier)
		var up_id = data.get("id", "%s_%s_%d" % [origin, branch, tier])
		if is_instance_valid(target_player) and target_player.has_method("apply_upgrade"):
			target_player.apply_upgrade(up_id, data)
		upgrade_selected.emit(origin, branch, tier, data)
	else:
		# Locked: player clicked a higher tier before unlocking prior tiers
		_shake_locked_slot(branch, tier)

func _shake_locked_slot(branch_name: String, tier: int) -> void:
	var frame = portrait_frames.get(branch_name, {}).get(tier, null)
	if frame and is_instance_valid(frame):
		var tw = frame.create_tween()
		var orig_pos = frame.position
		tw.tween_property(frame, "position", orig_pos + Vector2(-6, 0), 0.04)
		tw.tween_property(frame, "position", orig_pos + Vector2(6, 0), 0.04)
		tw.tween_property(frame, "position", orig_pos + Vector2(-4, 0), 0.04)
		tw.tween_property(frame, "position", orig_pos, 0.04)

## Builds the overarching UI nodes programmatically
func _build_ui_structure() -> void:
	# Root full-screen control
	root_control = Control.new()
	root_control.name = "Root"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root_control.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(root_control)
	
	# Darkened Backdrop
	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.03, 0.06, 0.85)
	backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			close()
	)
	root_control.add_child(backdrop)
	
	# Main Window Panel Container (Centered)
	main_panel = PanelContainer.new()
	main_panel.name = "MainPanel"
	main_panel.anchors_preset = Control.PRESET_CENTER
	main_panel.anchor_left = 0.5
	main_panel.anchor_top = 0.5
	main_panel.anchor_right = 0.5
	main_panel.anchor_bottom = 0.5
	main_panel.offset_left = -460.0
	main_panel.offset_top = -320.0
	main_panel.offset_right = 460.0
	main_panel.offset_bottom = 320.0
	main_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.12, 0.98)
	panel_style.border_color = Color(0.24, 0.32, 0.48, 0.85)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.content_margin_left = 20
	panel_style.content_margin_top = 16
	panel_style.content_margin_right = 20
	panel_style.content_margin_bottom = 20
	main_panel.add_theme_stylebox_override("panel", panel_style)
	root_control.add_child(main_panel)
	
	var window_vbox = VBoxContainer.new()
	window_vbox.add_theme_constant_override("separation", 14)
	main_panel.add_child(window_vbox)
	
	# 1. Header Bar: Title, Origin Indicator & Tabs, Reset Button, Close Button
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 16)
	window_vbox.add_child(header_hbox)
	
	var title_vbox = VBoxContainer.new()
	title_vbox.add_theme_constant_override("separation", 2)
	header_hbox.add_child(title_vbox)
	
	var main_title = Label.new()
	main_title.text = "⚡ UPGRADE FORGE"
	main_title.add_theme_font_size_override("font_size", 18)
	main_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	title_vbox.add_child(main_title)
	
	origin_label = Label.new()
	origin_label.text = "ORIGIN TREE: MORTAL"
	origin_label.add_theme_font_size_override("font_size", 12)
	title_vbox.add_child(origin_label)
	
	var header_spacer = Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_spacer)
	
	# Origin Switch Tabs (Mortal | Divine | Monstrous) for seamless preview/testing
	origin_tabs_container = HBoxContainer.new()
	origin_tabs_container.add_theme_constant_override("separation", 6)
	header_hbox.add_child(origin_tabs_container)
	
	for o_id in [CharacterOriginClass.ID_MORTAL, CharacterOriginClass.ID_DIVINE, CharacterOriginClass.ID_MONSTROUS]:
		var tab_btn = Button.new()
		tab_btn.name = "OriginTab_%s" % o_id
		tab_btn.text = o_id.capitalize()
		tab_btn.custom_minimum_size = Vector2(80, 28)
		tab_btn.add_theme_font_size_override("font_size", 11)
		tab_btn.pressed.connect(func():
			current_origin = o_id
		)
		origin_tabs_container.add_child(tab_btn)
	
	# Reset button for testing progression
	var reset_btn = Button.new()
	reset_btn.name = "ResetButton"
	reset_btn.text = "Reset"
	reset_btn.custom_minimum_size = Vector2(50, 28)
	reset_btn.add_theme_font_size_override("font_size", 11)
	reset_btn.tooltip_text = "Reset upgrade progression for this origin"
	reset_btn.pressed.connect(func():
		reset_upgrades(current_origin)
	)
	header_hbox.add_child(reset_btn)
	
	close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(30, 28)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.pressed.connect(close)
	header_hbox.add_child(close_btn)
	
	# Subtitle Warning/Guidance banner
	var guidance_lbl = Label.new()
	guidance_lbl.text = "Unlock upgrades from bottom to top (Tier 1 → Tier 2 → Tier 3). Caution: You are vulnerable while accessing the forge."
	guidance_lbl.add_theme_font_size_override("font_size", 11)
	guidance_lbl.add_theme_color_override("font_color", Color(0.70, 0.75, 0.85))
	window_vbox.add_child(guidance_lbl)
	
	# 2. Main Three Vertical Slices (HBoxContainer)
	strips_container = HBoxContainer.new()
	strips_container.name = "StripsContainer"
	strips_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	strips_container.add_theme_constant_override("separation", 16)
	window_vbox.add_child(strips_container)
	
	# Build the three vertical slices: Left: Resilience, Middle: Fervor, Right: Cunning
	for branch_name in UpgradeTreesClass.BRANCHES:
		var strip_panel = _create_vertical_strip_section(branch_name)
		strips_container.add_child(strip_panel)

func _create_vertical_strip_section(branch_name: String) -> PanelContainer:
	var meta = UpgradeTreesClass.get_branch_metadata(branch_name)
	var title_text: String = meta.get("title", branch_name.to_upper())
	var subtitle_text: String = meta.get("subtitle", "")
	var branch_color: Color = meta.get("color", Color.WHITE)
	var icon_sym: String = meta.get("icon_symbol", "◆")
	
	var strip = PanelContainer.new()
	strip.name = "Strip_%s" % branch_name
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Distinct colored border framing each vertical slice
	var strip_style = StyleBoxFlat.new()
	strip_style.bg_color = Color(0.05, 0.07, 0.11, 0.92)
	strip_style.border_color = branch_color
	strip_style.border_width_left = 2
	strip_style.border_width_top = 2
	strip_style.border_width_right = 2
	strip_style.border_width_bottom = 2
	strip_style.corner_radius_top_left = 10
	strip_style.corner_radius_top_right = 10
	strip_style.corner_radius_bottom_left = 10
	strip_style.corner_radius_bottom_right = 10
	strip_style.content_margin_left = 14
	strip_style.content_margin_top = 14
	strip_style.content_margin_right = 14
	strip_style.content_margin_bottom = 14
	strip.add_theme_stylebox_override("panel", strip_style)
	
	var strip_vbox = VBoxContainer.new()
	strip_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	strip_vbox.add_theme_constant_override("separation", 10)
	strip.add_child(strip_vbox)
	
	# Strip Header Box
	var header_box = PanelContainer.new()
	header_box.custom_minimum_size = Vector2(0, 48)
	
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = branch_color.lerp(Color.BLACK, 0.82)
	header_style.border_color = branch_color
	header_style.border_width_left = 1
	header_style.border_width_top = 1
	header_style.border_width_right = 1
	header_style.border_width_bottom = 2
	header_style.corner_radius_top_left = 6
	header_style.corner_radius_top_right = 6
	header_style.corner_radius_bottom_left = 6
	header_style.corner_radius_bottom_right = 6
	header_style.content_margin_left = 10
	header_style.content_margin_top = 6
	header_style.content_margin_right = 10
	header_style.content_margin_bottom = 6
	header_box.add_theme_stylebox_override("panel", header_style)
	strip_vbox.add_child(header_box)
	
	var header_vbox = VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 2)
	header_box.add_child(header_vbox)
	
	var title_lbl = Label.new()
	title_lbl.text = "%s %s" % [icon_sym, title_text]
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", branch_color)
	header_vbox.add_child(title_lbl)
	
	var sub_lbl = Label.new()
	sub_lbl.text = subtitle_text
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", branch_color.lerp(Color.WHITE, 0.4))
	header_vbox.add_child(sub_lbl)
	
	# Cards / Portraits Container (Expanded vertical track with ample empty space)
	var cards_vbox = VBoxContainer.new()
	cards_vbox.name = "CardsVBox"
	cards_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_vbox.add_theme_constant_override("separation", 0)
	strip_vbox.add_child(cards_vbox)
	
	branch_columns[branch_name] = strip_vbox
	return strip

func _update_origin_tab_styles() -> void:
	if not origin_tabs_container:
		return
	for child in origin_tabs_container.get_children():
		if child is Button:
			var is_active = child.name.ends_with(current_origin)
			if is_active:
				child.modulate = Color(1.2, 1.2, 1.2, 1.0)
			else:
				child.modulate = Color(0.7, 0.7, 0.7, 0.8)
