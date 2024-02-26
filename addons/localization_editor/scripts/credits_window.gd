@tool
extends Popup

@export var _engine_label: Label
@export var _description_label: Label

# Called when the node enters the scene tree for the first time.
func _ready():
	
	var engine_info := Engine.get_version_info()
	_engine_label.text = "Made with Godot Engine %d.%d.%d %s" % [
		engine_info["major"],
		engine_info["minor"],
		engine_info["patch"],
		engine_info["status"],
	]
	
	var plugin_conf := ConfigFile.new()
	plugin_conf.load("res://addons/localization_editor/plugin.cfg")
	
	var plugin_name := plugin_conf.get_value("plugin", "name", "")
	self.title = "%s - Credits" % plugin_name
	_description_label.text = plugin_conf.get_value("plugin", "description", "")
