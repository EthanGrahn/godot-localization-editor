@tool
extends HBoxContainer

signal translate_requested(NodeName, base_text)
signal text_updated(NodeName,key_str,txt)
signal edit_requested(NodeName)
signal need_revision_check_pressed(StringKey, pressed)

var focus_on_ready : bool

var key_str : String = "ItemTranslation": set = _key_str_txt_changed
var orig_txt : String = "Original Text": set = _orig_txt_changed
var trans_txt : String = "Text Translated": set = update_trans_txt

var need_revision : bool = false
var annotations : String = ""

# flag to avoid emitting signal as soon as the object is added to the tree
var _is_ready_for_emit_signals : bool

func _ready() -> void:
	
	$VBxString1/HBoxContainer/CheckBoxRevision.button_pressed = need_revision
	
	name = key_str

	_on_CheckBoxRevision_toggled(
		$VBxString1/HBoxContainer/CheckBoxRevision.button_pressed
	)

	_on_LineEditTranslation_text_changed(trans_txt)
	
	_is_ready_for_emit_signals = true
	
	if focus_on_ready == true:
		focus_line_edit()
		get_node("%LineEditTranslation").caret_column = get_node("%LineEditTranslation").text.length()

func focus_line_edit() -> void:
	get_node("%LineEditTranslation").grab_focus()

func has_translation() -> bool:
	return ! get_node("%LineEditTranslation").text.strip_edges().is_empty()

# the orig_txt variable has changed
func _orig_txt_changed(txt:String) -> void:
	orig_txt = txt
	
	if orig_txt.is_empty() == true:
		orig_txt = "EMPTY TEXT"
	
	get_node("%LblOriginalTxt").text = orig_txt
	# disabled as it may confuse the ellipsis with translation content
	# trim large amount of text (not working)
#	if orig_txt.length() > 10:
#		get_node("%LblOriginalTxt").text.erase(0,10)
#		get_node("%LblOriginalTxt").text = get_node("%LblOriginalTxt").text + "..." 

func update_trans_txt(txt:String) -> void:
	trans_txt = txt
	get_node("%LineEditTranslation").text = trans_txt
	# hide original text if it is the same as the translation
	# also hide the translate button
#	if trans_txt == orig_txt:
#		#get_node("%LblOriginalTxt").visible = false
#		get_node("%BtnTranslate").visible = false
#	else:
#		#get_node("%LblOriginalTxt").visible = true
#		get_node("%BtnTranslate").visible = true
	
	_on_LineEditTranslation_text_changed(trans_txt, false)

func _key_str_txt_changed(txt:String) -> void:
	key_str = txt
	get_node("%LblKeyStr").text = "Identifier: " + key_str

func _on_CheckBoxRevision_toggled(button_pressed: bool) -> void:
	need_revision = button_pressed
	if need_revision == true:
		$ButtonCopyKey/MarginContainer/IconNormal.visible = false
		$ButtonCopyKey/MarginContainer/IconAlert.visible = true
	else:
		$ButtonCopyKey/MarginContainer/IconNormal.visible = true
		$ButtonCopyKey/MarginContainer/IconAlert.visible = false
	
	if _is_ready_for_emit_signals == true:
		emit_signal("need_revision_check_pressed", key_str, need_revision)


func _on_LineEditTranslation_focus_entered() -> void:
	pass
func _on_LineEditTranslation_focus_exited() -> void:
	pass

func _on_LineEditTranslation_text_changed(new_text: String, update_trans_txt: bool = true) -> void:
	
	new_text = new_text.strip_edges()
	
	if new_text.is_empty() == true:
		get_node("%LineEditTranslation").modulate = Color("ce5f5f")
		# has_translation = false
	else:
		get_node("%LineEditTranslation").modulate = Color("ffffff")
		# has_translation = true
	
	if _is_ready_for_emit_signals == true:
		emit_signal("text_updated", name, key_str, get_node("%LineEditTranslation").text)

	if update_trans_txt:
		trans_txt = new_text

func _on_BtnEdit_pressed() -> void:
	emit_signal("edit_requested", name)

func _on_BtnTranslate_pressed() -> void:
	trans_txt = "Translating: [%s] please wait..." % [orig_txt]
	get_node("%LineEditTranslation").text = trans_txt
	emit_signal("translate_requested", name, orig_txt)

func _on_ButtonCopyKey_pressed() -> void:
	DisplayServer.clipboard_set(key_str)

# enter was pressed in the text field
# send focus to the following translation line edit
func _on_LineEditTranslation_text_entered(_new_text: String) -> void:
	var next_node:Control = get_node("%LineEditTranslation").find_next_valid_focus()
	
	if next_node.name == "LineEditTranslation":
		next_node.grab_focus()
	# set cursor position to the end
	next_node.caret_column = next_node.text.length()
