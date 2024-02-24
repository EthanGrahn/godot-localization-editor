@tool
extends Popup

signal on_new_file_created(filename: String)

@export var _filename_line_edit: LineEdit
@export var _filepath_line_edit: LineEdit
@export var _added_langs: TextEdit
@export var _lang_option: OptionButton
@export var _folder_dialog: FileDialog

func _on_about_to_popup() -> void:
	_filename_line_edit.grab_focus()


func _on_folder_dialog_dir_selected(dir: String) -> void:
	_filepath_line_edit.text = dir


func _on_add_lang_button_pressed():
	var delim : String = ","
	var new_text : String
	var new_lang : String = _lang_option.get_item_text(_lang_option.selected)
	new_lang = new_lang.split(", ")[1]
	
	if new_lang in _added_langs.text:
		return

	new_text = "%s%s %s" % [
		_added_langs.text, delim, new_lang
	]
	
	new_text = new_text.trim_prefix(delim).strip_edges()
	
	_added_langs.text = new_text


func _on_btn_new_file_explore_path_pressed():
	_folder_dialog.popup_centered()


func _on_create_new_file_button_pressed():
	var f_cell : String = "keys"
	var delim : String = ","
	
	var filename : String = _filename_line_edit.text.strip_edges()
	var filepath : String = _filepath_line_edit.text
	var langs_txt : String = _added_langs.text.replace(" ","")
	var headers_list : Array = langs_txt.split(delim, false)
	
	if filepath.is_empty() == true:
		OS.alert("Please choose a file path.")
		return
	
	if filename.is_empty() == true:
		OS.alert("Please enter a file name.")
		return
	
	if headers_list.size() == 0:
		headers_list.append("en") # TODO: get reference lang instead
	
	# add the fcell
	headers_list.push_front(f_cell)
	
	var full_path: String = "%s/%s.csv" % [filepath,filename]
	var out_file = FileAccess.open(full_path, FileAccess.WRITE)
	
	if out_file.get_open_error() == Error.OK:
		out_file.store_csv_line(headers_list,delim)
		out_file.close()
		
		# clean data
		_filename_line_edit.text = ""
		_filepath_line_edit.text = ""
		_added_langs.text = ""
		
		on_new_file_created.emit(full_path)
		self.hide()
	else:
		OS.alert("Error creating file. Error #"+str(out_file.get_open_error()))
		out_file.close()
