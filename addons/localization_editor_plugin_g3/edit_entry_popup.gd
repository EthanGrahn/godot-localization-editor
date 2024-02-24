@tool
extends Popup

signal entry_updated(key: String, source_text: String, target_text: String, notes: String)

@export var _key_line_edit: LineEdit
@export var _source_lang_label: Label
@export var _source_lang_text: TextEdit
@export var _target_lang_label: Label
@export var _target_lang_text: TextEdit
@export var _note_text: TextEdit
@export var _difference_bar: TextureProgressBar


func request_edit(key: String, source_lang: String, target_lang: String,
source_text: String, target_text: String, notes: String) -> void:
	_key_line_edit.text = key
	_source_lang_label.text = "[%s] Original Text" % source_lang
	_target_lang_label.text = "[%s] Translation" % target_lang
	_source_lang_text.text = source_text
	_target_lang_text.text = target_text
	_note_text.text = notes
	_on_text_changed()
	self.popup_centered()


func _on_save_button_pressed():
	entry_updated.emit(
		_key_line_edit.text,
		_source_lang_text.text,
		_target_lang_text.text,
		_note_text.text
	)
	self.hide()


# the reference or target language text had changed
func _on_text_changed() -> void:
	var orig_size: int = _source_lang_text.text.length()
	var trans_size: int = _target_lang_text.text.length()
	var diff: int = orig_size - trans_size
	var diff_percent: float = float(diff) / float(orig_size)

	_difference_bar.value = abs(diff_percent)
	_difference_bar.tint_progress = Color.LIME_GREEN.lerp(Color.RED, abs(diff_percent))
	_difference_bar.tooltip_text = "%s%% difference in character count" % [int(abs(diff_percent) * float(100))]
