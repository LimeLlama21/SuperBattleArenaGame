extends Node

## Comprehensive UI State Machine for Menu and In-Game UI
## Enforces lifecycle, presentation, and visibility for:
## 1. Non-Diegetic UI (2D screen panels, dialogs, overlays, HUD)
## 2. Spatial UI (3D world-anchored/billboard indicators: overhead HP, ground telegraphs, 3D reticles)
## 3. Diegetic UI (In-world physical/lore representations: safe zone storm wall, ground rings, guide lines)

enum State {
	MAIN_MENU = 0,
	JOIN_DIALOG = 1,
	LOBBY = 2,
	IN_MATCH = 3,
	MATCH_OVER = 4,
	PAUSED = 5
}

enum UICategory {
	NON_DIEGETIC = 0,
	SPATIAL = 1,
	DIEGETIC = 2
}

signal state_changed(old_state: int, new_state: int)
signal overlay_toggled(overlay_name: String, is_active: bool)
signal top_hud_updated(match_status_text: String, alert_text: String, status_color: Color)

static var instance: UIStateMachine = null

var current_state: State = State.MAIN_MENU
var previous_state: State = State.MAIN_MENU

# Overlay states (sub-screens active on top of primary states)
var active_overlays: Dictionary = {
	"scoreboard": false,
	"shop": false,
	"settings": false,
	"escape": false,
	"ability_modal": false,
	"upgrade_menu": false
}

# Registered element records: { "node": WeakRef, "category": int, "allowed_states": Array[int], "tag": String }
var _registered_elements: Array[Dictionary] = []

# Cached Top-Center HUD references and state
var top_match_status_text: String = ""
var top_match_status_color: Color = Color(1.0, 0.85, 0.25)
var top_hazard_warning_text: String = ""
var top_hazard_warning_visible: bool = false
var top_map_banner_text: String = ""
var top_map_banner_visible: bool = false

# Top-Center HUD UI container reference in Main
var top_center_container: Control = null
var top_match_status_label: Label = null
var top_hazard_warning_label: Label = null
var top_hazard_container: Control = null
var top_hazard_arrow: Label = null
var top_map_banner_label: Label = null

func _init() -> void:
	if instance == null:
		instance = self

func _enter_tree() -> void:
	if instance == null:
		instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

static func get_instance() -> UIStateMachine:
	return instance

# ==============================================================================
# STATE TRANSITIONS
# ==============================================================================

func transition_to(new_state: State) -> void:
	if current_state == new_state:
		return
	var old_state = current_state
	previous_state = old_state
	current_state = new_state
	
	# Close temporary in-game overlays if leaving match
	if new_state != State.IN_MATCH and new_state != State.PAUSED:
		active_overlays["scoreboard"] = false
		active_overlays["shop"] = false
		active_overlays["ability_modal"] = false
		active_overlays["upgrade_menu"] = false
		
	_apply_state(new_state)
	state_changed.emit(old_state, new_state)

func get_current_state() -> State:
	return current_state

func is_in_match() -> bool:
	return current_state == State.IN_MATCH or (current_state == State.PAUSED and previous_state == State.IN_MATCH)

func is_menu_active() -> bool:
	return current_state == State.MAIN_MENU or current_state == State.JOIN_DIALOG or current_state == State.LOBBY

# ==============================================================================
# OVERLAYS & MODALS
# ==============================================================================

func set_overlay(overlay_name: String, is_active: bool) -> void:
	if active_overlays.get(overlay_name) == is_active:
		return
	active_overlays[overlay_name] = is_active
	overlay_toggled.emit(overlay_name, is_active)

func is_overlay_active(overlay_name: String) -> bool:
	return active_overlays.get(overlay_name, false)

# ==============================================================================
# ELEMENT REGISTRATION & CATEGORIZATION
# ==============================================================================

## Register any node with a UI category and optional state restrictions.
## If allowed_states is empty, default category lifecycle applies:
## - NON_DIEGETIC: In-match HUD only visible during IN_MATCH/PAUSED; menus only in their screen.
## - SPATIAL: Visible only during IN_MATCH.
## - DIEGETIC: Visible & active only during IN_MATCH.
func register_element(node: Node, category: int, allowed_states: Array = [], tag: String = "") -> void:
	if not is_instance_valid(node):
		return
	# Remove existing record if already present
	unregister_element(node)
	_registered_elements.append({
		"ref": weakref(node),
		"category": category,
		"allowed_states": allowed_states,
		"tag": tag
	})
	_enforce_element_state(node, category, allowed_states, current_state)

func unregister_element(node: Node) -> void:
	for i in range(_registered_elements.size() - 1, -1, -1):
		var elem_ref = _registered_elements[i]["ref"].get_ref()
		if elem_ref == null or elem_ref == node:
			_registered_elements.remove_at(i)

# ==============================================================================
# STATE ENFORCEMENT ENGINE
# ==============================================================================

func _apply_state(state: State) -> void:
	_cleanup_stale_elements()
	
	for elem_data in _registered_elements:
		var node = elem_data["ref"].get_ref()
		if not node or not is_instance_valid(node):
			continue
		_enforce_element_state(node, elem_data["category"], elem_data["allowed_states"], state)
		
	# Update automatic Godot groups
	_enforce_group_state("ui_spatial", state == State.IN_MATCH)
	_enforce_group_state("ui_diegetic", state == State.IN_MATCH)
	_enforce_group_state("ui_hud", state == State.IN_MATCH)
	
	# Update Top HUD visibility
	if top_center_container and is_instance_valid(top_center_container):
		top_center_container.visible = (state == State.IN_MATCH)
		if state != State.IN_MATCH:
			top_match_status_text = ""
			top_hazard_warning_text = ""
			top_hazard_warning_visible = false

func _enforce_element_state(node: Node, category: int, allowed_states: Array, state: State) -> void:
	if not is_instance_valid(node):
		return
		
	var should_be_visible = false
	if not allowed_states.is_empty():
		should_be_visible = allowed_states.has(state)
	else:
		match category:
			UICategory.NON_DIEGETIC:
				should_be_visible = (state == State.IN_MATCH)
			UICategory.SPATIAL:
				should_be_visible = (state == State.IN_MATCH)
			UICategory.DIEGETIC:
				should_be_visible = (state == State.IN_MATCH)

	if "visible" in node:
		node.visible = should_be_visible
		
	# Call hook methods if implemented
	if node.has_method("on_ui_state_changed"):
		node.call("on_ui_state_changed", state, should_be_visible)

func _enforce_group_state(group_name: String, enabled: bool) -> void:
	if not is_inside_tree() or not get_tree():
		return
	for node in get_tree().get_nodes_in_group(group_name):
		if is_instance_valid(node) and "visible" in node:
			node.visible = enabled

func _cleanup_stale_elements() -> void:
	for i in range(_registered_elements.size() - 1, -1, -1):
		if _registered_elements[i]["ref"].get_ref() == null:
			_registered_elements.remove_at(i)

# ==============================================================================
# UNIFIED TOP-CENTER HUD COORDINATOR
# ==============================================================================

func setup_top_center_hud(container: Control, status_label: Label, warn_container: Control, warn_label: Label, arrow_label: Label, map_label: Label) -> void:
	top_center_container = container
	top_match_status_label = status_label
	top_hazard_container = warn_container
	top_hazard_warning_label = warn_label
	top_hazard_arrow = arrow_label
	top_map_banner_label = map_label
	
	if top_center_container:
		top_center_container.visible = (current_state == State.IN_MATCH)

func update_match_status(text: String, col: Color = Color(1.0, 0.85, 0.25)) -> void:
	top_match_status_text = text
	top_match_status_color = col
	if top_match_status_label and is_instance_valid(top_match_status_label):
		top_match_status_label.text = text
		top_match_status_label.add_theme_color_override("font_color", col)
		top_match_status_label.visible = not text.is_empty() and (current_state == State.IN_MATCH)
	top_hud_updated.emit(text, top_hazard_warning_text, col)

func update_hazard_warning(is_active: bool, text: String = "", arrow_rotation: float = 0.0) -> void:
	top_hazard_warning_visible = is_active and (current_state == State.IN_MATCH)
	top_hazard_warning_text = text if is_active else ""
	if top_hazard_container and is_instance_valid(top_hazard_container):
		top_hazard_container.visible = top_hazard_warning_visible
	if top_hazard_warning_label and is_instance_valid(top_hazard_warning_label):
		top_hazard_warning_label.text = text
		var alpha = 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.01)
		top_hazard_warning_label.modulate = Color(1.0, 0.25, 0.25, alpha)
	if top_hazard_arrow and is_instance_valid(top_hazard_arrow):
		top_hazard_arrow.rotation = arrow_rotation
