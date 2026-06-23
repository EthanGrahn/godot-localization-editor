@tool
extends Node

signal entry_updated(new_data: Dictionary)
signal entry_added(new_data: Dictionary)
signal entry_deleted(key: String)
signal list_ready

@export var _translation_entry_scene: PackedScene
@export var _reference_lang_option: OptionButton
@export var _translated_lang_option: OptionButton

@onready var _config_manager: Node = get_tree().root.find_child("ConfigManager", true, false)

const _GOOGLE_TRANSLATE_PATH: String = (
	"res://addons/localization_editor/google_translate/google_translate.tscn"
)
const _BUFFER: int = 5
const _ESTIMATED_HEIGHT: float = 100.0

var _google_translate: Node

# Ordered array of all entry data. Index in this array = the entry's data_index.
# Each element: { key, translations, notes, needs_revision, [old_key] }
var _data_store: Array = []

# Deep copy of _data_store as it was when the file was last loaded or saved.
# Used to compute the delta for the temp file.
var _baseline_store: Array = []

# Indices into _data_store that pass the current search filter, in visual order.
var _filtered_indices: Array = []

# Range of _filtered_indices currently instantiated as nodes: [_loaded_start, _loaded_end).
var _loaded_start: int = 0
var _loaded_end: int = 0

var _entry_height: float = _ESTIMATED_HEIGHT
var _top_spacer: Control
var _bottom_spacer: Control
var _scroll_container: ScrollContainer

var _ref_lang: String = ""
var _target_lang: String = ""
var _search_text: String = ""
var _search_filters: Dictionary = {}
var _key_counts: Dictionary = {}


func _ready() -> void:
	_top_spacer = Control.new()
	_bottom_spacer = Control.new()
	add_child(_top_spacer)
	add_child(_bottom_spacer)

	_scroll_container = get_parent() as ScrollContainer
	if _scroll_container:
		_scroll_container.get_v_scroll_bar().value_changed.connect(_on_scroll_changed)

	if ResourceLoader.exists(_GOOGLE_TRANSLATE_PATH) and _google_translate == null:
		_google_translate = load(_GOOGLE_TRANSLATE_PATH).instantiate()
		var target := owner if is_instance_valid(owner) else self
		target.add_child.call_deferred(_google_translate)


func init_list(translation_data: Dictionary) -> void:
	_data_store = []
	_filtered_indices = []
	_loaded_start = 0
	_loaded_end = 0

	for child in get_children():
		if child.has_method("remove"):
			child.remove(true)

	# wait a frame for entries to be removed
	await get_tree().process_frame

	var cfg := _config_manager if is_instance_valid(_config_manager) else null
	for key in translation_data:
		(
			_data_store
			. append(
				{
					"key": key,
					"translations": translation_data[key],
					"notes": cfg.get_key_value(key, "notes", "") if cfg else "",
					"needs_revision":
					cfg.get_key_value(key, "needs_revision", false) if cfg else false,
				}
			)
		)

	_baseline_store = []
	for d in _data_store:
		_baseline_store.append(d.duplicate(true))

	_ref_lang = _reference_lang_option.get_item_text(_reference_lang_option.selected)
	_target_lang = _translated_lang_option.get_item_text(_translated_lang_option.selected)

	_rebuild_filtered_indices()
	_rebuild_key_counts()
	if _scroll_container:
		_scroll_container.scroll_vertical = 0

	var initial_count: int = mini(
		_BUFFER * 2 + int(_get_viewport_height() / _entry_height) + 1, _filtered_indices.size()
	)
	_load_range(0, initial_count)
	_update_spacers()

	# wait a frame for entries to be loaded
	await get_tree().process_frame
	_measure_entry_height()
	list_ready.emit()


func update_reference_language(new_lang: String) -> void:
	_ref_lang = new_lang
	for i in range(1, get_child_count() - 1):
		get_child(i).update_reference_language(new_lang)


func update_target_language(new_lang: String) -> void:
	_target_lang = new_lang
	for i in range(1, get_child_count() - 1):
		get_child(i).update_target_language(new_lang)


func add_entry(key: String, ref_text: String, target_text: String) -> void:
	var translations: Dictionary = {_ref_lang: ref_text, _target_lang: target_text}
	var d_idx: int = _data_store.size()
	var new_data: Dictionary = {
		"key": key,
		"translations": translations,
		"notes": "",
		"needs_revision": false,
	}
	_data_store.append(new_data)
	_key_counts[key] = _key_counts.get(key, 0) + 1
	if _key_counts[key] == 2:
		_refresh_key_status(key)

	var emit_data := new_data.duplicate()
	emit_data["index"] = d_idx

	if _passes_filter(new_data):
		var f_idx: int = _filtered_indices.size()
		_filtered_indices.append(d_idx)
		_spawn_at_bottom(f_idx)
		_loaded_end += 1
		_update_spacers()

	entry_added.emit(emit_data)


func search(search_text: String, filters: Dictionary) -> void:
	_sync_all_visible_to_store()
	_search_text = search_text.strip_edges().to_lower()
	_search_filters = filters

	for child in get_children():
		if child.has_method("remove"):
			child.remove(true)

	_loaded_start = 0
	_loaded_end = 0
	_rebuild_filtered_indices()

	var scroll_y: float = _scroll_container.scroll_vertical if _scroll_container else 0.0
	var first: int = max(0, int(scroll_y / _entry_height) - _BUFFER)
	var last: int = mini(
		_filtered_indices.size(),
		int((scroll_y + _get_viewport_height()) / _entry_height) + _BUFFER + 1
	)
	_load_range(first, last)
	_update_spacers()


func clear_list() -> void:
	for child in get_children():
		if child.has_method("remove"):
			child.remove(true)
	_data_store = []
	_filtered_indices = []
	_key_counts = {}
	_loaded_start = 0
	_loaded_end = 0
	_update_spacers()


# Syncs all visible nodes to _data_store, rebuilds out_key_index from _data_store,
# and propagates any pending key renames and text changes into out_translations.
func flush(
	ref_lang: String, target_lang: String, out_translations: Dictionary, out_key_index: Array
) -> void:
	_sync_all_visible_to_store()

	out_key_index.clear()
	for d in _data_store:
		var old_key: String = d.get("old_key", d["key"])
		if old_key != d["key"] and out_translations.has(old_key):
			out_translations[d["key"]] = out_translations[old_key].duplicate(true)
			out_translations.erase(old_key)
		d.erase("old_key")
		var k: String = d["key"]
		if out_translations.has(k):
			out_translations[k][target_lang] = d["translations"].get(target_lang, "")
			out_translations[k][ref_lang] = d["translations"].get(ref_lang, "")
		out_key_index.append(k)
		if is_instance_valid(_config_manager):
			_config_manager.write_key_metadata(
				k, d.get("notes", ""), d.get("needs_revision", false)
			)
	if is_instance_valid(_config_manager):
		_config_manager.save_directory_config()


# ── Internal helpers ──────────────────────────────────────────────────────────


func _load_range(start: int, end_exclusive: int) -> void:
	_loaded_start = start
	_loaded_end = start
	for f_idx in range(start, end_exclusive):
		_spawn_at_bottom(f_idx)
		_loaded_end += 1


func _rebuild_filtered_indices() -> void:
	_filtered_indices = []
	for i in range(_data_store.size()):
		if _passes_filter(_data_store[i]):
			_filtered_indices.append(i)


func _passes_filter(data: Dictionary) -> bool:
	if _search_filters.is_empty() and _search_text.is_empty():
		return true

	var hide_translated: bool = _search_filters.get("need_translation", false)
	var hide_no_need_rev: bool = _search_filters.get("need_revision", false)

	if hide_translated and not data["translations"].get(_target_lang, "").is_empty():
		return false
	if hide_no_need_rev and not data.get("needs_revision", false):
		return false

	if not _search_text.is_empty():
		var search_key: bool = _search_filters.get("search_key", true)
		var search_ref: bool = _search_filters.get("search_ref_text", true)
		var search_target: bool = _search_filters.get("search_target_text", true)

		var key_match: bool = search_key and _search_text in data["key"].to_lower()
		var ref_match: bool = (
			search_ref and _search_text in data["translations"].get(_ref_lang, "").to_lower()
		)
		var target_match: bool = (
			search_target and _search_text in data["translations"].get(_target_lang, "").to_lower()
		)

		return key_match or ref_match or target_match

	return true


func _on_scroll_changed(_value: float) -> void:
	if _scroll_container:
		_update_visible_range(_scroll_container.scroll_vertical)


func _update_visible_range(scroll_y: float) -> void:
	if _filtered_indices.is_empty():
		return

	var viewport_h: float = _get_viewport_height()
	var first_needed: int = max(0, int(scroll_y / _entry_height) - _BUFFER)
	var last_needed: int = mini(
		_filtered_indices.size(), int((scroll_y + viewport_h) / _entry_height) + _BUFFER + 1
	)

	if first_needed == _loaded_start and last_needed == _loaded_end:
		return

	while _loaded_start < first_needed and _loaded_start < _loaded_end:
		_despawn_top()
	while _loaded_end > last_needed and _loaded_end > _loaded_start:
		_despawn_bottom()
	while _loaded_start > first_needed:
		_loaded_start -= 1
		_spawn_at_top(_loaded_start)
	while _loaded_end < last_needed:
		_spawn_at_bottom(_loaded_end)
		_loaded_end += 1

	_update_spacers()
	_measure_entry_height()


func _spawn_at_top(f_idx: int) -> void:
	var entry = _create_entry(f_idx)
	add_child(entry)
	move_child(entry, 1)  # after top_spacer
	entry.set_init_complete()


func _spawn_at_bottom(f_idx: int) -> void:
	var entry = _create_entry(f_idx)
	add_child(entry)
	move_child(entry, get_child_count() - 2)  # before bottom_spacer
	entry.set_init_complete()


func _create_entry(f_idx: int) -> Node:
	var d_idx: int = _filtered_indices[f_idx]
	var data: Dictionary = _data_store[d_idx]
	var entry = _translation_entry_scene.instantiate()

	if _google_translate != null:
		entry.translation_requested.connect(_on_translate_requested)
	entry.data_changed.connect(_on_entry_data_changed)
	entry.removed.connect(_on_entry_deleted)
	entry.reorder_requested.connect(func(dir: int): _handle_reorder(entry, dir))

	entry.set_translation_data(
		data["key"],
		_ref_lang,
		_target_lang,
		data["translations"],
		data.get("notes", ""),
		data.get("needs_revision", false),
		d_idx,
		false,
		_google_translate != null
	)
	entry.set_position_metadata(d_idx, f_idx, _filtered_indices.size())
	var k: String = data["key"]
	entry.set_key_status(k.is_empty(), _key_counts.get(k, 0))
	return entry


func _despawn_top() -> void:
	if get_child_count() <= 2:
		return
	var entry = get_child(1)
	_sync_node_to_store(entry, _filtered_indices[_loaded_start])
	entry.remove(true)
	_loaded_start += 1


func _despawn_bottom() -> void:
	if get_child_count() <= 2:
		return
	var entry = get_child(get_child_count() - 2)
	_sync_node_to_store(entry, _filtered_indices[_loaded_end - 1])
	entry.remove(true)
	_loaded_end -= 1


func _sync_node_to_store(entry: Node, d_idx: int) -> void:
	if d_idx < 0 or d_idx >= _data_store.size():
		return
	var d: Dictionary = _data_store[d_idx]
	var trans = entry.get_translation_data()
	d["key"] = trans["key"]
	d["translations"][_target_lang] = trans["target_text"]
	d["translations"][_ref_lang] = trans["ref_text"]
	d["notes"] = entry._entry_data.get("notes", d["notes"])
	d["needs_revision"] = entry._entry_data.get("needs_revision", d["needs_revision"])
	if trans["old_key"] != trans["key"]:
		d["old_key"] = trans["old_key"]


func _sync_all_visible_to_store() -> void:
	for i in range(1, get_child_count() - 1):
		var node = get_child(i)
		var f_idx: int = _loaded_start + i - 1
		if f_idx < _filtered_indices.size():
			_sync_node_to_store(node, _filtered_indices[f_idx])


func _update_spacers() -> void:
	if not is_instance_valid(_top_spacer) or not is_instance_valid(_bottom_spacer):
		return
	_top_spacer.custom_minimum_size.y = _loaded_start * _entry_height
	_bottom_spacer.custom_minimum_size.y = (
		max(0, _filtered_indices.size() - _loaded_end) * _entry_height
	)


func _measure_entry_height() -> void:
	if get_child_count() <= 2:
		return
	var sample = get_child(1)
	if is_instance_valid(sample) and sample.size.y > 1.0:
		var h: float = sample.size.y
		if abs(h - _entry_height) > 5.0:
			_entry_height = h
			_update_spacers()


func _get_viewport_height() -> float:
	if _scroll_container and _scroll_container.size.y > 1.0:
		return _scroll_container.size.y
	return 600.0


func _handle_reorder(entry: Node, direction: int) -> void:
	if not is_instance_valid(entry):
		return

	var f_idx: int = entry.filter_index
	var target_f_idx: int = f_idx + direction

	if target_f_idx < 0 or target_f_idx >= _filtered_indices.size():
		return

	var d_idx_a: int = _filtered_indices[f_idx]
	var d_idx_b: int = _filtered_indices[target_f_idx]

	# Swap data in store (positions d_idx_a and d_idx_b exchange content)
	var temp_data = _data_store[d_idx_a]
	_data_store[d_idx_a] = _data_store[d_idx_b]
	_data_store[d_idx_b] = temp_data

	var target_is_loaded: bool = target_f_idx >= _loaded_start and target_f_idx < _loaded_end

	if target_is_loaded:
		var target_child_idx: int = target_f_idx - _loaded_start + 1
		var target_entry: Node = get_child(target_child_idx)

		# Swap nodes in VBoxContainer; target_entry is fetched before the move.
		move_child(entry, target_child_idx)

		entry.update_display_index(d_idx_b, target_f_idx, _filtered_indices.size())
		target_entry.update_display_index(d_idx_a, f_idx, _filtered_indices.size())
	else:
		# The swap partner is off-screen - sync current entry and refresh.
		_sync_node_to_store(entry, d_idx_b)
		entry.update_display_index(d_idx_b, target_f_idx, _filtered_indices.size())
		_update_visible_range(_scroll_container.scroll_vertical if _scroll_container else 0.0)


func get_key_issue_counts() -> Dictionary:
	var empty_count: int = _key_counts.get("", 0)
	var duplicate_count: int = 0
	for key in _key_counts:
		if not key.is_empty() and _key_counts[key] > 1:
			duplicate_count += _key_counts[key]
	return {"empty": empty_count, "duplicates": duplicate_count}


func get_store_delta() -> Dictionary:
	_sync_all_visible_to_store()

	var baseline_by_key: Dictionary = {}
	for entry in _baseline_store:
		baseline_by_key[entry["key"]] = entry

	var order: Array = []
	var changes: Dictionary = {}
	var added: Dictionary = {}
	var deleted: Array = []

	var current_orig_keys: Dictionary = {}
	for d in _data_store:
		var orig_key: String = d.get("old_key", d["key"])
		current_orig_keys[orig_key] = d
		order.append(d["key"])

	for key in baseline_by_key:
		if not current_orig_keys.has(key):
			deleted.append(key)

	for orig_key in current_orig_keys:
		var current: Dictionary = current_orig_keys[orig_key]
		if not baseline_by_key.has(orig_key):
			added[current["key"]] = {
				"translations": current["translations"].duplicate(true),
				"notes": current.get("notes", ""),
				"needs_revision": current.get("needs_revision", false),
			}
		else:
			var baseline: Dictionary = baseline_by_key[orig_key]
			var diff: Dictionary = {}

			if current["key"] != orig_key:
				diff["key"] = current["key"]

			var cur_trans: Dictionary = current["translations"]
			var base_trans: Dictionary = baseline["translations"]
			var trans_diff: Dictionary = {}
			for lang in cur_trans:
				if cur_trans[lang] != base_trans.get(lang, ""):
					trans_diff[lang] = cur_trans[lang]
			if not trans_diff.is_empty():
				diff["translations"] = trans_diff

			if current.get("notes", "") != baseline.get("notes", ""):
				diff["notes"] = current.get("notes", "")

			if current.get("needs_revision", false) != baseline.get("needs_revision", false):
				diff["needs_revision"] = current.get("needs_revision", false)

			if not diff.is_empty():
				changes[orig_key] = diff

	var baseline_order: Array = []
	for entry in _baseline_store:
		baseline_order.append(entry["key"])
	var order_changed: bool = order != baseline_order

	if changes.is_empty() and added.is_empty() and deleted.is_empty() and not order_changed:
		return {}

	var result: Dictionary = {"order": order}
	if not changes.is_empty():
		result["changes"] = changes
	if not added.is_empty():
		result["added"] = added
	if not deleted.is_empty():
		result["deleted"] = deleted
	return result


func apply_delta(delta: Dictionary) -> void:
	if delta.is_empty():
		return
	var store_by_key: Dictionary = {}
	for d in _data_store:
		store_by_key[d["key"]] = d

	for del_key in delta.get("deleted", []):
		for i in range(_data_store.size() - 1, -1, -1):
			if _data_store[i]["key"] == del_key:
				_data_store.remove_at(i)
				store_by_key.erase(del_key)
				break

	for orig_key in delta.get("changes", {}):
		var diff: Dictionary = delta["changes"][orig_key]
		var entry: Dictionary = store_by_key.get(orig_key, {})
		if entry.is_empty():
			continue
		if diff.has("key"):
			store_by_key.erase(orig_key)
			entry["old_key"] = orig_key
			entry["key"] = diff["key"]
			store_by_key[diff["key"]] = entry
		if diff.has("translations"):
			for lang in diff["translations"]:
				entry["translations"][lang] = diff["translations"][lang]
		if diff.has("notes"):
			entry["notes"] = diff["notes"]
		if diff.has("needs_revision"):
			entry["needs_revision"] = diff["needs_revision"]

	for new_key in delta.get("added", {}):
		var add_data: Dictionary = delta["added"][new_key]
		var new_entry := {
			"key": new_key,
			"translations": add_data.get("translations", {}),
			"notes": add_data.get("notes", ""),
			"needs_revision": add_data.get("needs_revision", false),
		}
		_data_store.append(new_entry)
		store_by_key[new_key] = new_entry

	var order: Array = delta.get("order", [])
	if not order.is_empty():
		var ordered: Array = []
		for key in order:
			if store_by_key.has(key):
				ordered.append(store_by_key[key])
		for d in _data_store:
			if not order.has(d["key"]):
				ordered.append(d)
		_data_store = ordered

	for child in get_children():
		if child.has_method("remove"):
			child.remove(true)

	await get_tree().process_frame

	_loaded_start = 0
	_loaded_end = 0
	_rebuild_filtered_indices()
	_rebuild_key_counts()

	if _scroll_container:
		_scroll_container.scroll_vertical = 0

	var initial_count: int = mini(
		_BUFFER * 2 + int(_get_viewport_height() / _entry_height) + 1, _filtered_indices.size()
	)
	_load_range(0, initial_count)
	_update_spacers()

	await get_tree().process_frame
	_measure_entry_height()


func reset_baseline() -> void:
	_baseline_store = []
	for d in _data_store:
		_baseline_store.append(d.duplicate(true))


func get_current_translations() -> Dictionary:
	var result: Dictionary = {}
	for d in _data_store:
		result[d["key"]] = d["translations"]
	return result


func get_key_order() -> Array:
	var result: Array = []
	for d in _data_store:
		result.append(d["key"])
	return result


func _rebuild_key_counts() -> void:
	_key_counts = {}
	for d in _data_store:
		var k: String = d["key"]
		_key_counts[k] = _key_counts.get(k, 0) + 1


func _refresh_key_status(key: String) -> void:
	var count: int = _key_counts.get(key, 0)
	for i in range(1, get_child_count() - 1):
		var node = get_child(i)
		if is_instance_valid(node) and node.key == key:
			node.set_key_status(key.is_empty(), count)


func _on_entry_data_changed(new_data: Dictionary) -> void:
	var d_idx: int = new_data.get("index", -1)
	if d_idx >= 0 and d_idx < _data_store.size():
		var old_key: String = _data_store[d_idx]["key"]
		var new_key: String = new_data["key"]
		_data_store[d_idx]["key"] = new_key
		if new_data.has("translations"):
			_data_store[d_idx]["translations"] = new_data["translations"].duplicate()
		if new_data.has("needs_revision"):
			_data_store[d_idx]["needs_revision"] = new_data["needs_revision"]
		if new_data.has("notes"):
			_data_store[d_idx]["notes"] = new_data["notes"]
		if old_key != new_key:
			_key_counts[old_key] = _key_counts.get(old_key, 1) - 1
			if _key_counts[old_key] <= 0:
				_key_counts.erase(old_key)
			_key_counts[new_key] = _key_counts.get(new_key, 0) + 1
			_refresh_key_status(old_key)
			_refresh_key_status(new_key)
	entry_updated.emit(new_data)


func _on_entry_deleted(key: String) -> void:
	# Locate the deleted entry in the data store.
	var d_idx: int = -1
	for i in range(_data_store.size()):
		if _data_store[i]["key"] == key:
			d_idx = i
			break
	if d_idx == -1:
		entry_deleted.emit(key)
		return

	# Find the entry's position in the filtered list (may be -1 if filtered out).
	var f_idx: int = _filtered_indices.find(d_idx)

	_data_store.remove_at(d_idx)
	_key_counts[key] = _key_counts.get(key, 1) - 1
	if _key_counts[key] <= 0:
		_key_counts.erase(key)

	# Remove from filtered_indices and shift all values above d_idx down by 1.
	if f_idx != -1:
		_filtered_indices.remove_at(f_idx)
	for i in range(_filtered_indices.size()):
		if _filtered_indices[i] > d_idx:
			_filtered_indices[i] -= 1

	# Adjust loaded range bounds.
	if f_idx != -1:
		if f_idx < _loaded_start:
			_loaded_start -= 1
			_loaded_end -= 1
		elif f_idx < _loaded_end:
			_loaded_end -= 1

	# Update position metadata on remaining visible nodes without emitting signals.
	for i in range(1, get_child_count() - 1):
		var node = get_child(i)
		if not is_instance_valid(node) or node.key == key:
			continue
		var new_d_idx: int = node.data_index - 1 if node.data_index > d_idx else node.data_index
		var new_f_idx: int = (
			node.filter_index - 1
			if (f_idx != -1 and node.filter_index > f_idx)
			else node.filter_index
		)
		node.set_position_metadata(new_d_idx, new_f_idx, _filtered_indices.size())

	_refresh_key_status(key)
	_update_spacers()
	entry_deleted.emit(key)


func _on_translate_requested(
	source_lang: String, source_text: String, target_lang: String, callback: Callable
) -> void:
	if _google_translate != null:
		_google_translate.translate(source_lang, target_lang, source_text, callback)
