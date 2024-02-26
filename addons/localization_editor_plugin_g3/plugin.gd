@tool
extends EditorPlugin

const icon: Texture2D = preload("res://addons/localization_editor_plugin_g3/gle-plugin-icon.svg")

const Dock = preload("res://addons/localization_editor_plugin_g3/Dock.tscn")
var dock_instance

func _enter_tree() -> void:
	dock_instance = Dock.instantiate()
	dock_instance.connect("scan_files_requested", Callable(self, "_on_scan_files_requested"))
	# Add the main panel to the editor's main viewport.
	get_editor_interface().get_editor_main_screen().add_child(dock_instance)
	# Hide the main panel. Very much required.
	_make_visible(false)

func _exit_tree():
	if dock_instance:
		dock_instance.queue_free()

func _has_main_screen():
	return true

func _make_visible(visible):
	if dock_instance:
		dock_instance.visible = visible

func _get_plugin_name():
	return "Translations"

func _get_plugin_icon():
	return icon

func _on_scan_files_requested() -> void:
	if Engine.is_editor_hint() == true:
		get_editor_interface().get_resource_filesystem().scan()
