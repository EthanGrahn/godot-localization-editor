@tool
extends HBoxContainer

signal opened(f_path)
signal removed(NodeName,f_path)

var f_path:String

func _ready() -> void:
	var full_path : String = "%s/%s" % [
		f_path.get_base_dir(),
		f_path.get_file()
	] 
	if not FileAccess.file_exists(full_path):
		$Lnk.disabled = true
	$Lnk.text = "%s" % [
		f_path.get_file()
	]
	
	$Lnk.tooltip_text = "%s%s" % [
		"[NOT FOUND] " if $Lnk.disabled else "",
		full_path
	] 


func _on_BtnRemove_pressed() -> void:
	emit_signal("removed",name, f_path)

func _on_Lnk_pressed() -> void:
	emit_signal("opened",f_path)
