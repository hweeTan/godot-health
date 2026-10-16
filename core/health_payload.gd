class_name HealthPayload
extends RefCounted

## Shared reading of the JSON both native plugins return.
## Manual entries are the ones a person typed in, not a device recording.

static func is_manual(recording_method: String, was_user_entered: bool = false) -> bool:
	if was_user_entered:
		return true
	return recording_method == "manual_entry" or recording_method == "user_entered" or recording_method == "RECORDING_METHOD_MANUAL_ENTRY"


static func summarize(payload: Dictionary) -> Dictionary:
	var steps_today := int(payload.get("steps_today", 0))
	var steps_manual := int(payload.get("steps_today_manual", 0))
	var workouts: Array = payload.get("workouts", [])
	var manual_workouts := 0
	for item in workouts:
		if item is Dictionary and bool((item as Dictionary).get("manual", false)):
			manual_workouts += 1
	return {
		"steps_today": steps_today,
		"steps_today_manual": steps_manual,
		"steps_today_device": maxi(steps_today - steps_manual, 0),
		"workout_count": workouts.size(),
		"manual_workouts": manual_workouts,
		"active_minutes_7d": int(payload.get("active_minutes_7d", 0)),
		"active_minutes_7d_manual": int(payload.get("active_minutes_7d_manual", 0)),
		"platform": str(payload.get("platform", "")),
		"device_verified": bool(payload.get("device_verified", false)),
	}


static func stub() -> Dictionary:
	return {
		"platform": "stub",
		"available": false,
		"sdk_status": "desktop_stub",
		"device_verified": false,
		"steps_today": 8432,
		"steps_today_manual": 400,
		"steps_today_device": 8032,
		"steps_samples": [
			{
				"count": 8032,
				"manual": false,
				"recording_method": "automatically_recorded",
				"source": "stub.device",
			},
			{
				"count": 400,
				"manual": true,
				"recording_method": "manual_entry",
				"source": "stub.manual",
			},
		],
		"active_minutes_7d": 96,
		"active_minutes_7d_manual": 20,
		"active_minutes_source": "desktop stub",
		"active_calories_7d": 540,
		"active_calories_7d_manual": 80,
		"workouts": [
			{
				"activity": "running",
				"duration_seconds": 1920,
				"manual": false,
				"recording_method": "automatically_recorded",
				"source": "stub.device",
			},
			{
				"activity": "yoga",
				"duration_seconds": 1200,
				"manual": true,
				"recording_method": "manual_entry",
				"source": "stub.manual",
			},
		],
		"error": "",
	}
