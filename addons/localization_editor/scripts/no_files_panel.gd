@tool
extends Control

signal open_file_requested(path: String)
signal create_file_requested
signal open_file_popup_requested

@export var _recent_file_button_scene: PackedScene

var _config_manager: Node
var _recent_files: PackedStringArray = []


func initialize(config_manager: Node) -> void:
	_config_manager = config_manager
	_recent_files = _config_manager.get_settings_value("main", "recent_files", [])
	refresh_list()


func refresh_list() -> void:
	for n in get_node("%VBxRecentFiles").get_children():
		n.queue_free()
	for file in _recent_files:
		var btn := _recent_file_button_scene.instantiate()
		btn.filename = file
		btn.opened.connect(func(path: String): open_file_requested.emit(path))
		btn.removed.connect(_on_recent_file_removed)
		get_node("%VBxRecentFiles").add_child(btn)
	get_node("%LblNoRecentFiles").visible = _recent_files.is_empty()


func add_recent_file(path: String) -> void:
	if _recent_files.has(path):
		_recent_files.remove_at(_recent_files.find(path))
	_recent_files.insert(0, path)
	_recent_files = _recent_files.slice(0, 10)
	_config_manager.set_settings_value("main", "recent_files", _recent_files)


func get_most_recent_file() -> String:
	if _recent_files.is_empty():
		return ""
	return _recent_files[0]


func _on_recent_file_removed(file_path: String) -> void:
	_recent_files.remove_at(_recent_files.find(file_path))
	_config_manager.set_settings_value("main", "recent_files", _recent_files)


func _on_new_file_button_pressed() -> void:
	create_file_requested.emit()


func _on_open_file_button_pressed() -> void:
	open_file_popup_requested.emit()
