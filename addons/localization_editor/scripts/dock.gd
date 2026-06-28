@tool
extends Control

signal scan_files_requested

# where user preferences are stored
const _SETTINGS_FILE: String = "user://settings.ini"

@export var _recent_file_button_scene: PackedScene
@export var _preferences_window: Popup
@export var _open_file_popup: Popup
@export var _create_file_popup: Popup
@export var _credits_popup: Popup
@export var _version_label: Label
@export var _new_lang_popup: Popup
@export var _add_lang_option: OptionButton
@export var _create_file_lang_option: OptionButton
@export var _prefs_lang_option: OptionButton
@export var _ref_lang_option: OptionButton
@export var _target_lang_option: OptionButton
@export var _remove_lang_popup: Popup
@export var _add_translation_popup: Popup
@export var _alert_window: AcceptDialog
@export var _locale_list: Script
@export var _search_filter_popup: PopupMenu
@export var _csv_loader: Node
@export var _config_manager: Node
@export var _cb_search_key: CheckBox
@export var _cb_search_ref_text: CheckBox
@export var _cb_search_target_text: CheckBox

var _is_config_initialized := false
var _save_pressed := false
var _save_warning_dialog: ConfirmationDialog
var _autosave_timer: Timer
var _recovery_dialog: ConfirmationDialog
var _pending_recovery_temp: String = ""
var _pending_open_path: String = ""
var _pending_open_delimiter: String = ""

var _current_data: Dictionary
var _translations: Dictionary:
	set(new_value):
		_current_data["translations"] = new_value
	get:
		if _current_data.is_empty():
			return {}
		return _current_data["translations"]
var _key_index: Array:
	set(new_value):
		_current_data["key_index"] = new_value
	get:
		if _current_data.is_empty():
			return []
		return _current_data["key_index"]
var _langs: Array:
	set(new_value):
		_current_data["languages"] = new_value
	get:
		if _current_data.is_empty():
			return []
		return _current_data["languages"]

var _current_full_file: String
var _current_file: String
var _current_path: String
var _current_path_config := ConfigFile.new()
var _recent_files: PackedStringArray = []
var _opened_files: PackedStringArray = []
var _google_translate: Node
var _search_filters := {"need_translation": false, "need_revision": false}


func _ready() -> void:
	if Engine.is_editor_hint() and not EditorInterface.is_plugin_enabled("localization_editor"):
		set_process(false)
		return

	var plugin_conf := ConfigFile.new()
	plugin_conf.load("res://addons/localization_editor/plugin.cfg")
	_version_label.text = "v%s" % plugin_conf.get_value("plugin", "version", "")

	var locales = _locale_list.new()
	for list: OptionButton in [_add_lang_option, _create_file_lang_option, _prefs_lang_option]:
		list.clear()
		var i: int = 0
		for l in locales.LOCALES:
			list.add_item("%s, %s" % [l["name"], l["code"]], i)
			i += 1

	_save_warning_dialog = ConfirmationDialog.new()
	_save_warning_dialog.title = "Save with Issues?"
	_save_warning_dialog.confirmed.connect(_do_save)
	add_child(_save_warning_dialog)

	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = 2.0
	_autosave_timer.one_shot = true
	_autosave_timer.timeout.connect(_write_temp_file)
	add_child(_autosave_timer)

	_recovery_dialog = ConfirmationDialog.new()
	_recovery_dialog.title = "Recover Unsaved Changes"
	_recovery_dialog.confirmed.connect(_apply_recovery)
	_recovery_dialog.canceled.connect(_discard_recovery)
	add_child(_recovery_dialog)
	_recovery_dialog.get_ok_button().text = "Recover"
	_recovery_dialog.get_cancel_button().text = "Discard"

	get_node("%MenuFile").get_popup().id_pressed.connect(_on_file_menu_id_pressed)
	get_node("%MenuEdit").get_popup().id_pressed.connect(_on_edit_menu_id_pressed)
	get_node("%MenuHelp").get_popup().id_pressed.connect(_on_help_menu_id_pressed)

	_close_all()


	if not is_instance_valid(_config_manager):
		_config_manager = get_tree().root.find_child("ConfigManager", true, false)

	if not is_instance_valid(_config_manager):
		return

	if not _config_manager.is_initialized:
		await _config_manager.initialized

	_is_config_initialized = true

	if Engine.is_editor_hint() == false:
		get_window().mode = (
			Window.MODE_MAXIMIZED
			if (_config_manager.get_settings_value("main", "maximized", false))
			else Window.MODE_WINDOWED
		)

	_recent_files = _config_manager.get_settings_value("main", "recent_files", [])
	_load_recent_files_list()

	# reopen the last file
	if _config_manager.get_settings_value("main", "reopen_last_file", false):
		if _recent_files.is_empty() == false:
			if FileAccess.file_exists(_recent_files[0]):
				_open_file(_recent_files[0])


func _process(_delta):
	if not _save_pressed and Input.is_key_pressed(KEY_CTRL) and Input.is_key_pressed(KEY_S):
		_save_file()
		_save_pressed = true
	elif _save_pressed and not Input.is_key_pressed(KEY_S):
		_save_pressed = false


func _load_recent_files_list() -> void:
	for n in get_node("%VBxRecentFiles").get_children():
		n.queue_free()

	for file in _recent_files:
		var file_button := _recent_file_button_scene.instantiate()
		file_button.filename = file
		file_button.opened.connect(_open_file)
		file_button.removed.connect(_on_recent_file_removed)
		get_node("%VBxRecentFiles").add_child(file_button)

	# show message if list is empty
	get_node("%LblNoRecentFiles").visible = _recent_files.is_empty()


func _on_recent_file_removed(file_path: String) -> void:
	_recent_files.remove_at(_recent_files.find(file_path))
	_config_manager.set_settings_value("main", "recent_files", _recent_files)


func _start_search() -> void:
	var search_text: String = get_node("%LineEditSearchBox").text.strip_edges().to_lower()
	var hide_translated: bool = _search_filters["need_translation"]
	var hide_no_need_rev: bool = _search_filters["need_revision"]
	_search_filters["search_key"] = _cb_search_key.button_pressed
	_search_filters["search_ref_text"] = _cb_search_ref_text.button_pressed
	_search_filters["search_target_text"] = _cb_search_target_text.button_pressed
	get_node("%VBxTranslations").search(search_text, _search_filters)


func _clear_search() -> void:
	get_node("%LineEditSearchBox").text = ""
	_cb_search_key.button_pressed = true
	_cb_search_ref_text.button_pressed = true
	_cb_search_target_text.button_pressed = true
	_search_filters["need_translation"] = false
	_search_filters["need_revision"] = false
	for i in range(0, _search_filter_popup.item_count):
		_search_filter_popup.set_item_checked(i, false)


func alert(txt: String, title: String = "Alert!") -> void:
	_alert_window.title = title
	_alert_window.get_node("Label").text = txt
	_alert_window.size = Vector2.ZERO
	_alert_window.popup_centered()


func _get_opened_file() -> String:
	return _current_path + "/" + _current_file


# get the selected language (ref or trans)
func get_selected_lang(mode: String = "ref") -> String:
	var node: OptionButton = _ref_lang_option
	if mode != "ref":
		node = _target_lang_option
	return node.get_item_text(node.selected)


func _set_visible_content(vis: bool = true) -> void:
	get_node("%HBxFileAndLangSelect").visible = vis
	get_node("%HBxContentFile").visible = vis
	get_node("%ControlNoOpenedFiles").visible = !vis


func _on_file_menu_id_pressed(id: int) -> void:
	match id:
		1:
			create_file_popup()
		2:
			open_file_popup()
		3:
			_save_file()
		4:
			_close_all()


func open_file_popup():
	_open_file_popup.popup_centered()


func create_file_popup():
	_create_file_popup.request_popup(
		_config_manager.get_settings_value("main", "first_cell", "keys"),
		_config_manager.get_settings_value("main", "delimiter", ",")
	)


func _on_edit_menu_id_pressed(id: int) -> void:
	match id:
		1:
			# add new language
			if get_node("%ControlNoOpenedFiles").visible == false:
				_new_lang_popup.popup_centered()
		2:
			# delete language
			if get_node("%ControlNoOpenedFiles").visible == false and _langs.size() > 0:
				_remove_lang_popup.request_popup(_langs)
		3:
			# open program settings
			_preferences_window.popup_centered()


func _on_help_menu_id_pressed(id: int) -> void:
	match id:
		1:
			OS.shell_open(
				(
					"https://github.com/EthanGrahn/godot-localization-editor"
					+ "?tab=readme-ov-file#usage-guide"
				)
			)
		2:
			_credits_popup.popup_centered()


func _close_all() -> void:
	if is_instance_valid(_autosave_timer):
		_autosave_timer.stop()
	_opened_files = []
	_load_recent_files_list()
	_clear_search()
	_set_visible_content(false)
	_on_Popup_hide()
	_current_file = ""
	_current_path = ""
	get_node("%OpenedFilesList").clear()
	get_node("%ControlNoOpenedFiles").visible = true
	get_node("%VBxTranslations").clear_list()
	_current_data = {}


# Show or hide a popup
func _on_Popup_about_to_show() -> void:
	get_node("%PopupBG").visible = true


func _on_Popup_hide() -> void:
	get_node("%PopupBG").visible = false


# a file was selected from the list
func _on_opened_file_item_selected(index: int) -> void:
	_open_file(get_node("%OpenedFilesList").get_item_tooltip(index))


func _open_file(full_path: String, delimiter := "") -> void:
	if _opened_files.has(full_path):
		_opened_files.remove_at(_opened_files.find(full_path))
	_opened_files.append(full_path)
	_current_full_file = full_path
	_config_manager.set_new_file(full_path)
	_current_file = full_path.get_file()
	_current_path = full_path.get_base_dir()

	if delimiter.is_empty():
		delimiter = _config_manager.get_file_value("delimiter", ",")

	_autosave_timer.stop()

	var temp_path := _get_temp_file_path(full_path)
	if FileAccess.file_exists(temp_path):
		_pending_open_path = full_path
		_pending_open_delimiter = delimiter
		_pending_recovery_temp = temp_path
		_recovery_dialog.dialog_text = (
			'Unsaved changes were found for "%s".\nWould you like to recover them?'
			% full_path.get_file()
		)
		_recovery_dialog.popup_centered()
		return

	_do_open_file(full_path, delimiter)


func _do_open_file(full_path: String, delimiter: String) -> void:
	# get dictionary with keys mapped to language translations
	# e.g. {STRGOODBYE:{en:Goodbye!, es:Adiós!}, STRHELLO:{en:Hello!, es:Hola!}}
	_current_data = _csv_loader.load_translations(full_path, delimiter)

	# handle potential errors
	if _current_data.keys().has("ERROR"):
		var err_msg: String = _current_data["ERROR"]
		_close_all()
		alert(err_msg, "Translation Manager - Error")
		return

	# there is nothing to show
	if _translations.size() == 0 and _langs.size() == 0:
		_close_all()
		return

	_config_manager.set_file_value("first_cell", _current_data["first_cell"])

	# clean lists
	_ref_lang_option.clear()
	_target_lang_option.clear()

	# get user's preferred reference language
	var user_ref_lang: String = _config_manager.get_settings_value("main", "user_ref_lang", "en")
	# add languages to the reference and target lists
	var i: int = 0
	for l in _langs:
		_ref_lang_option.add_item(l, i)
		if not user_ref_lang.is_empty() and user_ref_lang == l:
			_ref_lang_option.select(i)
		_target_lang_option.add_item(l, i)
		i += 1

	# if both languages are the same but there is more than one, select the next
	if (
		(_ref_lang_option.get_selected_id() == _target_lang_option.get_selected_id())
		and _langs.size() > 1
	):
		_target_lang_option.select(1)

	get_node("%LblCurrentFTitle").text = get_node("%LblCurrentFTitle").text.replace("(*)", "")
	get_node("%VBxTranslations").init_list(_translations)
	_update_opened_file_list()
	_set_visible_content(true)
	_add_recent_file(full_path)


func _apply_recovery() -> void:
	var file := FileAccess.open(_pending_recovery_temp, FileAccess.READ)
	if not file:
		_pending_recovery_temp = ""
		_do_open_file(_pending_open_path, _pending_open_delimiter)
		return
	var delta = JSON.parse_string(file.get_as_text())
	file = null
	_pending_recovery_temp = ""

	var list_node: Node = get_node("%VBxTranslations")
	list_node.list_ready.connect(_finish_recovery.bind(delta), CONNECT_ONE_SHOT)
	_do_open_file(_pending_open_path, _pending_open_delimiter)


func _finish_recovery(delta: Dictionary) -> void:
	var list_node: Node = get_node("%VBxTranslations")
	await list_node.apply_delta(delta)
	_current_data["translations"] = list_node.get_current_translations()
	_current_data["key_index"] = list_node.get_key_order()
	_on_data_dirtied()


func _discard_recovery() -> void:
	var temp := _pending_recovery_temp
	_pending_recovery_temp = ""
	if not temp.is_empty() and FileAccess.file_exists(temp):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
	_do_open_file(_pending_open_path, _pending_open_delimiter)


func _get_temp_file_path(full_path: String) -> String:
	return full_path.get_base_dir().path_join(
		".gle-temp-" + full_path.get_file().get_basename() + ".json"
	)


func _write_temp_file() -> void:
	if _current_full_file.is_empty():
		return
	var delta: Dictionary = get_node("%VBxTranslations").get_store_delta()
	if delta.is_empty():
		_delete_temp_file()
		return
	var file := FileAccess.open(_get_temp_file_path(_current_full_file), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(delta, "\t"))


func _delete_temp_file() -> void:
	if _current_full_file.is_empty():
		return
	var temp_path := _get_temp_file_path(_current_full_file)
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))


func _update_opened_file_list():
	var file_list: OptionButton = get_node("%OpenedFilesList") as OptionButton
	file_list.clear()
	var i := 0
	for file in _opened_files:
		file_list.add_item(file.get_file())
		file_list.set_item_tooltip(i, file)
		if file == _current_full_file:
			file_list.select(i)
		i += 1


func _on_language_item_selected() -> void:
	_clear_search()
	get_node("%LblCurrentFTitle").text = get_node("%LblCurrentFTitle").text.replace("(*)", "")


func _on_ref_lang_item_selected(index):
	get_node("%VBxTranslations").update_reference_language(_ref_lang_option.get_item_text(index))
	_on_language_item_selected()


func _on_target_lang_item_selected(index):
	get_node("%VBxTranslations").update_target_language(_target_lang_option.get_item_text(index))
	_on_language_item_selected()


func _on_btn_swap_lang_pressed() -> void:
	var t_idx: int = _target_lang_option.get_selected_id()
	var r_idx: int = _ref_lang_option.get_selected_id()
	_target_lang_option.select(r_idx)
	_ref_lang_option.select(t_idx)
	get_node("%VBxTranslations").update_reference_language(
		_ref_lang_option.get_item_text(_ref_lang_option.selected)
	)
	get_node("%VBxTranslations").update_target_language(
		_target_lang_option.get_item_text(_target_lang_option.selected)
	)
	_on_language_item_selected()


func _parse_updated_translation_config(updated_config: Dictionary) -> void:
	var section_key := "%s/%s" % [_current_file, updated_config["key"]]
	if updated_config["old_key"] != updated_config["key"]:
		_current_path_config.erase_section("%s/%s" % [_current_file, updated_config["old_key"]])
	_current_path_config.set_value(section_key, "notes", updated_config["notes"])
	_current_path_config.set_value(section_key, "needs_revision", updated_config["needs_revision"])


func _on_data_dirtied():
	# show indicator of not having saved changes
	if get_node("%LblCurrentFTitle").text.begins_with("(*)") == false:
		get_node("%LblCurrentFTitle").text = "(*)" + get_node("%LblCurrentFTitle").text
	if not _current_full_file.is_empty():
		_autosave_timer.start()


# writing data to the csv
func _save_file() -> void:
	var issues: Dictionary = get_node("%VBxTranslations").get_key_issue_counts()
	var empty_count: int = issues["empty"]
	var duplicate_count: int = issues["duplicates"]

	if empty_count > 0 or duplicate_count > 0:
		var lines: PackedStringArray = []
		if empty_count > 0:
			lines.append(
				"%d entr%s with an empty key" % [empty_count, "ies" if empty_count != 1 else "y"]
			)
		if duplicate_count > 0:
			lines.append(
				(
					"%d entr%s with a duplicate key"
					% [duplicate_count, "ies" if duplicate_count != 1 else "y"]
				)
			)
		_save_warning_dialog.dialog_text = (
			"The following issues were found:\n\n%s\n\nSave anyway?" % "\n".join(lines)
		)
		_save_warning_dialog.popup_centered()
		return

	_do_save()


func _do_save() -> void:
	get_node("%VBxTranslations").flush(
		get_selected_lang("ref"), get_selected_lang("trans"), _translations, _key_index
	)
	var err = _csv_loader.save_translations(
		_get_opened_file(), _current_data, _config_manager.get_file_value("delimiter", ",")
	)
	if err == OK:
		get_node("%LblCurrentFTitle").text = get_node("%LblCurrentFTitle").text.replace("(*)", "")
		_autosave_timer.stop()
		_delete_temp_file()
		get_node("%VBxTranslations").reset_baseline()

	scan_files_requested.emit()


func _on_add_translation_pressed() -> void:
	_add_translation_popup.request_popup(
		get_selected_lang("ref"),
		get_selected_lang("trans"),
		_config_manager.get_file_value("uppercase_keys", true)
	)


func _on_language_removed(selected_lang: String) -> void:
	if _langs.size() < 2:
		alert("You can't remove more languages")
		return

	for t in _translations:
		_translations[t].erase(selected_lang)

	var i: int = 0
	for l in _langs:
		if l == selected_lang:
			_ref_lang_option.remove_item(i)
			_target_lang_option.remove_item(i)
			break
		i += 1

	_langs.erase(selected_lang)

	_ref_lang_option.selected = 0
	_target_lang_option.selected = 0
	# TODO: call remove language
	#_on_language_item_selected(0)
	_on_data_dirtied()


func _on_filter_changed(index: int) -> void:
	match index:
		0:
			_search_filters["need_translation"] = !_search_filters["need_translation"]
		1:
			_search_filters["need_revision"] = !_search_filters["need_revision"]
		_:
			return
	_start_search()


func _on_LineEditSearchBox_text_changed(_new_text: String) -> void:
	_start_search()


# pressed any checkbox from the search bar
func _on_CheckBoxSearch_pressed() -> void:
	# at least one of the checks must be pressed
	if (
		_cb_search_key.button_pressed == false
		and _cb_search_ref_text.button_pressed == false
		and _cb_search_target_text.button_pressed == false
	):
		_cb_search_key.button_pressed = true

	_start_search()


func _on_Dock_resized() -> void:
	if Engine.is_editor_hint() == false and _is_config_initialized:
		_config_manager.set_settings_value(
			"main", "maximized", get_window().mode == Window.MODE_MAXIMIZED
		)


func _on_BtnCloseFile_pressed() -> void:
	get_node("%OpenedFilesList").remove_item(get_node("%OpenedFilesList").selected)

	# if there are no more files, close everything
	if get_node("%OpenedFilesList").get_item_count() == 0:
		_close_all()
	# select the first
	else:
		get_node("%OpenedFilesList").select(0)
		#_on_opened_file_item_selected(0)


func _close_current_file() -> void:
	var opened_files_list: OptionButton = get_node("%OpenedFilesList") as OptionButton
	var selected_index: int = opened_files_list.selected
	var file_to_remove: String = opened_files_list.get_item_tooltip(selected_index)
	_opened_files.remove_at(_opened_files.find(file_to_remove))
	opened_files_list.remove_item(selected_index)
	if opened_files_list.get_item_count() == 0:
		_close_all()
	else:
		opened_files_list.select(0)
		_on_opened_file_item_selected(0)


func _add_recent_file(filename: String) -> void:
	if _recent_files.has(filename):
		_recent_files.remove_at(_recent_files.find(filename))

	_recent_files.insert(0, filename)
	# limit to 10 recent files
	_recent_files = _recent_files.slice(0, 10)
	_config_manager.set_settings_value("main", "recent_files", _recent_files)


func _on_new_file_created(filename: String, first_cell: String, delimiter: String) -> void:
	_config_manager.set_file_value("first_cell", first_cell)
	_config_manager.set_file_value("delimiter", delimiter)
	_open_file(filename)


func _on_add_lang_button_pressed():
	var lang_to_add: String = _add_lang_option.get_item_text(_add_lang_option.selected)
	lang_to_add = lang_to_add.split(",")[1].strip_edges()

	if lang_to_add in _langs:
		alert("The chosen language already exists in the file.")
		return

	_langs.append(lang_to_add)

	# looping each item (the strkeys)
	# if the entry doesn't have the language, add it
	for t_entry in _translations:
		if _translations[t_entry].keys().has(lang_to_add) == false:
			_translations[t_entry][lang_to_add] = ""

	_ref_lang_option.add_item(lang_to_add, _ref_lang_option.get_item_count())
	_target_lang_option.add_item(lang_to_add, _target_lang_option.get_item_count())

	_save_file()

	_new_lang_popup.hide()


func _on_translation_added(
	key: String, ref_text: String, target_text: String, key_is_uppercase: bool
):
	_config_manager.set_file_value("uppercase_keys", key_is_uppercase)

	if _translations.keys().has(key) == true:
		alert("The String key: %s already exists." % [key])
		return

	_translations[key] = {}
	var ref_lang: String = get_selected_lang("ref")
	var target_lang: String = get_selected_lang("trans")

	_translations[key][ref_lang] = ref_text
	_translations[key][target_lang] = target_text
	for l in _langs:
		if l != ref_lang and l != target_lang:
			_translations[key][l] = ""

	# if the languages are the same, copy ref to target
	# TODO: disallow having the same value selected
	if ref_lang == target_lang:
		target_text = ref_text

	get_node("%VBxTranslations").add_entry(key, ref_text, target_text)

	_on_data_dirtied()


func _on_open_file_selected(filename: String, delimiter: String) -> void:
	_open_file(filename, delimiter)


func _on_translation_entry_updated(_new_data: Dictionary) -> void:
	if _translations.is_empty():
		return
	_on_data_dirtied()


func _on_translation_entry_added(new_data: Dictionary) -> void:
	_key_index.append(new_data["key"])
	_on_data_dirtied()


func _on_translation_entry_deleted(key: String) -> void:
	_key_index.remove_at(_key_index.find(key))
	_translations.erase(key)
	_on_data_dirtied()
