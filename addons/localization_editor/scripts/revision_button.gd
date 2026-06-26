@tool
extends Button

@export var _texture: TextureRect
@export var _okay_texture: Texture2D
@export var _alert_texture: Texture2D


func _ready():
	_on_toggled(self.button_pressed)


func _on_toggled(button_pressed: bool) -> void:
	if button_pressed:
		_texture.texture = _alert_texture
	else:
		_texture.texture = _okay_texture
