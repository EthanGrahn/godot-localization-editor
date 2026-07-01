@tool
extends Popup

signal lang_add_requested(lang_code: String)

@export var _locale_list: Script
@onready var _option_button: OptionButton = $MarginContainer/VBoxContainer/AddLangOptionButton


func request_popup(existing_langs: Array) -> void:
	var locales = _locale_list.new()
	_option_button.clear()
	var i: int = 0
	for l in locales.LOCALES:
		if l["code"] not in existing_langs and l["name"] not in existing_langs:
			_option_button.add_item("%s, %s" % [l["name"], l["code"]], i)
			i += 1
	popup_centered()


func _on_add_button_pressed() -> void:
	var lang_code: String = (
		_option_button.get_item_text(_option_button.selected).split(",")[1].strip_edges()
	)
	lang_add_requested.emit(lang_code)
	hide()
