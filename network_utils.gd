class_name NetworkUtils
extends RefCounted

static func get_local_ipv4() -> String:
	var addresses = IP.get_local_addresses()
	for addr in addresses:
		if addr.count(".") == 3 and not addr.begins_with("127.") and not addr.begins_with("169.254."):
			return addr
	return "127.0.0.1"

static func clean_host_ip(input: String) -> String:
	var text = input.strip_edges()
	if text.is_empty() or text.to_lower() == "localhost" or text == "127.0.0.1":
		return "127.0.0.1"
	
	# Fallback if a hexadecimal room code was entered
	if text.length() == 8 and text.is_valid_hex_number(false):
		return room_code_to_ip(text)
		
	return text

static func ip_to_room_code(ip: String) -> String:
	if ip == "127.0.0.1" or ip == "localhost":
		return "LOCAL-01"
	
	var parts = ip.split(".")
	if parts.size() != 4:
		return ip.replace(".", "-").to_upper()
	
	var hex = ""
	for p in parts:
		var val = p.to_int()
		hex += "%02X" % val
	return hex

static func room_code_to_ip(code: String) -> String:
	code = code.strip_edges().to_upper()
	if code == "LOCAL-01" or code == "127.0.0.1" or code == "LOCALHOST":
		return "127.0.0.1"
	
	if code.length() == 8 and code.is_valid_hex_number(false):
		var octets = []
		for i in range(0, 8, 2):
			var sub = code.substr(i, 2)
			octets.append(str(("0x" + sub).hex_to_int()))
		return ".".join(octets)
	
	return code.replace("-", ".")
