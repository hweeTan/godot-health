#include "healthkit_plugin.h"

#include "healthkit_apple.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void HealthKitPlugin::_bind_methods() {
	ClassDB::bind_method(D_METHOD("is_available"), &HealthKitPlugin::is_available);
	ClassDB::bind_method(D_METHOD("request_authorization"), &HealthKitPlugin::request_authorization);
	ClassDB::bind_method(D_METHOD("read_recent"), &HealthKitPlugin::read_recent);
	ClassDB::bind_method(D_METHOD("get_last_payload"), &HealthKitPlugin::get_last_payload);
	ClassDB::bind_method(D_METHOD("emit_permissions", "json"), &HealthKitPlugin::emit_permissions);
	ClassDB::bind_method(D_METHOD("emit_data", "json"), &HealthKitPlugin::emit_data);
	ClassDB::bind_method(D_METHOD("emit_error", "message"), &HealthKitPlugin::emit_error);

	ADD_SIGNAL(MethodInfo("permissions_updated", PropertyInfo(Variant::STRING, "json")));
	ADD_SIGNAL(MethodInfo("health_data_ready", PropertyInfo(Variant::STRING, "json")));
	ADD_SIGNAL(MethodInfo("health_error", PropertyInfo(Variant::STRING, "message")));
}

bool HealthKitPlugin::is_available() {
	return healthkit_is_available();
}

void HealthKitPlugin::request_authorization() {
	healthkit_request_authorization([this](bool ok, const std::string &error) {
		String message = String::utf8(error.c_str()).replace("\"", "'");
		String json = "{\"ok\":";
		json += ok ? "true" : "false";
		json += ",\"platform\":\"ios\",\"error\":\"";
		json += message;
		json += "\"}";
		call_deferred("emit_permissions", json);
		if (!ok && !error.empty()) {
			call_deferred("emit_error", message);
		}
	});
}

void HealthKitPlugin::read_recent() {
	healthkit_read_recent([this](const std::string &json) {
		call_deferred("emit_data", String::utf8(json.c_str()));
	});
}

String HealthKitPlugin::get_last_payload() const {
	return last_payload;
}

void HealthKitPlugin::emit_permissions(const String &json) {
	last_payload = json;
	emit_signal("permissions_updated", json);
}

void HealthKitPlugin::emit_data(const String &json) {
	last_payload = json;
	emit_signal("health_data_ready", json);
}

void HealthKitPlugin::emit_error(const String &message) {
	emit_signal("health_error", message);
}
