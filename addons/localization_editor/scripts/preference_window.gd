@tool
extends Popup

signal preferences_updated(preferences: Array[Dictionary])

@export var _first_cell: LineEdit
@export var _delimiter: OptionButton
@export var _ref_lang: OptionButton
@export var _reopen_file: CheckBox

func _make_preference(key: String, value) -> Dictionary:
	return {
		"section": "main",
		"key": key,
		"value": value
	}

func _save_and_close() -> void:
	var preferences: Array[Dictionary] = []
	
	preferences.append(_make_preference("first_cell", _first_cell.text))
	preferences.append(_make_preference("delimiter", _get_delimiter_value()))
	var ref_lang: String = _ref_lang.get_item_text(_ref_lang.get_selected_id()).split(", ")[1]
	preferences.append(_make_preference("user_ref_lang", ref_lang))
	preferences.append(_make_preference("reopen_last_file", _reopen_file.button_pressed))
	
	preferences_updated.emit(preferences)
	self.hide()


func _get_delimiter_value():
	match _delimiter.get_selected_id():
		1:
			return ";"
		2:
			return "	"
		_: # option 0 and default
			return ","


func set_defaults(config: ConfigFile) -> void:
	var ref_lang: String = config.get_value("main", "user_ref_lang", "en")
	for i in range(0, _ref_lang.item_count):
		if _ref_lang.get_item_text(i).split(", ")[1] == ref_lang:
			_ref_lang.select(i)
			break
	_first_cell.text = config.get_value("main", "first_cell", "keys")
	match config.get_value("main", "delimiter", ","):
		";":
			_delimiter.select(1)
		"	":
			_delimiter.select(2)
		_:
			_delimiter.select(0)
	_reopen_file.button_pressed = config.get_value("main", "reopen_last_file", true)
