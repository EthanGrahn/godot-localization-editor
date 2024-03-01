@tool
extends Control

signal opened(filename: String)
signal removed(filename: String)

@export var _link: LinkButton
@export var _delete_button: Button

var filename: String

func _ready() -> void:
	_link.disabled = not FileAccess.file_exists(filename)
	_link.text = filename.get_file()
	
	_link.tooltip_text = "%s%s" % [
		"[NOT FOUND] " if _link.disabled else "",
		filename
	]


func _on_remove_pressed():
	removed.emit(filename)
	self.queue_free()


func _on_link_pressed():
	opened.emit(filename)
