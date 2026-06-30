@tool
extends Popup

signal translation_added(key: String, ref_text: String, target_text: String, key_is_uppercase: bool)

@onready var _key_text: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/KeyText
@onready var _ref_text: LineEdit = $MarginContainer/VBoxContainer/ReferenceText
@onready var _target_text: LineEdit = $MarginContainer/VBoxContainer/TargetText
@onready var _uppercase_check_box: CheckBox = $MarginContainer/VBoxContainer/HBoxContainer/UppercaseCheckBox
@onready var _add_translation_button: Button = $MarginContainer/VBoxContainer/AddTranslationButton


func request_popup(ref_lang: String, target_lang: String, key_is_uppercase: bool):
	_uppercase_check_box.button_pressed = key_is_uppercase
	_key_text.clear()
	_ref_text.clear()
	_target_text.clear()
	_ref_text.placeholder_text = "[%s] text here..." % ref_lang
	_target_text.placeholder_text = "[%s] text here..." % target_lang
	_key_text.grab_focus()
	self.popup_centered()


func _on_key_text_changed(new_text: String) -> void:
	_add_translation_button.disabled = new_text.is_empty()
	if not _uppercase_check_box.button_pressed:
		return
	var caret_column := _key_text.caret_column
	_key_text.text = new_text.to_upper()
	_key_text.caret_column = caret_column


func _on_add_translation_button_pressed():
	translation_added.emit(
		_key_text.text, _ref_text.text, _target_text.text, _uppercase_check_box.button_pressed
	)
	self.hide()


func _on_uppercase_check_box_toggled(button_pressed: bool) -> void:
	if button_pressed:
		var caret_column := _key_text.caret_column
		_key_text.text = _key_text.text.to_upper()
		_key_text.caret_column = caret_column
