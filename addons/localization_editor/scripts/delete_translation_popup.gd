@tool
extends ConfirmationDialog

signal delete_confirmed(remember_choice: bool)

@export var _remember_checkbox: CheckButton


func _on_confirmed() -> void:
	delete_confirmed.emit(_remember_checkbox.button_pressed)
