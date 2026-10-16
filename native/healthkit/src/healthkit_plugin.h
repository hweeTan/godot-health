#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace godot {

class HealthKitPlugin : public Object {
	GDCLASS(HealthKitPlugin, Object)

	String last_payload;

protected:
	static void _bind_methods();

public:
	bool is_available();
	void request_authorization();
	void read_recent();
	String get_last_payload() const;
	void emit_permissions(const String &json);
	void emit_data(const String &json);
	void emit_error(const String &message);
};

} // namespace godot
