@tool
extends RefCounted
class_name CSVLoader

static func load_csv_translation(filepath: String, conf:ConfigFile) -> Dictionary:
	
	var f_cell:String = conf.get_value("csv","f_cell","keys")
	var delimiter:String = conf.get_value("csv","delimiter",",")

	var file := FileAccess.open(filepath, FileAccess.READ)

	if file.get_open_error() != Error.OK:
		return {"TMERROR":"Can't open file: {0}, code {1}".format([filepath, file.get_open_error()])}
	
	var first_row := file.get_csv_line(delimiter)

	if first_row[0] != f_cell:
		return {"TMERROR":"Translation file is missing the `id` (f_cell) column"}
	
	var languages := PackedStringArray()
	for i in range(1, len(first_row)):
		languages.append(first_row[i])
	
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
	return translations

static func save_csv_translation(
	filepath: String, data: Dictionary, langs: Array, conf:ConfigFile
) -> int:
	
	var f_cell:String = conf.get_value("csv","f_cell","keys")
	var delimiter:String = conf.get_value("csv","delimiter",",")
	
	# csv headers are the first row
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	var csv_headers : Array = [f_cell]
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
		# get array with strkey translations [en,es,etc.]
		var str_translations : Array = data[str_key].values()
		# rowdata will have the strkey and then the other texts that would be the translations
		var row_data : Array = [str_key]
		row_data.append_array(str_translations)
		# scan data column
		file.store_csv_line(row_data, delimiter)

	return Error.OK

