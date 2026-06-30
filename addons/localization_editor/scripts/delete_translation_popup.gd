@tool
extends ConfirmationDialog

signal delete_confirmed(remember_choice: bool)

@onready var _remember_checkbox: CheckButton = $VBoxContainer/HBoxContainer/CheckButton


func _on_confirmed() -> void:
	delete_confirmed.emit(_remember_checkbox.button_pressed)
