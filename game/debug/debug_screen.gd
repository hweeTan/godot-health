extends Control

const SPRITE_PATH := "res://art/characters/runner_placeholder.png"
const SPRITE_SCALE := 3

var _log: RichTextLabel
var _health_label: Label
var _guest_label: Label
var _reading_label: Label
var _ads_label: Label


func _ready() -> void:
	_build()
	Health.health_updated.connect(_on_health)
	Health.status_changed.connect(_append)
	Ads.log_line.connect(_append)
	Ads.reward_earned.connect(_on_reward)
	Reading.changed.connect(_refresh_reading)
	_refresh_guest()
	_refresh_reading()
	Health.refresh()
	_append("Spike screen ready. Platform: %s" % OS.get_name())


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("0d1020")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 12
	scroll.offset_top = 12
	scroll.offset_right = -12
	scroll.offset_bottom = -12
	add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)

	column.add_child(_heading("SWEATPUNK  SPIKE"))
	column.add_child(_body("Portrait 360×640, integer scale, nearest filter."))

	var sprite := TextureRect.new()
	sprite.texture = load(SPRITE_PATH)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	sprite.custom_minimum_size = Vector2(64 * SPRITE_SCALE, 64 * SPRITE_SCALE)
	sprite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(sprite)
	column.add_child(_body("Placeholder runner, 64×64 drawn at 3× (192 px)."))

	column.add_child(_heading("HEALTH"))
	_health_label = _body("Waiting for a read.")
	column.add_child(_health_label)
	column.add_child(_button("Request health permission", _on_request_health))
	column.add_child(_button("Refresh steps and workouts", _on_refresh_health))

	column.add_child(_heading("REWARDED TEST AD"))
	_ads_label = _body("Google sample ad units only. UMP uses EEA debug geography.")
	column.add_child(_ads_label)
	column.add_child(_button("Request UMP consent", func() -> void: Ads.request_consent()))
	column.add_child(_button("Initialize AdMob", func() -> void: Ads.initialize_ads()))
	column.add_child(_button("Load rewarded test ad", func() -> void: Ads.load_rewarded()))
	column.add_child(_button("Show rewarded test ad", func() -> void: Ads.show_rewarded()))

	column.add_child(_heading("GUEST IDENTITY"))
	_guest_label = _body("")
	column.add_child(_guest_label)
	column.add_child(_button("Prepare Nakama device login", _on_nakama))

	column.add_child(_heading("READING TIMER"))
	_reading_label = _body("")
	column.add_child(_reading_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_button("Start", func() -> void: Reading.start()))
	row.add_child(_button("Stop", func() -> void: Reading.stop()))
	column.add_child(row)

	column.add_child(_heading("LOG"))
	_log = RichTextLabel.new()
	_log.custom_minimum_size = Vector2(0, 180)
	_log.bbcode_enabled = false
	_log.scroll_following = true
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.add_theme_color_override("default_color", Color("c8f6ea"))
	column.add_child(_log)


func _on_request_health() -> void:
	Health.request_permissions()


func _on_refresh_health() -> void:
	Health.refresh()


func _on_health(payload: Dictionary) -> void:
	var summary := HealthPayload.summarize(payload)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Source: %s" % summary["platform"])
	if not bool(summary["device_verified"]):
		lines.append("Not a verified device read.")
	lines.append("Steps today: %s (device %s, manual %s)" % [summary["steps_today"], summary["steps_today_device"], summary["steps_today_manual"]])
	lines.append("Active minutes, 7 days: %s (manual %s)" % [summary["active_minutes_7d"], summary["active_minutes_7d_manual"]])
	lines.append("Workouts: %s, flagged manual: %s" % [summary["workout_count"], summary["manual_workouts"]])
	var note := str(payload.get("active_minutes_source", ""))
	if not note.is_empty():
		lines.append(note)
	var error := str(payload.get("error", ""))
	if not error.is_empty():
		lines.append(error)
	_health_label.text = "\n".join(lines)


func _on_reward(reward_type: String, amount: int) -> void:
	_ads_label.text = "Last reward callback: %s x %s" % [amount, reward_type]


func _refresh_guest() -> void:
	_guest_label.text = "Guest id\n%s\nStored in user://. Nakama is not connected." % Auth.guest_id


func _on_nakama() -> void:
	var result := Auth.authenticate_device()
	_append(JSON.stringify(result))
	_guest_label.text = "Guest id\n%s\n%s" % [Auth.guest_id, result.get("nakama", "")]


func _refresh_reading() -> void:
	var state := "running" if Reading.running else "stopped"
	var extra := ""
	if Reading.was_stopped_by_background():
		extra = "\nStopped because the app left the foreground."
	_reading_label.text = "Today: %s min (%s s), %s.%s" % [Reading.get_today_minutes(), Reading.get_today_seconds(), state, extra]


func _append(message: String) -> void:
	if _log == null:
		return
	_log.append_text(message + "\n")


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("ff2bd6"))
	label.add_theme_font_size_override("font_size", 18)
	return label


func _body(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("e8fff4"))
	label.add_theme_font_size_override("font_size", 14)
	return label


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button
