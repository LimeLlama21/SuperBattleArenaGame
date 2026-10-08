class_name CharacterOrigin
extends Resource

enum Type {
	MORTAL,
	DIVINE,
	MONSTROUS
}

const ID_MORTAL = "mortal"
const ID_DIVINE = "divine"
const ID_MONSTROUS = "monstrous"

const VALID_IDS: Array[String] = [
	ID_MORTAL,
	ID_DIVINE,
	ID_MONSTROUS
]

@export_group("Identity")
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var theme_color: Color = Color.WHITE
@export var icon: Texture2D = null

static func type_to_id(p_type: Type) -> String:
	match p_type:
		Type.MORTAL:
			return ID_MORTAL
		Type.DIVINE:
			return ID_DIVINE
		Type.MONSTROUS:
			return ID_MONSTROUS
		_:
			return ""

static func id_to_type(p_id: String) -> Type:
	match p_id.strip_edges().to_lower():
		ID_MORTAL:
			return Type.MORTAL
		ID_DIVINE:
			return Type.DIVINE
		ID_MONSTROUS:
			return Type.MONSTROUS
		_:
			return Type.MORTAL

static func normalize_id(val: Variant) -> String:
	if val is Type:
		return type_to_id(val)
	if val is int:
		return type_to_id(val as Type)
	if val is String:
		return val.strip_edges().to_lower()
	if val is CharacterOrigin:
		return val.id.strip_edges().to_lower()
	return ""

static func is_valid_id(val: Variant) -> bool:
	var norm = normalize_id(val)
	return VALID_IDS.has(norm)
