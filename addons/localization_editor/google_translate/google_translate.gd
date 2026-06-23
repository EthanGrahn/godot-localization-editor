@tool
extends Node

signal text_translated(id, from_lang, to_lang, original_text, translated_text)


func translate(from_lang: String, to_lang: String, text: String, callback: Callable) -> void:
	var url = _create_url(from_lang, to_lang, text)
	var http_request = HTTPRequest.new()
	http_request.timeout = 5
	add_child(http_request)
	http_request.request_completed.connect(_http_request_completed.bindv([http_request, callback]))
	http_request.request(url, [], HTTPClient.METHOD_GET)


func _create_url(from_lang: String, to_lang: String, text: String) -> String:
	var url = "https://translate.googleapis.com/translate_a/single?client=gtx"
	url += "&sl=" + _resolve_lang_code(from_lang)
	url += "&tl=" + _resolve_lang_code(to_lang)
	url += "&dt=t"
	url += "&q=" + text.uri_encode()
	return url


func _resolve_lang_code(lang: String) -> String:
	if ", " in lang:
		return lang.split(", ")[-1]
	var locale_list = (
		load("res://addons/localization_editor/scripts/localization_locale_list.gd").new()
	)
	for entry in locale_list.LOCALES:
		if entry["name"] == lang:
			var code: String = entry["code"]
			locale_list.free()
			return code
	locale_list.free()
	return lang


func _http_request_completed(
	result, _response_code, _headers, body, http_request, callback: Callable
):
	if result != HTTPRequest.RESULT_SUCCESS:
		OS.alert("ApiTranslate error #" + str(result), "HttpRequest Error")
		remove_child(http_request)
		return

	var result_body = JSON.new()
	var parse_error = result_body.parse(body.get_string_from_utf8())
	if parse_error != OK:
		OS.alert("ApiTranslate parse error", "HttpRequest Error")
		remove_child(http_request)
		return

	var data = result_body.get_data()
	if not data is Array or data.is_empty() or not data[0] is Array:
		OS.alert("ApiTranslate unexpected response format", "HttpRequest Error")
		remove_child(http_request)
		return

	var translated := ""
	for segment in data[0]:
		if segment is Array and not segment.is_empty() and segment[0] is String:
			translated += segment[0]

	callback.call(translated)
	remove_child(http_request)
