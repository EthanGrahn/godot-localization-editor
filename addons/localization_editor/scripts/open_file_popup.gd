@tool
extends Popup

signal file_selected(filename: String, delimiter: String)

@export var _file_dialog: FileDialog
@export var _line_edit: LineEdit
@export var _open_button: Button
@export var _delimiter_option: OptionButton

var _selected_file: String
var _delimiter := ","


func _on_file_dialog_file_selected(path: String) -> void:
	_selected_file = path
	_line_edit.placeholder_text = ".../%s" % path.get_file()
	_line_edit.tooltip_text = path
	_open_button.disabled = false


func _on_about_to_popup() -> void:
	_selected_file = ""
	_line_edit.placeholder_text = ""
	_line_edit.tooltip_text = ""
	_open_button.disabled = true
	_delimiter = ","
	_delimiter_option.select(0)


func _on_option_button_item_selected(index: int) -> void:
	match index:
		1:
			_delimiter = ";"
		2:
			_delimiter = "	"
		_:
			_delimiter = ","


func _on_open_button_pressed():
	file_selected.emit(_selected_file, _delimiter)
	self.hide()
