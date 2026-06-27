@tool
class_name HoverButton
extends Button

@export var use_child_texture: bool = false:
	set(value):
		use_child_texture = value
		_refresh()

@export var icon_normal_color: Color = Color("#e0e0e0"):
	set(value):
		icon_normal_color = value
		_refresh()

@export var icon_hover_color: Color = Color.WHITE:
	set(value):
		icon_hover_color = value
		_refresh()

@export var icon_pressed_color: Color = Color.WHITE:
	set(value):
		icon_pressed_color = value
		_refresh()

@export var icon_disabled_color: Color = Color("#696969"):
	set(value):
		icon_disabled_color = value
		_refresh()

var _hovered := false
var _held := false
var _last_disabled := false


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW and use_child_texture and disabled != _last_disabled:
		_last_disabled = disabled
		_update_child_textures()


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	_refresh()


func _on_mouse_entered() -> void:
	_hovered = true
	_update_child_textures()


func _on_mouse_exited() -> void:
	_hovered = false
	_update_child_textures()


func _on_button_down() -> void:
	_held = true
	_update_child_textures()


func _on_button_up() -> void:
	_held = false
	_update_child_textures()


func _refresh() -> void:
	if use_child_texture:
		remove_theme_color_override("icon_normal_color")
		remove_theme_color_override("icon_hover_color")
		remove_theme_color_override("icon_pressed_color")
		remove_theme_color_override("icon_disabled_color")
		_update_child_textures()
	else:
		add_theme_color_override("icon_normal_color", icon_normal_color)
		add_theme_color_override("icon_hover_color", icon_hover_color)
		add_theme_color_override("icon_pressed_color", icon_pressed_color)
		add_theme_color_override("icon_disabled_color", icon_disabled_color)


func _update_child_textures() -> void:
	if not use_child_texture or not is_node_ready():
		return
	var color: Color
	if disabled:
		color = icon_disabled_color
	elif _held:
		color = icon_pressed_color
	elif _hovered:
		color = icon_hover_color
	else:
		color = icon_normal_color
	for child in get_children():
		if child is TextureRect:
			child.modulate = color
