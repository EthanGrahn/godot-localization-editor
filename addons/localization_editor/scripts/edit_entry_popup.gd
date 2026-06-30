@tool
extends Popup

signal entry_updated(key: String, source_text: String, target_text: String, notes: String)

@export var _key_line_edit: LineEdit
@export var _source_lang_label: Label
@export var _source_lang_text: TextEdit
@export var _target_lang_label: Label
@export var _target_lang_text: TextEdit
@export var _note_text: TextEdit
@export var _difference_bar: TextureProgressBar


func request_edit(
	key: String,
	source_lang: String,
	target_lang: String,
	source_text: String,
	target_text: String,
	notes: String
) -> void:
	_key_line_edit.text = key
	_source_lang_label.text = "Reference [%s]" % source_lang
	_target_lang_label.text = "Target [%s]" % target_lang
	_source_lang_text.text = source_text
	_target_lang_text.text = target_text
	_note_text.text = notes
	_on_text_changed()
	self.popup_centered()


func _on_save_button_pressed():
	entry_updated.emit(
		_key_line_edit.text, _source_lang_text.text, _target_lang_text.text, _note_text.text
	)
	self.hide()


# the reference or target language text had changed
func _on_text_changed() -> void:
	var orig_width: float = _estimate_visual_width(_source_lang_text.text)
	var trans_width: float = _estimate_visual_width(_target_lang_text.text)
	var max_width: float = maxf(orig_width, trans_width)
	var diff_percent: float = (
		0.0 if max_width == 0.0 else absf(orig_width - trans_width) / max_width
	)

	_difference_bar.value = diff_percent
	_difference_bar.tint_progress = Color.LIME_GREEN.lerp(Color.RED, diff_percent)

	var diff_int := int(diff_percent * 100.0)
	if diff_int == 0:
		_difference_bar.tooltip_text = "Target is the same visual width as the reference"
	elif trans_width > orig_width:
		_difference_bar.tooltip_text = "%s%% wider than reference" % diff_int
	else:
		_difference_bar.tooltip_text = "%s%% narrower than reference" % diff_int


func _estimate_visual_width(text: String) -> float:
	const NARROW := "iIl1j|!.,;: \t"
	const WIDE := "mwMW%@"
	var width := 0.0
	for i in text.length():
		var cp := text.unicode_at(i)
		if _is_zero_width(cp):
			pass
		elif _is_wide_script(cp):
			width += 1.7
		elif _is_rtl_script(cp):
			width += 0.85
		elif text[i] in NARROW:
			width += 0.5
		elif text[i] in WIDE:
			width += 1.5
		else:
			width += 1.0
	return width


# Combining diacritics and zero-width control characters add no horizontal space.
func _is_zero_width(cp: int) -> bool:
	return (
		(cp >= 0x0300 and cp <= 0x036F)  # Combining Diacritical Marks
		or (cp >= 0x0610 and cp <= 0x061A)  # Arabic extended combining marks
		or (cp >= 0x064B and cp <= 0x065F)  # Arabic vowel marks (harakat)
		or (cp >= 0x0591 and cp <= 0x05C7)  # Hebrew points / cantillation marks
		or (cp >= 0x1AB0 and cp <= 0x1AFF)  # Combining Diacritical Marks Extended
		or (cp >= 0x1DC0 and cp <= 0x1DFF)  # Combining Diacritical Marks Supplement
		or (cp >= 0x20D0 and cp <= 0x20FF)  # Combining Diacritical Marks for Symbols
		or cp == 0x200B  # Zero-width space
		or cp == 0x200C  # Zero-width non-joiner
		or cp == 0x200D  # Zero-width joiner
		or cp == 0x00AD  # Soft hyphen
		or cp == 0xFEFF
	)  # Zero-width no-break space (BOM)


# Arabic and Hebrew use contextual shaping and ligatures, so raw character count
# consistently overestimates their rendered width.
func _is_rtl_script(cp: int) -> bool:
	return (
		(cp >= 0x0600 and cp <= 0x06FF)  # Arabic
		or (cp >= 0x0750 and cp <= 0x077F)  # Arabic Supplement
		or (cp >= 0x08A0 and cp <= 0x08FF)  # Arabic Extended-A
		or (cp >= 0xFB50 and cp <= 0xFDFF)  # Arabic Presentation Forms-A
		or (cp >= 0xFE70 and cp <= 0xFEFF)  # Arabic Presentation Forms-B
		or (cp >= 0x0590 and cp <= 0x05FF)  # Hebrew
		or (cp >= 0xFB00 and cp <= 0xFB4F)
	)  # Hebrew Presentation Forms


# Wide scripts that render at roughly 1.7× the width of a Latin letter.
# Covers CJK ideographs, Hiragana, Katakana, Hangul, full-width forms, and emoji.
func _is_wide_script(cp: int) -> bool:
	return (
		(cp >= 0x1100 and cp <= 0x11FF)  # Hangul Jamo
		or (cp >= 0x2E80 and cp <= 0x303F)  # CJK Radicals / Symbols
		or (cp >= 0x3040 and cp <= 0x33FF)  # Hiragana, Katakana, Bopomofo, Hangul Compat, CJK Compat
		or (cp >= 0x3400 and cp <= 0x4DBF)  # CJK Extension A
		or (cp >= 0x4E00 and cp <= 0x9FFF)  # CJK Unified Ideographs
		or (cp >= 0xA000 and cp <= 0xA4CF)  # Yi Syllables / Radicals
		or (cp >= 0xAC00 and cp <= 0xD7AF)  # Hangul Syllables
		or (cp >= 0xF900 and cp <= 0xFAFF)  # CJK Compatibility Ideographs
		or (cp >= 0xFE10 and cp <= 0xFE6F)  # Vertical / Small / CJK Compat Forms
		or (cp >= 0xFF01 and cp <= 0xFF60)  # Fullwidth Latin / ASCII
		or (cp >= 0xFFE0 and cp <= 0xFFE6)  # Fullwidth Signs
		or (cp >= 0x1B000 and cp <= 0x1B0FF)  # Kana Supplement
		or (cp >= 0x1F200 and cp <= 0x1F2FF)  # Enclosed Ideographic Supplement
		or (cp >= 0x1F300 and cp <= 0x1FAFF)  # Emoji (symbols, pictographs, etc.)
		or (cp >= 0x20000 and cp <= 0x2FA1F)
	)  # CJK Extensions B–F + Compat Supplement
