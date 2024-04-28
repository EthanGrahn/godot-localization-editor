@tool
extends Node

signal data_changed
signal translation_requested(source_lang: String, source_text: String,
	target_lang: String, target_text: String, callback: Callable)

@export var _edit_translation_popup: Popup
@export var _ref_lang_label: Label
@export var _target_lang_line_edit: LineEdit
@export var _key_label: Label
@export var _needs_revision_cb: Button
@export var _empty_translation_color: Color
@export var _translate_button: Button
@export var _index_line_edit: LineEdit
@export var _dec_index_button: TextureButton
@export var _inc_index_button: TextureButton

@onready var _default_translation_color: Color = _target_lang_line_edit.modulate

var key: String = "Translation Key": set = _set_key
var ref_text: String = "Reference Translation": set = _set_ref_text
var target_text: String = "Translated Text"
var notes: String = ""
var ref_lang: String = "en"
var target_lang: String = "es"

var needs_revision : bool = false
var old_config: Dictionary = {}
var new_config: Dictionary = {}

# flag to avoid emitting signal as soon as the object is added to the tree
var _is_ready_for_emit_signals: bool
var _previous_key: String
var _is_dragging: bool = false

func _ready() -> void:
	get_parent().child_order_changed.connect(_on_order_changed)

func has_translation() -> bool:
	return !_target_lang_line_edit.text.is_empty()

func _emit_data_changed():
	if not _is_ready_for_emit_signals:
		return
	data_changed.emit()

func _set_ref_text(new_ref_text: String) -> void:
	ref_text = new_ref_text
	_ref_lang_label.text = ref_text
	if ref_text.is_empty() == true:
		ref_text = "[EMPTY]"
	
	# TODO: add logic for text that doesn't fit in box

func set_translation_data(key: String, ref_lang: String, ref_text: String,
	target_lang: String, target_text: String, notes: String,
	needs_revision: bool, start_focused := false, has_google := false) -> void:
	self.key = key
	self.ref_lang = ref_lang
	self.ref_text = ref_text
	self.target_lang = target_lang
	self.target_text = target_text
	_target_lang_line_edit.text = target_text
	self.notes = notes
	self.needs_revision = needs_revision
	if start_focused:
		_target_lang_line_edit.grab_focus()
		_target_lang_line_edit.caret_column = _target_lang_line_edit.text.length()
	name = key
	_previous_key = key
	_needs_revision_cb.button_pressed = needs_revision
	_translate_button.visible = has_google
	_on_needs_revision_toggled(_needs_revision_cb.button_pressed)
	old_config = {
		"key": key,
		"notes": notes,
		"needs_revision": needs_revision
	}

func set_init_complete() -> void:
	_is_ready_for_emit_signals = true

func get_translation_data() -> Dictionary:
	var output: Dictionary = {
		"ref_text": ref_text,
		"target_text": target_text,
		"key": key,
		"old_key": _previous_key
	}
	_previous_key = key
	return output

func get_config_data() -> Dictionary:
	new_config = {
		"key": key,
		"notes": notes,
		"needs_revision": needs_revision
	}
	var config_changed: bool = new_config != old_config
	var output_config := new_config.duplicate(true)
	output_config["updated"] = config_changed
	output_config["old_key"] = old_config["key"]
	old_config = new_config.duplicate(true)
	return output_config

func _translation_callback(new_target_text: String) -> void:
	if target_text != new_target_text:
		_emit_data_changed()
	target_text = new_target_text
	_target_lang_line_edit.text = target_text
	if _target_lang_line_edit.has_focus():
		_target_lang_line_edit.caret_column = _target_lang_line_edit.text.length()
	_on_translation_text_changed(new_target_text)

func _set_key(new_key: String) -> void:
	if key != new_key:
		_emit_data_changed()
	key = new_key
	_key_label.text = key

func _on_needs_revision_toggled(button_pressed: bool) -> void:
	needs_revision = button_pressed
	_emit_data_changed()

func _on_translation_text_changed(new_text: String) -> void:
	if new_text.is_empty():
		_target_lang_line_edit.modulate = _empty_translation_color
	else:
		_target_lang_line_edit.modulate = _default_translation_color

	if target_text != new_text:
		_emit_data_changed()
	target_text = new_text

func _on_translate_button_pressed() -> void:
	target_text = "Translating: [%s] please wait..." % [ref_text]
	_target_lang_line_edit.text = target_text
	translation_requested.emit(
		ref_lang,
		ref_text,
		target_lang,
		target_text,
		_translation_callback
	)

func _on_entry_updated(key, ref_text, target_text, notes) -> void:
	if (self.key != key or self.ref_text != ref_text
		or self.target_text != target_text or self.notes != notes):
		_emit_data_changed()
	self.key = key
	self.ref_text = ref_text
	self.target_text = target_text
	_target_lang_line_edit.text = target_text
	_target_lang_line_edit.caret_column = _target_lang_line_edit.text.length()
	self.notes = notes

func _on_edit_button_pressed() -> void:
	_edit_translation_popup.request_edit(
		key,
		ref_lang,
		target_lang,
		ref_text,
		target_text,
		notes
	)

func _on_change_index_pressed(is_up: bool) -> void:
	if is_up and get_index() == 0:
		return
	var amount: int = -1 if is_up else 1
	get_parent().move_child(self, get_index() + amount)


func _on_order_changed():
	var new_index: int = get_index()
	_index_line_edit.text = str(new_index)
	var value_set := false
	if new_index == 0:
		_dec_index_button.mouse_default_cursor_shape = Control.CURSOR_ARROW
		_dec_index_button.disabled = true
		value_set = true
	else:
		_dec_index_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_dec_index_button.disabled = false
		
	if get_parent() != null and new_index == get_parent().get_child_count() - 1:
		_inc_index_button.mouse_default_cursor_shape = Control.CURSOR_ARROW
		_inc_index_button.disabled = true
		value_set = true
	else:
		_inc_index_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_inc_index_button.disabled = false
	
	_emit_data_changed()


func _on_index_text_submitted(line_edit: LineEdit, new_text: String) -> void:
	# validate index
	var new_index := int(new_text)
	var max_index := get_parent().get_child_count() - 1
	if new_index > max_index:
		new_index = max_index
	
	line_edit.text = str(new_index)
	get_parent().move_child(self, new_index)
