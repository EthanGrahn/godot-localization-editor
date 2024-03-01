@tool
extends Node

signal text_translated(id, from_lang, to_lang, original_text, translated_text)

func translate(from_lang:String, to_lang:String, text:String, callback: Callable) -> void:
	var url = _create_url(from_lang, to_lang, text)
	var http_request = HTTPRequest.new()
	http_request.timeout = 5
	add_child(http_request)
	http_request.request_completed.connect(
		_http_request_completed.bindv([http_request, callback])
	)
	http_request.request(url, [], HTTPClient.METHOD_GET)

func _create_url(from_lang:String, to_lang:String, text:String) -> String:
	var url = "https://translate.googleapis.com/translate_a/single?client=gtx"
	url += "&sl=" + from_lang
	url += "&tl=" + to_lang
	url += "&dt=t"
	url += "&q=" + text.uri_encode()
	return url

func _http_request_completed(result, response_code, headers, body, http_request, callback: Callable):
	if result != HTTPRequest.RESULT_SUCCESS:
		OS.alert(
			"ApiTranslate error #" + str(result), "HttpRequest Error"
		)
		return

	var result_body = JSON.new()
	result_body.parse(body.get_string_from_utf8())
	callback.call(result_body.get_data()[0][0][0])
	remove_child(http_request)
