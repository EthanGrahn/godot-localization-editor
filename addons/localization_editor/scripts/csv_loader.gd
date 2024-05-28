@tool
extends Node

func load_translations(filepath: String, delimiter: String = ",") -> Dictionary:
	var file := FileAccess.open(filepath, FileAccess.READ)
	
	if file.get_open_error() != Error.OK:
		return {
			"ERROR":"Can't open file: {0}, code {1}".format(
				[filepath, file.get_open_error()]
				)
		}
	
	var first_row := file.get_csv_line(delimiter)
	var first_cell: String = first_row[0]
	
	var languages: PackedStringArray = []
	languages.append_array(first_row.slice(1))
	
	var keys := []
	var rows := []
	var translations := {}
	var key_index := []
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line(delimiter)
		# skip empty rows
		if len(row) < 1 or row[0].strip_edges() == "":
			continue
		# resize rows that are too short
		if len(row) < len(first_row):
			row.resize(len(first_row))
		
		var key := row[0]
		translations[key] = {}
		key_index.append(key)
		for i in range(0, len(languages)):
			translations[key][languages[i]] = row[i + 1]
	file.close()
	
	# will return dictionary or empty if there are no languages or translations
	return {
		"first_cell": first_cell,
		"translations": translations,
		"key_index": key_index,
		"languages": languages,
		"has_translations": languages.size() > 0 and !translations.is_empty()
	}

func save_translations(filepath: String, data: Dictionary,
		delimiter: String = ",") -> int:
	# csv headers are the first row
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	var csv_headers : Array = [data["first_cell"]]
	csv_headers.append_array(data["languages"])

	if file.get_open_error() != Error.OK:
		OS.alert(
			"Can't open file: {0}, code {1}".format([filepath, file.get_open_error()]),
			"Translation Manager - Error"
		)
		return file.get_open_error()
	
	# insert headers as first row
	file.store_csv_line(csv_headers, delimiter)
	
	var key_index : PackedStringArray = data["key_index"]
	var languages : PackedStringArray = data["languages"]
	for i in range(0, key_index.size()):
		var key : String = key_index[i]
		var translations : Dictionary = data["translations"][key]
		# rowdata will have the key followed by all translations
		var row_data : PackedStringArray = [key]
		for lang in languages:
			if translations.has(lang):
				row_data.append(translations[lang])
			else:
				row_data.append("")
		
		file.store_csv_line(row_data, delimiter)
	
	return Error.OK

