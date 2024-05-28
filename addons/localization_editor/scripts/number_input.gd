extends LineEdit

signal text_ready(line_edit: LineEdit, new_text: String)

var _regex = RegEx.new()
var _prev_text: String
var _prev_column: int
var _pre_focus_text: String

func _ready():
	_pre_focus_text = self.text
	_prev_text = self.text
	_prev_column = self.text.length() - 1
	_regex.compile("[^0-9]")

func _process(delta) -> void:
	if self.has_focus() && Input.is_key_pressed(KEY_ESCAPE):
		self.text = _pre_focus_text
		self.release_focus()

func _on_text_changed(new_text: String) -> void:
	var curr_column := self.caret_column
	self.text = _regex.sub(self.text, "", true)
	if _prev_text == self.text:
		self.caret_column = _prev_column
	else:
		self.caret_column = curr_column
	_prev_column = self.caret_column
	_prev_text = self.text

func _on_text_submitted(new_text: String) -> void:
	self.release_focus()

func _on_focus_exited():
	_pre_focus_text = self.text
	text_ready.emit(self, self.text)

func _on_focus_entered():
	_pre_focus_text = self.text
