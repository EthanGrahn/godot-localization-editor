@tool
extends Popup

@export var _first_cell: LineEdit
@export var _delimiter: OptionButton
@export var _ref_lang: OptionButton
@export var _reopen_file: CheckBox
@export var _delete_confirmation: CheckBox

@onready var _config_manager: Node = get_node("/root/Main/ConfigManager")


func _save_and_close() -> void:
	_config_manager.set_settings_value("main", "first_cell", _first_cell.text)
	_config_manager.set_settings_value("main", "delimiter", _get_delimiter_value())
	var ref_lang: String = _ref_lang.get_item_text(_ref_lang.get_selected_id()).split(", ")[1]
	_config_manager.set_settings_value("main", "user_ref_lang", ref_lang)
	_config_manager.set_settings_value("main", "reopen_last_file", _reopen_file.button_pressed)
	_config_manager.set_settings_value("main", "no_confirm_delete", _delete_confirmation.button_pressed)
	self.hide()


func _get_delimiter_value():
	match _delimiter.get_selected_id():
		1:
			return ";"
		2:
			return "	"
		_: # option 0 and default
			return ","


func _on_about_to_popup():
	var ref_lang: String = _config_manager.get_settings_value("main", "user_ref_lang", "en")
	for i in range(0, _ref_lang.item_count):
		if _ref_lang.get_item_text(i).split(", ")[1] == ref_lang:
			_ref_lang.select(i)
			break
	_first_cell.text = _config_manager.get_settings_value("main", "first_cell", "keys")
	match _config_manager.get_settings_value("main", "delimiter", ","):
		";":
			_delimiter.select(1)
		"	":
			_delimiter.select(2)
		_:
			_delimiter.select(0)
	_reopen_file.button_pressed = _config_manager.get_settings_value("main", "reopen_last_file", true)
	_delete_confirmation.button_pressed = _config_manager.get_settings_value("main", "no_confirm_delete", false)
