class_name NakamaSlot
extends RefCounted

## Slot for heroiclabs/nakama-godot. The spike does not vendor the SDK or run a server.
## When a host is configured, these methods are the call sites for:
##   client.authenticate_device_async(guest_id)
##   client.link_apple_async(session, id_token)
##   client.link_google_async(session, id_token)
## The guest id is a random UUID stored on device. Do not replace it with OS.get_unique_id().

static func authenticate_device(guest_id: String, host: String) -> Dictionary:
	if host.is_empty():
		return {
			"ok": true,
			"mode": "local_guest",
			"guest_id": guest_id,
			"nakama": "not_configured",
		}
	return {
		"ok": false,
		"mode": "nakama_unwired",
		"guest_id": guest_id,
		"nakama": "host_set_sdk_missing",
		"error": "Nakama host is set, but the nakama-godot SDK is not vendored in this spike.",
	}


static func link_identity(guest_id: String, provider: String, id_token: String, host: String) -> Dictionary:
	var token_present := not id_token.is_empty()
	return {
		"ok": false,
		"mode": "nakama_unwired",
		"guest_id": guest_id,
		"provider": provider,
		"id_token_present": token_present,
		"nakama": "not_configured" if host.is_empty() else "host_set_sdk_missing",
		"error": "Linking waits for the Nakama SDK. Apple uses link_apple_async, Google uses link_google_async, on the current device session.",
	}
