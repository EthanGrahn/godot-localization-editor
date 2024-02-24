extends Popup

signal remove_requested(language: String)

@export var _option_button: OptionButton
@export var _confirmation: ConfirmationDialog

func request_popup(langs: Array):
	_option_button.clear()
	for l in langs:
		_option_button.add_item(l)
	self.popup_centered()

func _on_remove_button_pressed():
	_confirmation.dialog_text = "Are you sure you want to remove all [%s] translations?" % _option_button.get_item_text(_option_button.selected)
	_confirmation.show()

func _on_remove_confirmed():
	remove_requested.emit(
		_option_button.get_item_text(_option_button.selected)
	)
	self.hide()
