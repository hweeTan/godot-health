extends Node

signal health_updated(payload: Dictionary)
signal status_changed(message: String)

var last_payload: Dictionary = {}
var _connected: bool = false


func platform_name() -> String:
	if OS.get_name() == "Android" and Engine.has_singleton("HealthConnect"):
		return "android"
	if OS.get_name() == "iOS" and Engine.has_singleton("HealthKit"):
		return "ios"
	return "stub"


func request_permissions() -> void:
	_connect_plugin()
	if platform_name() == "android":
		Engine.get_singleton("HealthConnect").call("requestPermissions")
		status_changed.emit("Opening the Health Connect permission screen.")
	elif platform_name() == "ios":
		Engine.get_singleton("HealthKit").call("request_authorization")
		status_changed.emit("Asking HealthKit for read access.")
	else:
		status_changed.emit("No health plugin on this desktop run. Showing stub data.")
		_publish(HealthPayload.stub())


func refresh() -> void:
	_connect_plugin()
	if platform_name() == "android":
		Engine.get_singleton("HealthConnect").call("readRecent")
		status_changed.emit("Reading Health Connect…")
	elif platform_name() == "ios":
		Engine.get_singleton("HealthKit").call("read_recent")
		status_changed.emit("Reading HealthKit…")
	else:
		status_changed.emit("Desktop stub. This is not a device read.")
		_publish(HealthPayload.stub())


func _connect_plugin() -> void:
	if _connected:
		return
	var plugin: Object = null
	if platform_name() == "android":
		plugin = Engine.get_singleton("HealthConnect")
	elif platform_name() == "ios":
		plugin = Engine.get_singleton("HealthKit")
	if plugin == null:
		return
	if not plugin.is_connected("permissions_updated", _on_permissions):
		plugin.connect("permissions_updated", _on_permissions)
	if not plugin.is_connected("health_data_ready", _on_data):
		plugin.connect("health_data_ready", _on_data)
	if not plugin.is_connected("health_error", _on_error):
		plugin.connect("health_error", _on_error)
	_connected = true


func _on_permissions(json_text: String) -> void:
	var parsed := _parse(json_text)
	status_changed.emit("Permission result: %s" % JSON.stringify(parsed))


func _on_data(json_text: String) -> void:
	_publish(_parse(json_text))


func _on_error(message: String) -> void:
	status_changed.emit(message)


func _publish(payload: Dictionary) -> void:
	last_payload = payload
	health_updated.emit(payload)
	if str(payload.get("error", "")).is_empty():
		status_changed.emit("Health data updated.")
	else:
		status_changed.emit(str(payload.get("error", "")))


func _parse(json_text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(json_text)
	if parsed is Dictionary:
		return parsed
	return {"platform": platform_name(), "error": "Plugin returned invalid JSON", "device_verified": false}
