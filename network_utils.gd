class_name NetworkUtils
extends RefCounted

const BACKEND_URL: String = "https://superbattlearenabackend.onrender.com"
const DEFAULT_PORT: int = 8910

const CODE_CHARS: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

static func generate_room_code(length: int = 6) -> String:
	var code = ""
	for i in range(length):
		var idx = randi() % CODE_CHARS.length()
		code += CODE_CHARS[idx]
	return code

static func get_local_ipv4() -> String:
	var addresses = IP.get_local_addresses()
	for addr in addresses:
		if addr.count(".") == 3 and not addr.begins_with("127.") and not addr.begins_with("169.254."):
			return addr
	return "127.0.0.1"

static func parse_host_address(raw_address: String, default_port: int = DEFAULT_PORT) -> Dictionary:
	var text = raw_address.strip_edges()
	if text.is_empty():
		return {"ip": "127.0.0.1", "port": default_port}
	
	var port = default_port
	var host_part = text
	
	# If port is appended with ':'
	if ":" in text:
		var last_colon = text.rfind(":")
		var p_str = text.substr(last_colon + 1).strip_edges()
		if p_str.is_valid_int():
			port = p_str.to_int()
			host_part = text.substr(0, last_colon).strip_edges()
	
	# If x-forwarded-for comma-separated chain is returned, take first client IP
	if "," in host_part:
		var parts = host_part.split(",")
		host_part = parts[0].strip_edges()
	
	if host_part.to_lower() == "localhost" or host_part.is_empty():
		host_part = "127.0.0.1"
		
	return {"ip": host_part, "port": port}

static func is_direct_ip_or_localhost(input: String) -> bool:
	var text = input.strip_edges().to_lower()
	if text == "localhost" or text == "127.0.0.1":
		return true
	if text.count(".") == 3:
		var parts = text.split(".")
		var all_num = true
		for p in parts:
			if not p.is_valid_int():
				all_num = false
				break
		if all_num:
			return true
	return false

static func clean_host_ip(input: String) -> String:
	var text = input.strip_edges()
	if text.is_empty() or text.to_lower() == "localhost" or text == "127.0.0.1":
		return "127.0.0.1"
	return text
