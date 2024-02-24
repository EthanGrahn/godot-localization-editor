@tool
extends Control

signal scan_files_requested

const _data_file_name: String = ".gle-data"
const LinkBtnFile = preload("res://addons/localization_editor_plugin_g3/LinkButtonRecentFile.tscn")

@export var _translation_entry_scene: PackedScene
@export var _preferences_window: Popup
@export var _file_dialog: FileDialog
@export var _create_file_popup: Popup
@export var _credits_popup: Popup
@export var _version_label: Label
@export var _new_lang_popup: Popup
@export var _add_lang_option: OptionButton
@export var _ref_lang_option: OptionButton
@export var _target_lang_option: OptionButton
@export var _remove_lang_popup: Popup
@export var _add_translation_popup: Popup
@export var _alert_window: AcceptDialog

var Locales = load("res://addons/localization_editor_plugin_g3/localization_locale_list.gd").new()

var Conf := ConfigFile.new()
var _is_config_initialized := false
var _save_pressed := false

var _translations : Dictionary
var _langs : Array

var _selected_translation_panel : String

var _current_file : String
var _current_path : String
var _current_path_config := ConfigFile.new()

# folder where internal data of the addon is saved, such as keystr annotations
var _settings_file : String = "user://settings.ini"

func _ready() -> void:
	var plugin_conf := ConfigFile.new()
	plugin_conf.load("res://addons/localization_editor_plugin_g3/plugin.cfg")
	_version_label.text = "v%s" % plugin_conf.get_value("plugin", "version", "")
	
	for list in get_tree().get_nodes_in_group("language_options"):
		if not list is OptionButton:
			continue
		(list as OptionButton).clear()
		var i : int = 0
		for l in Locales.LOCALES:
			list.add_item(
				"%s, %s" % [l["name"], l["code"]], i
			)
			i += 1
	
	# conectar señales
	get_node("%MenuFile").get_popup().connect("id_pressed", Callable(self, "_on_FileMenu_id_pressed"))
	get_node("%MenuEdit").get_popup().connect("id_pressed", Callable(self, "_on_EditMenu_id_pressed"))
	get_node("%MenuHelp").get_popup().connect("id_pressed", Callable(self, "_on_HelpMenu_id_pressed"))

	_on_CloseAll()
	
	
	# if running in editor, only use res://
	for dialog in get_tree().get_nodes_in_group("file_access"):
		if not dialog is FileDialog:
			continue
		if Engine.is_editor_hint():
			dialog.access = FileDialog.ACCESS_RESOURCES
		else: # if running standalone, allow full filesystem
			dialog.access = FileDialog.ACCESS_FILESYSTEM

	if FileAccess.file_exists(_settings_file):
		Conf.load(_settings_file)
	_save_settings_config(true)
	_is_config_initialized = true
	
	if Engine.is_editor_hint() == false:
		get_window().mode = Window.MODE_MAXIMIZED if (Conf.get_value("main","maximized", false)) else Window.MODE_WINDOWED
	
	load_recent_files_list()

	# reopen the last file
	if Conf.get_value("main","reopen_last_file",false):
		var recent_files:Array = Conf.get_value("main","recent_files",[])
		if recent_files.is_empty() == false:
			if FileAccess.file_exists(recent_files[0]):
				_on_file_dialog_files_selected([recent_files[0]])

func _process(delta):
	if (not _save_pressed and Input.is_key_pressed(KEY_CTRL)
	and Input.is_key_pressed(KEY_S)):
		_on_BtnSaveFile_pressed()
		_save_pressed = true
	elif _save_pressed and not Input.is_key_pressed(KEY_S):
		_save_pressed = false

func _save_settings_config(_is_init_step := false) -> void:
	if not _is_config_initialized and not _is_init_step:
		return
	Conf.save(_settings_file)

func _save_path_config() -> void:
	_current_path_config.save("%s/%s" % [_current_path, _data_file_name])

func load_recent_files_list() -> void:
	# show recent files
	var recent_list:Array = Conf.get_value("main","recent_files",[])
	
	for n in get_node("%VBxRecentFiles").get_children():
		n.queue_free()
	
	for rl in recent_list:
		var Btn := LinkBtnFile.instantiate()
		Btn.f_path = rl
		Btn.connect("opened", Callable(self, "_OnRecentFile_opened"))
		Btn.connect("removed", Callable(self, "_OnRecentFile_removed"))
		get_node("%VBxRecentFiles").add_child(Btn)
	
	# show message if list is empty
	get_node("%LblNoRecentFiles").visible = recent_list.is_empty()

func _OnRecentFile_opened(f_path:String) -> void:
	_on_file_dialog_files_selected([f_path])

func _OnRecentFile_removed(NodeName:String,f_path:String) -> void:
	var recent_list:Array = Conf.get_value("main", "recent_files", [])
	
	recent_list.erase(f_path)
	Conf.get_value("main", "recent_files", recent_list)
	
	_save_settings_config()

	get_node("%VBxRecentFiles").get_node(NodeName).queue_free()

func start_search() -> void:
	var searchtxt:String = get_node("%LineEditSearchBox").text.strip_edges().to_lower()
	var hide_translated:bool = get_node("%CheckBoxHideCompleted").button_pressed
	var hide_no_need_rev:bool = get_node("%CheckBoxHideNoNeedRev").button_pressed
	var search_key: bool = get_node("%CheckBoxSearchKeyID").button_pressed
	var search_ref_text: bool = get_node("%CheckBoxSearchRefText").button_pressed
	var search_target_text: bool = get_node("%CheckBoxSearchTransText").button_pressed
	
	for tp in get_node("%VBxTranslations").get_children():
		tp.visible = true
		# text search
		if not searchtxt.is_empty():
			tp.visible = (
				(search_key and searchtxt in tp.key.to_lower())
				or (search_ref_text and searchtxt in tp.ref_text.to_lower())
				or (search_target_text and searchtxt in tp.target_text.to_lower())
			)
		
		# hide those that do not have a translation
		if hide_translated and tp.has_translation():
			tp.visible = false
		# hide those that do not need revision
		if hide_no_need_rev and not tp.need_revision:
			tp.visible = false

func clear_search() -> void:
	get_node("%BtnClearSearch").disabled = true
	get_node("%LineEditSearchBox").text = ""
	get_node("%CheckBoxSearchKeyID").button_pressed = true
	get_node("%CheckBoxSearchRefText").button_pressed = true
	get_node("%CheckBoxSearchTransText").button_pressed = true
	get_node("%CheckBoxHideCompleted").button_pressed = false
	get_node("%CheckBoxHideNoNeedRev").button_pressed = false

func alert(txt:String,title:String="Alert!") -> void:
	_alert_window.title = title
	_alert_window.get_node("Label").text = txt
	_alert_window.size = Vector2.ZERO
	_alert_window.popup_centered()

func add_translation_panel(
	strkey:String, ref_txt:String, trans_txt:String, focus_lineedit:bool=false
) -> void:
	var translation_entry = _translation_entry_scene.instantiate()
	translation_entry.translation_requested.connect(_on_translate_requested)
	translation_entry.data_changed.connect(_on_data_dirtied)
	var config_section := "%s/%s" % [_current_file, strkey]
	translation_entry.set_translation_data(
		strkey,
		get_selected_lang("ref"),
		ref_txt,
		get_selected_lang("trans"),
		trans_txt,
		_current_path_config.get_value(config_section, "notes", ""),
		_current_path_config.get_value(config_section, "needs_revision", false),
		focus_lineedit
	)

	get_node("%VBxTranslations").call_deferred("add_child", translation_entry)


func get_opened_file() -> String:
	return _current_path + "/" + _current_file

# get list of available languages
func get_langs() -> Array:
	var langs_list:Array
	var available_langs_count:int = _ref_lang_option.get_item_count()
	var i:int = 0
	for l in available_langs_count:
		langs_list.append(
			_ref_lang_option.get_item_text(i)
		)
		i += 1
	return langs_list

# get the selected language (ref or trans)
func get_selected_lang(mode:String="ref") -> String:
	var node : OptionButton = _ref_lang_option
	if mode != "ref":
		node = _target_lang_option
	return node.get_item_text(node.selected)

func _set_visible_content(vis:bool=true) -> void:
	get_node("%HBxFileAndLangSelect").visible = vis
	get_node("%HBxContentFile").visible = vis
	get_node("%ControlNoOpenedFiles").visible = ! vis

func _on_FileMenu_id_pressed(id:int) -> void:
	match id:
		1:
			_create_file_popup.popup_centered()
		2:
			_file_dialog.popup_centered()
		3:
			_on_CloseAll()

func _on_EditMenu_id_pressed(id:int) -> void:
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
			_preferences_window.set_defaults(Conf)
			_preferences_window.popup_centered()

func _on_HelpMenu_id_pressed(id:int) -> void:
	match id:
		1:
			OS.shell_open("https://github.com/EthanGrahn/godot-localization-editor?tab=readme-ov-file#usage-guide")
		2:
			_credits_popup.popup_centered()

func _on_FilesLoaded() -> void:
	_set_visible_content(true)

func _on_CloseAll() -> void:
	load_recent_files_list()
	clear_search()
	# initial settings
	_set_visible_content(false)
	_on_Popup_hide()
	# clean fields
	_current_file = ""
	_current_path = ""
	get_node("%OpenedFilesList").clear()
	get_node("%ControlNoOpenedFiles").visible = true
	_translations = {}
	_langs = []
	
# Show or hide a popup
func _on_Popup_about_to_show() -> void:
	get_node("%PopupBG").visible = true
func _on_Popup_hide() -> void:
	get_node("%PopupBG").visible = false

# a file was selected from the list
func _on_OpenedFilesList_item_selected(index: int) -> void:
	_current_file = get_node("%OpenedFilesList").get_item_text(index)

	# dict with text keys mapped to a dict containing translations
	# e.g. {STRGOODBYE:{en:Goodbye!, es:Adiós!}, STRHELLO:{en:Hello!, es:Hola!}}
	_translations = CSVLoader.load_csv_translation(get_opened_file(), Conf)

	if _translations.size() == 1 and _translations.keys().has("TMERROR"):
		var err_msg:String = _translations["TMERROR"]
		_on_CloseAll()
		alert(
			err_msg, "Translation Manager - Error"
		)
		return

	# there is nothing to show
	if _translations.size() == 0 and _langs.size() == 0:
		_on_CloseAll()
		return
	
	if _translations.size() > 0:
		# if it only contains the list of languages, set variables to empty
		# from now on only _langs will be used in the rest of the func
		if _translations.size() == 1 and _translations.keys().has("EMPTYTRANSLATIONS"):
			_langs = _translations["EMPTYTRANSLATIONS"]
			_translations = {}
		else:
			# get array of languages parsed from the file
			_langs = _translations[_translations.keys()[0]].keys()
	
	# clean lists
	_ref_lang_option.clear()
	_target_lang_option.clear()

	var user_ref_lang: String = Conf.get_value("main","user_ref_lang", "")
	# add languages from the file
	var i : int = 0
	for l in _langs:
		_ref_lang_option.add_item(l, i)
		if not user_ref_lang.is_empty() and user_ref_lang == l:
			_ref_lang_option.select(i)
		_target_lang_option.add_item(l, i)
		i += 1

	# if both languages are the same, but there is more than one language
	# select the subsequent language in TargetLangItemList
	if (
		(_ref_lang_option.get_selected_id() == _target_lang_option.get_selected_id())
		and _langs.size() > 1
	):
		_target_lang_option.select(1)

	# upload translations
	_on_LangItemList_item_selected(0)

	_on_FilesLoaded()

# changed the language selected in the item list
# this loses any unsaved change
# load translation panels
func _on_LangItemList_item_selected(_index: int) -> void:
	
	clear_search()

	get_node("%LblCurrentFTitle").text = get_node("%LblCurrentFTitle").text.replace("(*)","")
	
	_selected_translation_panel = ""
	
	# clear list of on-screan translations
	for t in get_node("%VBxTranslations").get_children():
		t.queue_free()

	# add translation panels
	var selected_lang_ref : String = get_selected_lang("ref")
	var selected_lang_trans : String = get_selected_lang("trans")
	for t_key in _translations:
		add_translation_panel(
			t_key,
			_translations[t_key][selected_lang_ref],
			_translations[t_key][selected_lang_trans]
		)

# translation requested
func _on_translate_requested(source_lang: String, source_text: String,
	target_lang: String, target_text: String, callback: Callable) -> void:
	$ApiTranslate.translate(
		source_lang,
		target_lang,
		source_text,
		callback
	)

func _parse_translation_entries():
	var target_lang: String = get_selected_lang("trans")
	var ref_lang: String = get_selected_lang("ref")
	for entry in get_node("%VBxTranslations").get_children():
		var translation_data: Dictionary = entry.get_translation_data()
		var config_data: Dictionary = entry.get_config_data()
		if translation_data["old_key"] != translation_data["key"]:
			_translations[translation_data["key"]] = _translations[translation_data["old_key"]].duplicate(true)
			_translations.erase(translation_data["old_key"])
		_translations[translation_data["key"]][target_lang] = translation_data["target_text"]
		_translations[translation_data["key"]][ref_lang] = translation_data["ref_text"]
		if config_data["updated"]:
			_parse_updated_translation_config(config_data)
	_save_path_config()

func _parse_updated_translation_config(updated_config: Dictionary) -> void:
	var section_key := "%s/%s" % [_current_file, updated_config["key"]]
	if updated_config["old_key"] != updated_config["key"]:
		_current_path_config.erase_section("%s/%s" % [_current_file, updated_config["old_key"]])
	_current_path_config.set_value(
		section_key,
		"notes",
		updated_config["notes"]
	)
	_current_path_config.set_value(
		section_key,
		"needs_revision",
		updated_config["needs_revision"]
	)

func _on_data_dirtied():
	# show indicator of not having saved changes
	if get_node("%LblCurrentFTitle").text.begins_with("(*)") == false:
		get_node("%LblCurrentFTitle").text = "(*)" + get_node("%LblCurrentFTitle").text

func _on_CTCheckEnableOriginalTxt_toggled(button_pressed: bool) -> void:
	get_node("%TxtOriginalTxt").editable = button_pressed

# writing data to the csv
func _on_BtnSaveFile_pressed() -> void:
	_parse_translation_entries()
	var err = CSVLoader.save_csv_translation(
		get_opened_file(),
		_translations, _langs,
		Conf
	)
	if err == OK:
		get_node("%LblCurrentFTitle").text = get_node("%LblCurrentFTitle").text.replace("(*)","")

	scan_files_requested.emit()

# pressed add translation
func _on_BtnAddTranslation_pressed() -> void:
	_add_translation_popup.request_popup(
		get_selected_lang("ref"),
		get_selected_lang("trans"),
		_current_path_config.get_value(_current_file, "uppercase_keys", true)
	)

func _on_language_removed(selected_lang: String) -> void:
	if _langs.size() < 2:
		alert("You can't remove more languages")
		return
	
	for t in _translations:
		_translations[t].erase(selected_lang)
	
	var i:int = 0
	for l in _langs:
		if l == selected_lang:
			_ref_lang_option.remove_item(i)
			_target_lang_option.remove_item(i)
			break
		i += 1
	
	_langs.erase(selected_lang)
	
	_ref_lang_option.selected = 0
	_target_lang_option.selected = 0
	_on_LangItemList_item_selected(0)
	_on_data_dirtied()

func _on_CheckBoxHideCompleted_pressed() -> void:
	if get_node("%CheckBoxHideCompleted").button_pressed == true:
		get_node("%BtnClearSearch").disabled = false
	start_search()
func _on_CheckBoxShowNeedRev_pressed() -> void:
	if get_node("%CheckBoxHideNoNeedRev").button_pressed == true:
		get_node("%BtnClearSearch").disabled = false
	start_search()

func _on_LineEditSearchBox_text_changed(new_text: String) -> void:
	get_node("%BtnClearSearch").disabled = new_text.strip_edges().is_empty()
	start_search()

# pressed any checkbox from the search bar
func _on_CheckBoxSearch_pressed() -> void:
	
	# at least one of the checks must be pressed
	if (
		get_node("%CheckBoxSearchKeyID").button_pressed == false
		and get_node("%CheckBoxSearchRefText").button_pressed == false
		and get_node("%CheckBoxSearchTransText").button_pressed == false
	):
		get_node("%CheckBoxSearchKeyID").button_pressed = true
	
	# if at least one of the checks is disabled
	if (
		get_node("%CheckBoxSearchKeyID").button_pressed == false
		or get_node("%CheckBoxSearchRefText").button_pressed == false
		or get_node("%CheckBoxSearchTransText").button_pressed == false
	):
		get_node("%BtnClearSearch").disabled = false
	
	start_search()

func _on_BtnClearSearch_pressed() -> void:
	clear_search()
	start_search()


func _on_Dock_resized() -> void:
	if Engine.is_editor_hint() == false:
		Conf.set_value("main","maximized",(get_window().mode == Window.MODE_MAXIMIZED))
		_save_settings_config()
		

# close opened file
func _on_BtnCloseFile_pressed() -> void:
	
	get_node("%OpenedFilesList").remove_item(
		get_node("%OpenedFilesList").selected
	)

	# if there are no more files, close everything
	if get_node("%OpenedFilesList").get_item_count() == 0:
		_on_CloseAll()
	# select the first
	else:
		get_node("%OpenedFilesList").select(0)
		_on_OpenedFilesList_item_selected(0)



func _on_preferences_updated(preferences: Array[Dictionary]) -> void:
	for pref in preferences:
		Conf.set_value(pref["section"], pref["key"], pref["value"])
	_save_settings_config()


func _on_file_dialog_files_selected(paths: PackedStringArray) -> void:
	get_node("%OpenedFilesList").clear()

	var i : int = 0
	for p in paths:
		# if some of the files do not exist, remove from the list of paths
		# TODO: improve or make sure it works
		if FileAccess.file_exists(p) == false:
			paths.remove_at(i)
		else:
			get_node("%OpenedFilesList").add_item(
				p.get_file(), i
			)
			
			# add path to recent files list
			var recent_limit:int = 10
			var recent_list:Array = Conf.get_value("main","recent_files",[])
			if recent_list.has(p) == false:
				if recent_list.size() >= recent_limit:
					recent_list.remove_at(recent_list.size()-1)
				recent_list.append(p)
			# the path was already listed
			# delete it and place it at the top of the array
			else:
				recent_list.erase(p)
				recent_list.push_front(p)
			
			Conf.set_value("main","recent_files", recent_list)
			
		i += 1
	
	_save_settings_config()

	if paths.size() == 0:
		_set_visible_content(false)
		return
	
	_current_path = paths[0].get_base_dir()
	var config_path := "%s/%s" % [_current_path, _data_file_name]
	if FileAccess.file_exists(config_path):
		_current_path_config.load(config_path)
	_save_path_config()

	# show the path of the file
	get_node("%LblOpenedPath").text = "[%s]" % [_current_path]
	
	# send signal of first selected item since it is not activated by default
	_on_OpenedFilesList_item_selected(0)
	
	clear_search()


func _on_new_file_created(filename: String) -> void:
	_on_file_dialog_files_selected([filename])


func _on_add_lang_button_pressed():
	var lang_to_add:String = _add_lang_option.get_item_text(
		_add_lang_option.selected
	)
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
	
	_ref_lang_option.add_item(
		lang_to_add, _ref_lang_option.get_item_count()
	)
	_target_lang_option.add_item(
		lang_to_add, _target_lang_option.get_item_count()
	)
	
	_on_BtnSaveFile_pressed()
	
	_new_lang_popup.hide()


func _on_translation_added(key: String, ref_text: String, target_text: String, key_is_uppercase: bool):
	_current_path_config.set_value(_current_file, "uppercase_keys", key_is_uppercase)
	_save_settings_config()
	
	if _translations.keys().has(key) == true:
		alert(
			"The String key: %s already exists." % [key]
		)
		return
	
	_translations[key] = {}
	var ref_lang: String = get_selected_lang("ref")
	var target_lang: String = get_selected_lang("trans")
	
	_translations[key][ref_lang] = ref_text
	_translations[key][target_lang] = target_text
	print(_translations[key])
	for l in get_langs():
		if l != ref_lang and l != target_lang:
			_translations[key][l] = ""
	
	# if the languages are the same, copy ref to target
	# TODO: disallow having the same value selected
	if ref_lang == target_lang:
		target_text = ref_text
	
	# add dashboard
	add_translation_panel(key, ref_text, target_text, true)
	
	_on_data_dirtied()
	
	await get_tree().process_frame
	get_node("%ScrollContainerTranslationsPanels").ensure_control_visible(get_viewport().gui_get_focus_owner())
