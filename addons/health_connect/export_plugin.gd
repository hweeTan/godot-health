@tool
extends EditorPlugin

var _export_plugin: AndroidExportPlugin


func _enter_tree() -> void:
	_export_plugin = AndroidExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:
	const _plugin_name := "HealthConnect"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if debug:
			return PackedStringArray(["health_connect/bin/debug/HealthConnect-debug.aar"])
		return PackedStringArray(["health_connect/bin/release/HealthConnect-release.aar"])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([
			"androidx.health.connect:connect-client:1.1.0",
			"androidx.activity:activity-ktx:1.10.1",
			"org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2",
		])

	func _get_name() -> String:
		return _plugin_name
