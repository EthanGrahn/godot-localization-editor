@tool
extends Node

signal initialized

# where user preferences are stored
const _settings_file : String = "user://settings.ini"
# where file specific data is stored
const _data_file_name: String = ".gle-data"

var is_initialized := false

var _user_config := ConfigFile.new()
var _directory_config := ConfigFile.new()

var _current_file : String
var _directory_config_path: String:
	get:
		return "%s/%s" % [_current_file.get_base_dir(), _data_file_name]

# Called when the node enters the scene tree for the first time.
func _ready():
	if FileAccess.file_exists(_settings_file):
		_user_config.load(_settings_file)
	is_initialized = true
	initialized.emit()

func _save_settings_config(_is_init_step := false) -> void:
	if not is_initialized and not _is_init_step:
		return
	_user_config.save(_settings_file)

func _save_directory_config() -> void:
	_directory_config.save(_directory_config_path)

func set_new_file(new_file: String) -> void:
	_current_file = new_file
	if FileAccess.file_exists(_directory_config_path):
		_directory_config.load(_directory_config_path)
	else:
		_directory_config = ConfigFile.new()
		_save_directory_config()

func get_key_value(translation_key: String, config_key: String, default: Variant = null) -> Variant:
	var section_key := "%s/%s" % [_current_file.get_file(), translation_key]
	return _directory_config.get_value(section_key, config_key, default)

func set_key_value(translation_key: String, config_key: String, value: Variant) -> void:
	var section_key := "%s/%s" % [_current_file.get_file(), translation_key]
	_directory_config.set_value(section_key, config_key, value)
	_save_directory_config()

func replace_key(old_key: String, new_key: String) -> void:
	var old_section_key := "%s/%s" % [_current_file.get_file(), old_key]
	var new_section_key := "%s/%s" % [_current_file.get_file(), new_key]
	for key in _directory_config.get_section_keys(old_section_key):
		var old_value = _directory_config.get_value(old_section_key, key)
		_directory_config.set_value(new_section_key, key, old_value)
	_directory_config.erase_section(old_section_key)
	_save_directory_config()

func get_file_value(key: String, default: Variant = null) -> Variant:
	return _directory_config.get_value(_current_file.get_file(), key, default)

func set_file_value(key: String, value: Variant) -> void:
	_directory_config.set_value(_current_file.get_file(), key, value)
	_save_directory_config()

func get_directory_value(section: String, key: String, default: Variant = null) -> Variant:
	return _directory_config.get_value(section, key, default)

func set_directory_value(section: String, key: String, value: Variant) -> void:
	_directory_config.set_value(section, key, value)
	_save_directory_config()

func get_settings_value(section: String, key: String, default: Variant = null) -> Variant:
	return _user_config.get_value(section, key, default)

func set_settings_value(section: String, key: String, value: Variant) -> void:
	_user_config.set_value(section, key, value)
	_save_settings_config()
