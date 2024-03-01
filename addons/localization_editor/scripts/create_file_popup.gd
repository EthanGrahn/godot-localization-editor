@tool
extends Popup

signal on_new_file_created(filename: String, first_cell: String, delimiter: String)

@export var _filename_line_edit: LineEdit
@export var _filepath_line_edit: LineEdit
@export var _added_langs: TextEdit
@export var _lang_option: OptionButton
@export var _folder_dialog: FileDialog
@export var _delimiter_option: OptionButton
@export var _create_new_file_button: Button

var _first_cell := "keys"
var _delimiter := ","


func request_popup(first_cell := "keys", delimiter := ",") -> void:
	_first_cell = first_cell
	_delimiter = delimiter
	match delimiter:
		";":
			_delimiter_option.select(1)
		"	":
			_delimiter_option.select(2)
		_:
			_delimiter_option.select(0)
	self.popup_centered()


func _on_about_to_popup() -> void:
	_create_new_file_button.disabled = true
	_filename_line_edit.grab_focus()


func _on_folder_dialog_dir_selected(dir: String) -> void:
	_filepath_line_edit.text = dir


func _on_add_lang_button_pressed():
	var new_text : String
	var new_lang : String = _lang_option.get_item_text(_lang_option.selected)
	new_lang = new_lang.split(", ")[1]
	
	if new_lang in _added_langs.text:
		return

	_create_new_file_button.disabled = false
	new_text = "%s%s %s" % [
		_added_langs.text, _delimiter, new_lang
	]
	
	new_text = new_text.trim_prefix(_delimiter).strip_edges()
	
	_added_langs.text = new_text


func _on_btn_new_file_explore_path_pressed():
	_folder_dialog.popup_centered()


func _on_create_new_file_button_pressed():
	var filename : String = _filename_line_edit.text.strip_edges()
	var filepath : String = _filepath_line_edit.text
	var langs_txt : String = _added_langs.text.replace(" ","")
	var headers_list : Array = langs_txt.split(_delimiter, false)
	
	if filepath.is_empty() == true:
		OS.alert("Please choose a file path.")
		return
	
	if filename.is_empty() == true:
		OS.alert("Please enter a file name.")
		return
	
	if headers_list.size() == 0:
		headers_list.append("en") # TODO: get reference lang instead
	
	# add the first cell
	headers_list.push_front(_first_cell)
	
	var full_path: String = "%s/%s.csv" % [filepath,filename]
	var out_file = FileAccess.open(full_path, FileAccess.WRITE)
	
	if out_file.get_open_error() == Error.OK:
		out_file.store_csv_line(headers_list, _delimiter)
		out_file.close()
		
		# clean data
		_filename_line_edit.text = ""
		_filepath_line_edit.text = ""
		_added_langs.text = ""
		
		on_new_file_created.emit(full_path, _first_cell, _delimiter)
		self.hide()
	else:
		OS.alert("Error creating file. Error #"+str(out_file.get_open_error()))
		out_file.close()


func _on_delimiter_selected(index: int) -> void:
	match index:
		1:
			_delimiter = ";"
		2:
			_delimiter = "	"
		_:
			_delimiter = ","
