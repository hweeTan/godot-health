extends Node

## Foreground reading timer. Minutes are stored per local day.
## Leaving the app stops the timer so background time is not counted.

signal changed

const DEFAULT_PATH := "user://reading/daily.cfg"

var save_path: String = DEFAULT_PATH
var running: bool = false
var today_seconds: int = 0
var _started_unix: int = 0
var _stopped_by_background: bool = false


func _ready() -> void:
	_load_today()


func _notification(what: int) -> void:
	var left_foreground := what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT
	if left_foreground and running:
		_stopped_by_background = true
		stop()


func start() -> void:
	_load_today()
	if running:
		return
	_stopped_by_background = false
	running = true
	_started_unix = _now()
	changed.emit()


func stop() -> void:
	if not running:
		return
	var elapsed := maxi(_now() - _started_unix, 0)
	running = false
	_started_unix = 0
	today_seconds += elapsed
	_save_today()
	changed.emit()


func get_today_seconds() -> int:
	var total := today_seconds
	if running:
		total += maxi(_now() - _started_unix, 0)
	return total


func get_today_minutes() -> int:
	return int(get_today_seconds() / 60.0)


func was_stopped_by_background() -> bool:
	return _stopped_by_background


func today_key() -> String:
	var date := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(date.year), int(date.month), int(date.day)]


func _now() -> int:
	return int(Time.get_unix_time_from_system())


func _load_today() -> void:
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	var config := ConfigFile.new()
	if config.load(save_path) == OK:
		today_seconds = int(config.get_value("days", today_key(), 0))
	else:
		today_seconds = 0


func _save_today() -> void:
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	var config := ConfigFile.new()
	config.load(save_path)
	config.set_value("days", today_key(), today_seconds)
	config.save(save_path)
