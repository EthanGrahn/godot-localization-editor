@tool
extends RefCounted
class_name CSVLoader

static func load_csv_translation(filepath: String, delimiter: String = ",") -> Dictionary:
	var file := FileAccess.open(filepath, FileAccess.READ)

	if file.get_open_error() != Error.OK:
		return {"TMERROR":"Can't open file: {0}, code {1}".format([filepath, file.get_open_error()])}
	
	var first_row := file.get_csv_line(delimiter)
	var first_cell: String = first_row[0]
	
	var languages: PackedStringArray = []
	languages.append_array(first_row.slice(1))
	
	var ids := []
	var rows := []
	while not file.eof_reached():
		var row := file.get_csv_line(delimiter)
		if len(row) < 1 or row[0].strip_edges() == "":
			#print_debug("Found an empty row")
			continue
		if len(row) < len(first_row):
			#print_debug("Found row smaller than header, resizing")
			row.resize(len(first_row))
		ids.append(row[0])
		var trans = PackedStringArray()
		for i in range(1, len(row)):
			trans.append(row[i])
		rows.append(trans)
	file.close()
	
	var translations := {}
	for i in len(ids):
		var t := {}
		for language_index in len(rows[i]):
			t[languages[language_index]] = rows[i][language_index]
		translations[ids[i]] = t

	# if the file contains only the languages but has no translations,
	# return only the list of languages
	if (
		languages.size() > 0 and translations.is_empty() == true
	):
		return {"EMPTYTRANSLATIONS":languages}
	
	# will return dictionary or empty if there are no languages or translations
	return {"first_cell": first_cell, "translations": translations}

static func save_csv_translation(filepath: String, data: Dictionary,
langs: Array, first_cell: String = "keys", delimiter: String = ",") -> int:
	# csv headers are the first row
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	var csv_headers : Array = [first_cell]
	csv_headers.append_array(langs)

	if file.get_open_error() != Error.OK:
		OS.alert(
			"Can't open file: {0}, code {1}".format([filepath, file.get_open_error()]),
			"Translation Manager - Error"
		)
		return file.get_open_error()
	
	# insert headers as first row
	file.store_csv_line(csv_headers, delimiter)
	
	# scan data row
	for str_key in data.keys():
		# rowdata will have the strkey followed by all translations
		var row_data : Array = [str_key]
		# make sure we are storing the languages in correct order
		for lang in langs:
			row_data.append(data[str_key][lang])
		
		file.store_csv_line(row_data, delimiter)

	return Error.OK

