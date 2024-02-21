@tool
extends Control

signal scan_files_requested

const _data_file_name: String = ".gle-data"
const LinkBtnFile = preload("res://addons/localization_editor_plugin_g3/LinkButtonRecentFile.tscn")
const TranslationItem = preload("res://addons/localization_editor_plugin_g3/HBxItemTranslation.tscn")

var Locales = load("res://addons/localization_editor_plugin_g3/localization_locale_list.gd").new()

var Conf := ConfigFile.new()
var _is_config_initialized := false

var _translations : Dictionary
var _langs : Array

var _selected_translation_panel : String

var _current_file : String
var _current_path : String

# folder where internal data of the addon is saved, such as keystr annotations
var _settings_file : String = "user://settings.ini"

func _ready() -> void:
	
	get_node("%LblGodotEng").text = "Made with Godot Engine %d.%d.%d %s" % [
		Engine.get_version_info()["major"],
		Engine.get_version_info()["minor"],
		Engine.get_version_info()["patch"],
		Engine.get_version_info()["status"],
	]
	
	get_node("%LblTextBottom").text = "v%s" % get_plugin_info("version")
	
	get_node("%LblCreditTitle").text = get_plugin_info("name")
	get_node("%LblCreditDescription").text = get_plugin_info("description")

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
	if Engine.is_editor_hint():
		get_node("%FileDialog").access = FileDialog.ACCESS_RESOURCES
		get_node("%FileDialogNewFilePath").access = FileDialog.ACCESS_RESOURCES
	else: # if running standalone, allow full filesystem
		get_node("%FileDialog").access = FileDialog.ACCESS_FILESYSTEM
		get_node("%FileDialogNewFilePath").access = FileDialog.ACCESS_FILESYSTEM

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
				_on_FileDialog_files_selected([recent_files[0]])

func _save_settings_config(_is_init_step := false) -> void:
	if not _is_config_initialized and not _is_init_step:
		return
	Conf.save(_settings_file)

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
	_on_FileDialog_files_selected([f_path])

func _OnRecentFile_removed(NodeName:String,f_path:String) -> void:
	var recent_list:Array = Conf.get_value("main", "recent_files", [])
	
	recent_list.erase(f_path)
	Conf.get_value("main", "recent_files", recent_list)
	
	_save_settings_config()

	get_node("%VBxRecentFiles").get_node(NodeName).queue_free()


func get_plugin_info(val:String) -> String:
	var ConfPlugin := ConfigFile.new()
	ConfPlugin.load("res://addons/localization_editor_plugin_g3/plugin.cfg")
	return ConfPlugin.get_value("plugin", val, "")

func start_search() -> void:
	var searchtxt:String = get_node("%LineEditSearchBox").text.strip_edges().to_lower()
	var hide_translated:bool = get_node("%CheckBoxHideCompleted").button_pressed
	var hide_no_need_rev:bool = get_node("%CheckBoxHideNoNeedRev").button_pressed
	
	for tp in get_node("%VBxTranslations").get_children():
		tp.visible = true
		# text search
		if searchtxt.is_empty()== false:
			if (
				(get_node("%CheckBoxSearchKeyID").pressed and searchtxt in tp.key_str.to_lower())
				or (get_node("%CheckBoxSearchRefText").pressed and searchtxt in tp.orig_txt.to_lower())
				or (get_node("%CheckBoxSearchTransText").pressed and searchtxt in tp.trans_txt.to_lower())
			):
				tp.visible = true
			else:
				tp.visible = false
		
		# hide those that do not have a translation
		if hide_translated and tp.has_translation() == true:
			tp.visible = false
		# hide those that do not need revision
		if hide_no_need_rev and tp.need_revision == false:
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
	get_node("%WindowDialogAlert").title = title
	get_node("%WindowDialogAlert").get_node("MarginContainer/VBoxContainer/Label").text = txt
	get_node("%WindowDialogAlert").popup_centered()

func add_translation_panel(
	strkey:String, ref_txt:String, trans_txt:String, focus_lineedit:bool=false
) -> void:
	
	var TransInstance = TranslationItem.instantiate()
	var extra_data_path : String = _current_path + "/" + _data_file_name
	var TransConf := ConfigFile.new()
	
	TransConf.load(extra_data_path)

	TransInstance.connect("translate_requested", Callable(self, "_on_Translation_translate_requested"))
	TransInstance.connect("text_updated", Callable(self, "_on_Translation_text_updated"))
	TransInstance.connect("edit_requested", Callable(self, "_on_Translation_edit_requested"))
	TransInstance.connect("need_revision_check_pressed", Callable(self, "_on_Translation_need_revision_check_pressed"))

	TransInstance.focus_on_ready = focus_lineedit

	TransInstance.key_str = strkey

	TransInstance.orig_txt = ref_txt
	TransInstance.trans_txt = trans_txt
	TransInstance.need_revision = TransConf.get_value(strkey, "need_rev", false)
	TransInstance.annotations = TransConf.get_value(strkey, "annotations", "")

	get_node("%VBxTranslations").call_deferred("add_child", TransInstance)


func get_opened_file() -> String:
	return _current_path + "/" + _current_file

# get list of available languages
func get_langs() -> Array:
	var langs_list:Array
	var available_langs_count:int = get_node("%RefLangItemList").get_item_count()
	var i:int = 0
	for l in available_langs_count:
		langs_list.append(
			get_node("%RefLangItemList").get_item_text(i)
		)
		i += 1
	return langs_list

# get the selected language (ref or trans)
func get_selected_lang(mode:String="ref") -> String:
	var nod : String = "%RefLangItemList"
	if mode != "ref":
		nod = "%TransLangItemList"
	return get_node(nod).get_item_text(
		get_node(nod).selected
	)

func _set_visible_content(vis:bool=true) -> void:
	get_node("%HBxFileAndLangSelect").visible = vis
	get_node("%HBxContentFile").visible = vis
	get_node("%ControlNoOpenedFiles").visible = ! vis

func _on_FileMenu_id_pressed(id:int) -> void:
	match id:
		1:
			get_node("%WindowDialogCreateFile").popup_centered()
			get_node("%LineEditNewFileName").grab_focus()
		2:
			get_node("%FileDialog").popup_centered()
		3:
			_on_CloseAll()

func _on_EditMenu_id_pressed(id:int) -> void:
	match id:
		1:
			# add new language
			if get_node("%ControlNoOpenedFiles").visible == false:
				get_node("%WindowDialogAddNewLang").popup_centered()
		2:
			# delete language
			if get_node("%ControlNoOpenedFiles").visible == false and _langs.size() > 0:
				
				get_node("%OptionButtonLangsToRemoveList").clear()
				var i:int = 0
				for l in _langs:
					get_node("%OptionButtonLangsToRemoveList").add_item(l,i)
					i += 1
				
				get_node("%WindowDialogRemoveLang").popup_centered()
		3:
			# open program settings
			get_node("%Preferences").set_defaults(Conf)
			get_node("%Preferences").popup_centered()

func _on_HelpMenu_id_pressed(id:int) -> void:
	match id:
		1:
			OS.shell_open("https://ko-fi.com/Post/How-to-use-Localization-Editor-V7V7GF7GH")
		2:
			# credits
			get_node("%WindowDialogCredits").popup_centered()

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

func _on_FileDialog_files_selected(paths: PackedStringArray) -> void:
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

	# show the path of the file
	get_node("%LblOpenedPath").text = "[%s]" % [_current_path]
	
	# send signal of first selected item since it is not activated by default
	_on_OpenedFilesList_item_selected(0)
	
	clear_search()

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
#		OS.alert(
#			err_msg, "Translation Manager - Error"
#		)
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
	get_node("%RefLangItemList").clear()
	get_node("%TransLangItemList").clear()

	var user_ref_lang: String = Conf.get_value("main","user_ref_lang", "")
	# add languages from the file
	var i : int = 0
	for l in _langs:
		get_node("%RefLangItemList").add_item(
			l, i
		)
		if not user_ref_lang.is_empty() and user_ref_lang == l:
			get_node("%RefLangItemList").select(i)
		get_node("%TransLangItemList").add_item(
			l, i
		)
		i += 1

	# if both languages are the same, but there is more than one language
	# select the following language in TransLangItemList
	if (
		(get_node("%RefLangItemList").get_selected_id() == get_node("%TransLangItemList").get_selected_id())
		and _langs.size() > 1
	):
		get_node("%TransLangItemList").select(1)

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
func _on_Translation_translate_requested(TransNodeName:String, text_to_trans:String) -> void:
	$ApiTranslate.translate(
		get_selected_lang("ref"),
		get_selected_lang("trans"),
		text_to_trans, TransNodeName
	)

# pressed edit button for the selected translation
func _on_Translation_edit_requested(TransNodeName:String) -> void:
	
	_selected_translation_panel = TransNodeName
	
	var TranslationObj = get_node("%VBxTranslations").get_node(TransNodeName)
	
	get_node("%CTCheckEditKey").button_pressed = false
	_on_CTCheckEditKey_toggled(false)
	get_node("%CTCheckEnableOriginalTxt").button_pressed = false
	get_node("%TxtOriginalTxt").editable = false
	
	# set data
	get_node("%LblOriginalTxt").text = "[%s] Original Text" % [get_selected_lang("ref").capitalize()]
	get_node("%LblTranslation").text = "[%s] Translation" % [get_selected_lang("trans").capitalize()]
	
	get_node("%CTLineEdit").text = TranslationObj.key_str
	get_node("%TxtOriginalTxt").text = TranslationObj.orig_txt
	get_node("%TxtTranslation").text = TranslationObj.trans_txt
	get_node("%TxtAnnotations").text = TranslationObj.annotations
	
	# hide reference text panel if editing the same language
	if get_selected_lang("ref") == get_selected_lang("trans"):
		get_node("%VBxRefText").visible = false
		# also hide difference bar
		get_node("%DifferenceBar").visible = false
	else:
		get_node("%VBxRefText").visible = true
		get_node("%DifferenceBar").visible = true
	
	_on_TextEditPanel_text_changed()
	
	get_node("%DialogEditTranslation").popup_centered()
	
	#get_node("%TxtTranslation").grab_focus()

# the line edit of the selected translation has been edited
func _on_Translation_text_updated(NodeName:String, keystr:String, txt:String) -> void:
	_translations[keystr][get_selected_lang("trans")] = txt
	# show indicator of not having saved changes
	if get_node("%LblCurrentFTitle").text.begins_with("(*)") == false:
		get_node("%LblCurrentFTitle").text = "(*)" + get_node("%LblCurrentFTitle").text

	# if you're editing the translation from the same language
	if get_selected_lang("ref") == get_selected_lang("trans"):
		get_node("%VBxTranslations").get_node(NodeName).orig_txt = txt

# pressed needs revision checkbox
func _on_Translation_need_revision_check_pressed(key:String,pressed:bool) -> void:
	var extra_data_path : String = _current_path + "/" + _data_file_name
	var TransConf = ConfigFile.new()
	TransConf.load(extra_data_path)
	TransConf.set_value(key, "need_rev", pressed)
	TransConf.save(extra_data_path)

# enable editing or deletion of StringKey and all its translations
func _on_CTCheckEditKey_toggled(button_pressed: bool) -> void:
	get_node("%CTLineEdit").editable = button_pressed
	#get_node("%CTBtnDeleteKey").disabled = ! button_pressed
	get_node("%CTBtnDeleteKey").visible = button_pressed


# delete translation based on the string key from the edit popup
func _on_CTBtnDeleteKey_pressed() -> void:
	var TranslationObj = get_node("%VBxTranslations").get_node(_selected_translation_panel)
	
	var extra_data_path : String = _current_path + "/" + _data_file_name
	var TransConf = ConfigFile.new()
	TransConf.load(extra_data_path)
	
	# delete from dictionary
	_translations.erase(TranslationObj.key_str)
	
	# delete from configuration
	if TransConf.has_section(TranslationObj.key_str):
		TransConf.erase_section(TranslationObj.key_str)
		TransConf.save(extra_data_path)
	
	# delete panel
	TranslationObj.queue_free()
	
	# show indicator that there are unsaved changes
	#get_node("%LblCurrentFTitle").text = "(*)" + get_node("%LblCurrentFTitle").text
	
	_selected_translation_panel = ""
	get_node("%DialogEditTranslation").hide()

	_on_BtnSaveFile_pressed()

# save string key data from the edit popup
func _on_CTBtnSaveKey_pressed() -> void:
	var extra_data_path : String = _current_path + "/" + _data_file_name
	var TransConf = ConfigFile.new()
	TransConf.load(extra_data_path)
	
	var TranslationObj = get_node("%VBxTranslations").get_node(_selected_translation_panel)
	
	# if the strkey field is checked
	# rename the keystr to a new one
	if get_node("%CTCheckEditKey").button_pressed == true:
		
		if get_node("%CTLineEdit").text in _translations.keys():
			OS.alert("The String Key [%s] is already in use"%[get_node("%CTLineEdit").text])
			return
		
		var conf_values : Array
		# create a new entry with the new key, copying the values of the previous one
		_translations[get_node("%CTLineEdit").text] = _translations[TranslationObj.key_str]
		
		if TransConf.has_section(TranslationObj.key_str):
			for c in TransConf.get_section_keys(TranslationObj.key_str):
				# save [confkey,value]
				conf_values.append(
					[c, TransConf.get_value(TranslationObj.key_str,c)]
				)
		
		# erase the old
		_translations.erase(TranslationObj.key_str)
		
		if TransConf.has_section(TranslationObj.key_str):
			TransConf.erase_section(TranslationObj.key_str)
		
		# set the new keystr to the translation panel
		TranslationObj.key_str = get_node("%CTLineEdit").text
		
		if conf_values.is_empty() == false:
			for c in conf_values:
				TransConf.set_value(
					get_node("%CTLineEdit").text, # section
					c[0],c[1]
				)
	
	# if the original text check is checked
	if get_node("%CTCheckEnableOriginalTxt").button_pressed == true:
		# store the panel text
		TranslationObj.orig_txt = get_node("%TxtOriginalTxt").text
		# save it in the dictionary
		_translations[TranslationObj.key_str][get_selected_lang("ref")] = TranslationObj.orig_txt
	
	# save translated text to the dashboard
	TranslationObj.trans_txt = get_node("%TxtTranslation").text
	# and save to the dictionary
	_translations[TranslationObj.key_str][get_selected_lang("trans")] = TranslationObj.trans_txt
	
	# if the same language is edited, save the orig_txt variable as well
	if get_selected_lang("ref") == get_selected_lang("trans"):
		# store the panel text
		TranslationObj.orig_txt = TranslationObj.trans_txt
		# save it in the dictionary
		_translations[TranslationObj.key_str][get_selected_lang("ref")] = TranslationObj.orig_txt
	
	# save annotations
	TranslationObj.annotations = get_node("%TxtAnnotations").text
	TransConf.set_value(TranslationObj.key_str, "annotations", TranslationObj.annotations)
	TransConf.save(extra_data_path)
	
	# send save all button signal
	get_node("%BtnSaveFile").emit_signal("pressed")
	
	get_node("%DialogEditTranslation").hide()

func _on_CTCheckEnableOriginalTxt_toggled(button_pressed: bool) -> void:
	get_node("%TxtOriginalTxt").editable = button_pressed

# writing data to the csv
func _on_BtnSaveFile_pressed() -> void:
	var err = CSVLoader.save_csv_translation(
		get_opened_file(),
		_translations, _langs,
		Conf
	)
	if err == OK:
		get_node("%LblCurrentFTitle").text = get_node("%LblCurrentFTitle").text.replace("(*)","")

	emit_signal("scan_files_requested")

# the text has changed in any of the text panels
# on the edit translation panel
func _on_TextEditPanel_text_changed() -> void:
	# obtain text size, not counting spaces, tabs, or line breaks
	var orig_size:int = get_node("%TxtOriginalTxt").text.strip_edges().strip_escapes().length()
	var trans_size:int = get_node("%TxtTranslation").text.strip_edges().strip_escapes().length()
	var diff:int = 0
	var diff_percent:float = 0
	
	# the total difference if...
	# if the translation is larger than the original text
	# or if the fields are empty
	if trans_size > orig_size or trans_size == 0 or orig_size == 0:
		diff_percent = 100
	else:
		# difference in the number of characters
		diff = abs(orig_size-trans_size)
		# convert to percentage
		diff_percent = (float(diff)/float(orig_size)) * 100.0

	get_node("%DifferenceBar").value = diff_percent
	
	# show colors in the bar
#	if diff_percent < 20:
#		get_node("%DifferenceBar").tint_progress = Color.white
#	elif diff_percent < 50:
#		get_node("%DifferenceBar").tint_progress = Color.yellow
#	elif diff_percent < 80:
#		get_node("%DifferenceBar").tint_progress = Color.orange
#	else:
#		get_node("%DifferenceBar").tint_progress = Color.red

# a translation has been received
func _on_ApiTranslate_text_translated(
	id, _from_lang, _to_lang, _original_text, translated_text
) -> void:
	var TransObj = get_node("%VBxTranslations").get_node_or_null(id)
	if TransObj != null:
		TransObj.update_trans_txt(translated_text)
		TransObj._on_LineEditTranslation_text_changed(translated_text)

# pressed add translation
func _on_BtnAddTranslation_pressed() -> void:
	
	get_node("%CheckBoxNewSTRKeyUppercase").button_pressed = Conf.get_value("main", "uppercase_on_input", true)
	
	get_node("%LineEditKeyStrNewTransItem").text = ""
	get_node("%LineEditRefTxtNewTransItem").placeholder_text = "[%s] Text here..." % [get_selected_lang("ref")]
	get_node("%LineEditRefTxtNewTransItem").text = ""
	get_node("%LineEditTransTxtNewTransItem").placeholder_text = "[%s] Text here... (optional)" % [get_selected_lang("trans")]
	get_node("%LineEditTransTxtNewTransItem").text = ""
	
	get_node("%BtnAddTransItem").disabled = true
	get_node("%WindowDialogAddTranslationItem").popup_centered()
	get_node("%LineEditKeyStrNewTransItem").grab_focus()
	
	if get_selected_lang("ref") == get_selected_lang("trans"):
		get_node("%LineEditTransTxtNewTransItem").visible = false
	else:
		get_node("%LineEditTransTxtNewTransItem").visible = true

# the new languages panel appears
func _on_WindowDialogAddNewLang_about_to_show() -> void:
	pass # Replace with function body.
# add new selected language
func _on_BtnAddNewLang_pressed() -> void:
	var lang_to_add:String = get_node("%OptionButtonAvailableLangsList").get_item_text(
		get_node("%OptionButtonAvailableLangsList").selected
	)
	lang_to_add = lang_to_add.split(",")[1].strip_edges()
	
	if lang_to_add in _langs:
		OS.alert("The language already exists in the file.")
		return

	_langs.append(lang_to_add)

	# looping each item (the strkeys)
	# if the entry doesn't have the language, add it
	for t_entry in _translations:
		if _translations[t_entry].keys().has(lang_to_add) == false:
			_translations[t_entry][lang_to_add] = ""
	
	get_node("%RefLangItemList").add_item(
		lang_to_add, get_node("%RefLangItemList").get_item_count()
	)
	get_node("%TransLangItemList").add_item(
		lang_to_add, get_node("%TransLangItemList").get_item_count()
	)
	
	_on_BtnSaveFile_pressed()
	
	get_node("%WindowDialogAddNewLang").hide()

func _on_BtnNewFileAddLang_pressed() -> void:
	var delim : String = Conf.get_value("csv","delimiter",",")
	var new_text : String
	var new_lang : String = get_node("%OptionButtonLangsNewFile").get_item_text(
		get_node("%OptionButtonLangsNewFile").selected
	)
	new_lang = new_lang.split(", ")[1]
	
	if new_lang in get_node("%TextEditNewFileLangsAdded").text:
		return

	new_text = "%s%s %s" % [
		get_node("%TextEditNewFileLangsAdded").text, delim, new_lang
	]
	
	new_text = new_text.trim_prefix(delim).strip_edges()
	
	get_node("%TextEditNewFileLangsAdded").text = new_text


func _on_FileDialogNewFilePath_dir_selected(dir: String) -> void:
	get_node("%LineEditNewFilePath").text = dir


func _on_BtnNewFileExplorePath_pressed() -> void:
	get_node("%FileDialogNewFilePath").popup_centered()


func _on_BtnNewFileCreate_pressed() -> void:
	var f_cell : String = Conf.get_value("csv","f_cell","keys")
	var delim : String = Conf.get_value("csv","delimiter",",")
	
	var namefile : String = get_node("%LineEditNewFileName").text.strip_edges()
	var filepath : String = get_node("%LineEditNewFilePath").text
	var langs_txt : String = get_node("%TextEditNewFileLangsAdded").text.replace(" ","")
	var headers_list : Array = langs_txt.split(delim, false)
	
	if filepath.is_empty() == true:
		OS.alert("Please add a file path.")
		return
	
	if namefile.is_empty() == true:
		namefile = str(Time.get_ticks_usec())
	
	if headers_list.size() == 0:
		headers_list.append("en")
	
	# add the fcell
	headers_list.push_front(f_cell)
	
	var out_file = FileAccess.open(
		"%s/%s.csv" % [filepath,namefile], FileAccess.WRITE
	)
	
	if out_file.get_open_error() == Error.OK:
		out_file.store_csv_line(headers_list,delim)
		out_file.close()
		# saved file open
		_on_FileDialog_files_selected([
			"%s/%s.csv" % [filepath,namefile]
		])
		
		# clean data
		get_node("%LineEditNewFileName").text = ""
		get_node("%LineEditNewFilePath").text = ""
		get_node("%TextEditNewFileLangsAdded").text = ""
		
		get_node("%WindowDialogCreateFile").hide()
	else:
		OS.alert("Error creating file. Error #"+str(out_file.get_open_error()))
		out_file.close()

# in the add translation pane any of the LineEdit has been modified
func _on_NewTransLineEdit_text_changed(_new_text: String) -> void:
	var strkey:String = get_node("%LineEditKeyStrNewTransItem").text.strip_edges()
	var reftxt:String = get_node("%LineEditRefTxtNewTransItem").text.strip_edges()
	var transtxt:String = get_node("%LineEditTransTxtNewTransItem").text.strip_edges()
	
	if (
		strkey.is_empty() == true 
		or reftxt.is_empty() == true 
	):
		get_node("%BtnAddTransItem").disabled = true
	else:
		get_node("%BtnAddTransItem").disabled = false

# clocked add translation in the new translation panel
func _on_BtnAddTransItem_pressed() -> void:
	var ref_lang:String = get_selected_lang("ref")
	var trans_lang:String = get_selected_lang("trans")
	
	var strkey:String = get_node("%LineEditKeyStrNewTransItem").text.strip_edges()
	var reftxt:String = get_node("%LineEditRefTxtNewTransItem").text.strip_edges()
	var transtxt:String = get_node("%LineEditTransTxtNewTransItem").text.strip_edges()
	
	if _translations.keys().has(strkey) == true:
		OS.alert(
			"The String key: %s already exists." % [strkey]
		)
		return
	
	_translations[strkey] = {}
	
	for l in get_langs():
		if l == ref_lang or ref_lang==trans_lang:
			_translations[strkey][l] = reftxt
		elif l == trans_lang:
			_translations[strkey][l] = transtxt
		else:
			_translations[strkey][l] = ""
	
	# if the languages are the same, copy ref to trans
	if ref_lang == trans_lang:
		transtxt = reftxt
	
	# add dashboard
	add_translation_panel(strkey, reftxt, transtxt, true)
	
	# show indicator of not having saved changes
	if get_node("%LblCurrentFTitle").text.begins_with("(*)") == false:
		get_node("%LblCurrentFTitle").text = "(*)" + get_node("%LblCurrentFTitle").text
	
	get_node("%WindowDialogAddTranslationItem").hide()
	
	await get_tree().idle_frame
	get_node("%ScrollContainerTranslationsPanels").ensure_control_visible(get_viewport().gui_get_focus_owner())

func _on_BtnRemoveLang_pressed() -> void:
	
	if _langs.size() < 2:
		OS.alert("You can't remove more languages")
		return
	
	var selected_lang:String = get_node("%OptionButtonLangsToRemoveList").get_item_text(
		get_node("%OptionButtonLangsToRemoveList").selected
	)
	
	for t in _translations:
		_translations[t].erase(selected_lang)
	
	var i:int = 0
	for l in _langs:
		if l == selected_lang:
			get_node("%RefLangItemList").remove_item(i)
			get_node("%TransLangItemList").remove_item(i)
		i += 1
	
	_langs.erase(selected_lang)
	
	get_node("%RefLangItemList").selected = 0
	get_node("%TransLangItemList").selected = 0
	_on_LangItemList_item_selected(0)
	
	_on_BtnSaveFile_pressed()
	
	get_node("%WindowDialogRemoveLang").hide()

# the strkey field in the new translation popup changed
func _on_LineEditKeyStrNewTransItem_text_changed(new_text: String) -> void:
	if get_node("%CheckBoxNewSTRKeyUppercase").button_pressed == true:
		get_node("%LineEditKeyStrNewTransItem").text = get_node("%LineEditKeyStrNewTransItem").text.to_upper().replace(" ","_")
	
	get_node("%LineEditKeyStrNewTransItem").caret_column = get_node("%LineEditKeyStrNewTransItem").text.length()


func _on_CheckBoxNewSTRKeyUppercase_toggled(button_pressed: bool) -> void:
	Conf.set_value("main", "uppercase_on_input", button_pressed)
	_save_settings_config()
	
	if button_pressed == true:
		get_node("%LineEditKeyStrNewTransItem").text = get_node("%LineEditKeyStrNewTransItem").text.to_upper().replace(" ","_")
	else:
		get_node("%LineEditKeyStrNewTransItem").text = get_node("%LineEditKeyStrNewTransItem").text.to_lower().replace(" ","_")
	get_node("%LineEditKeyStrNewTransItem").caret_column = get_node("%LineEditKeyStrNewTransItem").text.length()


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
