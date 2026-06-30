@tool
extends Popup

signal remove_requested(language: String)

@onready
var _option_button: OptionButton = $MarginContainer/VBoxContainer/HBoxContainer/LangsToRemove

var _confirmation: ConfirmationDialog


func _ready():
	_confirmation = ConfirmationDialog.new()
	_confirmation.ok_button_text = "Yes"
	_confirmation.cancel_button_text = "No"
	_confirmation.dialog_autowrap = true
	_confirmation.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	add_child(_confirmation)
	_confirmation.confirmed.connect(_on_remove_confirmed)


func request_popup(langs: Array):
	_option_button.clear()
	for l in langs:
		_option_button.add_item(l)
	self.popup_centered()


func _on_remove_button_pressed():
	_confirmation.dialog_text = (
		"Are you sure you want to remove all [%s] translations?"
		% _option_button.get_item_text(_option_button.selected)
	)
	_confirmation.popup_centered()


func _on_remove_confirmed():
	remove_requested.emit(_option_button.get_item_text(_option_button.selected))
	self.hide()
