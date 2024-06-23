@tool
extends Node

# Structure of translation entry data
# {
#   "key": "SOME_KEY",
#   "translations": {
#     "lang_1": "translation 1",
#     "lang_2": "translation 2",
#     ...
#     "lang_n": "translation n"
#   },
#   "index": 0,
#   "needs_revision": false,
#   "notes": "notes go here"
# }

signal data_changed(new_data: Dictionary)
signal translation_requested(source_lang: String, source_text: String,
	target_lang: String, callback: Callable)
signal removed(key: String)


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
@onready var _config_manager: Node = get_node("/root/Main/ConfigManager")

var key: String = "Translation Key":
	set(new_value):
		var old_value: String = _entry_data.get("key", new_value)
		_entry_data["key"] = new_value
		_key_label.text = key
		if old_value != new_value and _is_ready_for_emit_signals:
			_config_manager.replace_key(old_value, new_value)
	get:
		return _entry_data["key"]

var ref_text: String = "Reference Translation":
	set(new_value):
		ref_text = new_value
		_ref_lang_label.text = ref_text
		if ref_text.is_empty() == true:
			ref_text = "[EMPTY]"
		
		# TODO: add logic for text that doesn't fit in box

var target_text: String = "Translated Text":
	set(new_value):
		target_text = new_value
		_target_lang_line_edit.text = new_value

var notes: String = "":
	set(new_value):
		var old_value: String = _entry_data.get("notes", new_value)
		_entry_data["notes"] = new_value
		if old_value != new_value and _is_ready_for_emit_signals:
			_config_manager.set_key_value(key, "notes", new_value)
	get:
		return _entry_data["notes"]

var needs_revision : bool = false:
	set(new_value):
		var old_value: bool = _entry_data.get("needs_revision", new_value)
		_entry_data["needs_revision"] = new_value
		if old_value != new_value and _is_ready_for_emit_signals:
			_config_manager.set_key_value(key, "needs_revision", new_value)
	get:
		return _entry_data["needs_revision"]

var old_config: Dictionary = {}
var new_config: Dictionary = {}
var ref_lang: String = "en"
var target_lang: String = "es"

# flag to avoid emitting signal as soon as the object is added to the tree
var _is_ready_for_emit_signals: bool
var _previous_key: String
var _is_dragging: bool = false
var _entry_data: Dictionary = {}
var _grab_focus: bool = false

func _enter_tree() -> void:
	get_parent().child_order_changed.connect(_on_order_changed)

func _ready():
	if _grab_focus:
		_target_lang_line_edit.grab_focus()
		_target_lang_line_edit.caret_column = _target_lang_line_edit.text.length()
		_grab_focus = false

func has_translation() -> bool:
	return !_target_lang_line_edit.text.is_empty()

func _emit_data_changed():
	if not _is_ready_for_emit_signals:
		return
	data_changed.emit(_entry_data)

func get_entry_data() -> Dictionary:
	return _entry_data

func set_translation_data(key: String, ref_lang: String, target_lang: String,
	translations: Dictionary, notes: String,
	needs_revision: bool, start_focused := false, has_google := false) -> void:
	self.key = key
	self.ref_lang = ref_lang
	self.ref_text = translations[ref_lang]
	self.target_lang = target_lang
	self.target_text = translations[target_lang]
	self.notes = notes
	self.needs_revision = needs_revision
	_grab_focus = start_focused
	_entry_data["index"] = get_index()
	_entry_data["translations"] = translations
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

func update_reference_language(new_lang: String) -> void:
	ref_lang = new_lang
	ref_text = _entry_data["translations"][new_lang]

func update_target_language(new_lang: String) -> void:
	target_lang = new_lang
	target_text = _entry_data["translations"][new_lang]

func remove(quiet := false) -> void:
	_is_ready_for_emit_signals = false
	if not quiet:
		removed.emit(key)
	self.queue_free()

func filter(search_text: String, filters: Dictionary) -> void:
	var hide_translated: bool = filters["need_translation"]
	var hide_no_need_rev: bool = filters["need_revision"]
	var search_key: bool = filters.get("search_key", true)
	var search_ref_text: bool = filters.get("search_ref_text", true)
	var search_target_text: bool = filters.get("search_target_text", true)
	
	self.visible = true
	
	if (hide_translated and has_translation() or 
	hide_no_need_rev and not needs_revision):
		self.visible = false
		return
	
	if not search_text.is_empty():
		var key_match: bool = search_key and search_text in key.to_lower()
		var ref_match: bool = (search_ref_text and 
			search_text in ref_text.to_lower())
		var target_match: bool = (search_target_text and 
			search_text in target_text.to_lower())
		self.visible = key_match or ref_match or target_match

func _translation_callback(new_target_text: String) -> void:
	if target_text != new_target_text:
		_emit_data_changed()
	target_text = new_target_text
	if _target_lang_line_edit.has_focus():
		_target_lang_line_edit.caret_column = _target_lang_line_edit.text.length()
	_on_translation_text_changed(new_target_text)

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
		_translation_callback
	)

func _on_entry_updated(key, ref_text, target_text, notes) -> void:
	if self.ref_text != ref_text or self.target_text != target_text:
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
	_update_arrows()
	# check if index has changed
	if new_index == -1 or _entry_data["index"] == new_index:
		return
	_index_line_edit.text = str(new_index)
	_entry_data["index"] = new_index
	_emit_data_changed()

func _update_arrows() -> void:
	var new_index: int = get_index()
	if new_index == 0:
		_dec_index_button.mouse_default_cursor_shape = Control.CURSOR_ARROW
		_dec_index_button.disabled = true
	else:
		_dec_index_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_dec_index_button.disabled = false
		
	if get_parent() != null and new_index == get_parent().get_child_count() - 1:
		_inc_index_button.mouse_default_cursor_shape = Control.CURSOR_ARROW
		_inc_index_button.disabled = true
	else:
		_inc_index_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_inc_index_button.disabled = false

func _on_index_text_submitted(line_edit: LineEdit, new_text: String) -> void:
	# validate index
	var new_index := int(new_text)
	var max_index := get_parent().get_child_count() - 1
	if new_index > max_index:
		new_index = max_index
	
	line_edit.text = str(new_index)
	get_parent().move_child(self, new_index)


func _on_delete_confirmed(remember_choice: bool) -> void:
	_config_manager.set_settings_value("main", "no_confirm_delete", remember_choice)
	remove()


func _on_delete_button_pressed():
	if not _config_manager.get_settings_value("main", "no_confirm_delete", false):
		get_node("Popup").popup_centered()
	else:
		remove()
