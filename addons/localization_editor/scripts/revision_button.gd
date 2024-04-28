@tool
extends Button

@export var _texture: TextureRect
@export var _okay_texture: Texture2D
@export var _okay_color: Color
@export var _alert_texture: Texture2D
@export var _alert_color: Color

func _ready():
	_on_toggled(self.button_pressed)

func _on_toggled(button_pressed: bool) -> void:
	if button_pressed:
		_texture.texture = _alert_texture
		_texture.modulate = _alert_color
	else:
		_texture.texture = _okay_texture
		_texture.modulate = _okay_color
