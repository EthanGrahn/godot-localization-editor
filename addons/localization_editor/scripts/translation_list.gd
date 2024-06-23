@tool
extends Node

signal translation_requested(source_lang: String, source_text: String,
	target_lang: String, target_text: String, callback: Callable)
signal entry_updated(new_data: Dictionary)
signal entry_added(new_data: Dictionary)
signal entry_deleted(key: String)

@export var _translation_entry_scene: PackedScene
@export var _reference_lang_option: OptionButton
@export var _translated_lang_option: OptionButton

@onready var _config_manager: Node = get_node("/root/Main/ConfigManager")

const _google_translate_path: String = "res://addons/localization_editor/google_translate/google_translate.tscn"
var _google_translate: Node

func _ready():
	if ResourceLoader.exists(_google_translate_path) and _google_translate == null:
		_google_translate = load(_google_translate_path).instantiate()
		get_node("/root/Main/Dock").add_child.call_deferred(_google_translate)

func init_list(translation_data: Dictionary) -> void:
	# reset list
	for child in get_children():
		child.remove(true)
	
	# wait a frame for entries to be removed
	await get_tree().process_frame
	
	for key in translation_data:
		_add_entry_internal(key, translation_data[key])
	
	# wait a frame for entries to be loaded
	await get_tree().process_frame
	for child in get_children():
		child.set_init_complete()

func update_reference_language(new_lang: String) -> void:
	for child in get_children():
		child.update_reference_language(new_lang)

func update_target_language(new_lang: String) -> void:
	for child in get_children():
		child.update_target_language(new_lang)

func add_entry(key: String, ref_text: String, target_text: String) -> void:
	var selected_reference := _reference_lang_option.get_item_text(_reference_lang_option.selected)
	var selected_translated := _translated_lang_option.get_item_text(_translated_lang_option.selected)
	var translations : Dictionary = {
		selected_reference: ref_text,
		selected_translated: target_text
	}
	var new_entry = _add_entry_internal(key, translations, true)
	await get_tree().process_frame
	entry_added.emit(new_entry.get_entry_data())
	new_entry.set_init_complete()

func search(search_text: String, filters: Dictionary) -> void:
	for child in get_children():
		child.filter(search_text, filters)

func _add_entry_internal(key: String, entry_data: Dictionary,
		focus: bool = false) -> Node:
	var selected_reference := _reference_lang_option.get_item_text(_reference_lang_option.selected)
	var selected_translated := _translated_lang_option.get_item_text(_translated_lang_option.selected)
	var translation_entry = _translation_entry_scene.instantiate()
	if _google_translate != null:
		translation_entry.translation_requested.connect(_on_translate_requested)
	translation_entry.data_changed.connect(_on_entry_updated)
	translation_entry.removed.connect(_on_entry_deleted)
	translation_entry.set_translation_data(
		key,
		selected_reference,
		selected_translated,
		entry_data,
		_config_manager.get_key_value(key, "notes", ""),
		_config_manager.get_key_value(key, "needs_revision", false),
		focus,
		_google_translate != null
	)
	add_child.call_deferred(translation_entry)
	return translation_entry

func _on_translate_requested(source_lang: String, source_text: String,
	target_lang: String, callback: Callable) -> void:
	_google_translate.translate(
		source_lang,
		target_lang,
		source_text,
		callback
	)

func _on_entry_updated(new_data: Dictionary) -> void:
	entry_updated.emit(new_data)

func _on_entry_deleted(key: String) -> void:
	entry_deleted.emit(key)
