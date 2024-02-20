extends Popup

signal preferences_updated(preferences: Array[Dictionary])

@export var _first_cell: LineEdit
@export var _delimiter: LineEdit
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
	
	# TODO: make these values file dependent or remove
	preferences.append(_make_preference("f_cell", _first_cell.text))
	preferences.append(_make_preference("delimiter", _delimiter.text))
	# end TODO
	preferences.append(_make_preference("user_ref_lang", _ref_lang.get_item_text(_ref_lang.get_selected_id())))
	preferences.append(_make_preference("reopen_last_file", _reopen_file.button_pressed))
	
	preferences_updated.emit(preferences)
	self.hide()
