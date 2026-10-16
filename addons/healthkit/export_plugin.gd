@tool
extends EditorPlugin

var _export_plugin: IosExportPlugin


func _enter_tree() -> void:
	_export_plugin = IosExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class IosExportPlugin extends EditorExportPlugin:
	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformIOS

	func _get_name() -> String:
		return "HealthKit"

	func _export_begin(features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		if not features.has("ios"):
			return
		# SDK framework name, not a project file. Godot links it into the Xcode project.
		add_apple_embedded_platform_framework("HealthKit.framework")
		add_apple_embedded_platform_linker_flags("-framework HealthKit")
