extends Node

var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_test_guest_id_persists()
	_test_guest_id_is_not_hardware_id()
	_test_nakama_slot_stays_local()
	_test_reading_timer_accumulates_and_persists()
	_test_manual_entry_flags()
	_test_pixel_settings()
	if _failures.is_empty():
		print("TESTS PASSED")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("TESTS FAILED: %s" % _failures.size())
		get_tree().quit(1)


func _fail(message: String) -> void:
	_failures.append(message)
	print("FAIL ", message)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _test_guest_id_persists() -> void:
	var path := "user://tests/guest.cfg"
	_remove(path)
	var first := Node.new()
	first.set_script(load("res://services/auth_service.gd"))
	first.save_path = path
	var created: String = first.ensure_guest_id()
	_expect(first._is_uuid(created), "guest id is not a uuid v4")
	first.free()

	var second := Node.new()
	second.set_script(load("res://services/auth_service.gd"))
	second.save_path = path
	var loaded: String = second.ensure_guest_id()
	_expect(loaded == created, "guest id changed across loads")
	second.free()
	_remove(path)


func _test_guest_id_is_not_hardware_id() -> void:
	var source := FileAccess.get_file_as_string("res://services/auth_service.gd")
	_expect(not source.contains("get_unique_id"), "auth service must not use OS.get_unique_id")


func _test_nakama_slot_stays_local() -> void:
	var local := NakamaSlot.authenticate_device("11111111-1111-4111-8111-111111111111", "")
	_expect(bool(local["ok"]) and str(local["mode"]) == "local_guest", "empty host should stay a local guest")
	var unwired := NakamaSlot.authenticate_device("11111111-1111-4111-8111-111111111111", "nakama.example")
	_expect(not bool(unwired["ok"]), "a host without the SDK must not pretend to log in")
	var link := NakamaSlot.link_identity("11111111-1111-4111-8111-111111111111", "apple", "", "")
	_expect(str(link["provider"]) == "apple" and not bool(link["ok"]), "apple link is not wired yet")


func _test_reading_timer_accumulates_and_persists() -> void:
	var path := "user://tests/reading.cfg"
	_remove(path)
	var timer := Node.new()
	timer.set_script(load("res://services/reading_timer_service.gd"))
	timer.save_path = path
	timer.start()
	timer._started_unix = timer._now() - 125
	timer.stop()
	_expect(timer.today_seconds == 125, "elapsed seconds were not stored")
	_expect(timer.get_today_minutes() == 2, "minute total should floor 125 seconds to 2")
	timer.free()

	var again := Node.new()
	again.set_script(load("res://services/reading_timer_service.gd"))
	again.save_path = path
	again._load_today()
	_expect(again.today_seconds == 125, "daily seconds did not persist")
	again.start()
	again._started_unix = again._now() - 60
	again.stop()
	_expect(again.today_seconds == 185, "second session did not add")
	again.free()
	_remove(path)


func _test_manual_entry_flags() -> void:
	_expect(HealthPayload.is_manual("manual_entry"), "android manual_entry")
	_expect(HealthPayload.is_manual("RECORDING_METHOD_MANUAL_ENTRY"), "android constant name")
	_expect(HealthPayload.is_manual("user_entered"), "ios user_entered")
	_expect(HealthPayload.is_manual("device", true), "explicit user-entered flag")
	_expect(not HealthPayload.is_manual("automatically_recorded"), "device steps are not manual")
	_expect(not HealthPayload.is_manual("actively_recorded"), "active recording is not manual")
	var summary := HealthPayload.summarize(HealthPayload.stub())
	_expect(int(summary["steps_today_device"]) == 8032, "device steps")
	_expect(int(summary["manual_workouts"]) == 1, "one stub workout is manual")
	_expect(not bool(summary["device_verified"]), "stub data is not device verified")


func _test_pixel_settings() -> void:
	var file := FileAccess.open("res://art/characters/runner_placeholder.png", FileAccess.READ)
	_expect(file != null, "placeholder sprite missing")
	if file == null:
		return
	var header := file.get_buffer(24)
	file.close()
	# PNG IHDR stores width and height as big-endian. PackedByteArray.decode_u32 is little-endian.
	var width := (header[16] << 24) | (header[17] << 16) | (header[18] << 8) | header[19]
	var height := (header[20] << 24) | (header[21] << 16) | (header[22] << 8) | header[23]
	_expect(width == 64 and height == 64, "sprite is %sx%s, expected 64x64" % [width, height])

	var project := FileAccess.get_file_as_string("res://project.godot")
	_expect(project.contains("default_texture_filter=0"), "nearest filter is not the project default")
	_expect(project.contains("scale_mode=\"integer\""), "integer scaling is not set")
	_expect(project.contains("snap_2d_transforms_to_pixel=true"), "pixel snap is not set")
	_expect(project.contains("viewport_width=360"), "base width is not 360")
	_expect(project.contains("viewport_height=640"), "base height is not 640")


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
