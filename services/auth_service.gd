extends Node

## Persisted guest identity. A later Nakama device login uses this id, then
## link_apple / link_google attach a store account to the same session.

const DEFAULT_PATH := "user://auth/identity.cfg"

var save_path: String = DEFAULT_PATH
var guest_id: String = ""
var nakama_host: String = ""
var nakama_port: int = 7350
var nakama_scheme: String = "https"
var session_token: String = ""
var refresh_token: String = ""


func _ready() -> void:
	ensure_guest_id()


func ensure_guest_id() -> String:
	var directory := save_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(directory)
	var config := ConfigFile.new()
	if config.load(save_path) == OK:
		var existing := str(config.get_value("auth", "guest_id", ""))
		if _is_uuid(existing):
			guest_id = existing
			return guest_id
	guest_id = _uuid4()
	config.set_value("auth", "guest_id", guest_id)
	config.set_value("auth", "created_unix", int(Time.get_unix_time_from_system()))
	config.save(save_path)
	return guest_id


func authenticate_device() -> Dictionary:
	if guest_id.is_empty():
		ensure_guest_id()
	var result := NakamaSlot.authenticate_device(guest_id, nakama_host)
	result["nakama_host"] = nakama_host
	result["nakama_port"] = nakama_port
	result["nakama_scheme"] = nakama_scheme
	return result


func link_identity(provider: String, id_token: String) -> Dictionary:
	if guest_id.is_empty():
		ensure_guest_id()
	return NakamaSlot.link_identity(guest_id, provider, id_token, nakama_host)


func _uuid4() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var parts: PackedStringArray = PackedStringArray()
	for i in bytes.size():
		parts.append("%02x" % bytes[i])
	return "%s%s%s%s-%s%s-%s%s-%s%s-%s%s%s%s%s%s" % [
		parts[0], parts[1], parts[2], parts[3],
		parts[4], parts[5],
		parts[6], parts[7],
		parts[8], parts[9],
		parts[10], parts[11], parts[12], parts[13], parts[14], parts[15],
	]


func _is_uuid(value: String) -> bool:
	if value.length() != 36:
		return false
	for i in value.length():
		var character := value.substr(i, 1)
		if i == 8 or i == 13 or i == 18 or i == 23:
			if character != "-":
				return false
		elif not "0123456789abcdef".contains(character):
			return false
	return value.substr(14, 1) == "4"
