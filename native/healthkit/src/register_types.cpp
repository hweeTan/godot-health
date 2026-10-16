#include "healthkit_plugin.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>

#include <gdextension_interface.h>

using namespace godot;

static HealthKitPlugin *singleton = nullptr;

void initialize_healthkit_module(ModuleInitializationLevel level) {
	if (level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(HealthKitPlugin);
	singleton = memnew(HealthKitPlugin);
	Engine::get_singleton()->register_singleton("HealthKit", singleton);
}

void uninitialize_healthkit_module(ModuleInitializationLevel level) {
	if (level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	if (singleton != nullptr && Engine::get_singleton()->has_singleton("HealthKit")) {
		Engine::get_singleton()->unregister_singleton("HealthKit");
		memdelete(singleton);
		singleton = nullptr;
	}
}

extern "C" {
GDExtensionBool GDE_EXPORT healthkit_library_init(
		GDExtensionInterfaceGetProcAddress get_proc_address,
		GDExtensionClassLibraryPtr library,
		GDExtensionInitialization *initialization) {
	GDExtensionBinding::InitObject init_obj(get_proc_address, library, initialization);
	init_obj.register_initializer(initialize_healthkit_module);
	init_obj.register_terminator(uninitialize_healthkit_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
