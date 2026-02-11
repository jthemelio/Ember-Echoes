@icon("res://addons/godot-playfab/icon.png")

extends Node
class_name PlayFabHttp

## Emitted when a JSON parse error occurs. Will receive a JSONResult as parameter.
signal json_parse_error(json_result)

## Emitted when a PlayFab API (HTTP status code 4xx) error occurs.
signal api_error(api_error_wrapper)

## Emitted when a Server Error (HTTP status code 5xx) occurs.
signal server_error(path)

var _http: HTTPRequest
var _request_in_progress = false
var _title_id: String
var _base_uri = "playfabapi.com"
var _response_compression_enabled = true	
var _response_compression_max_output_bytes = -1 

func _ready():
	_http = HTTPRequest.new()
	add_child(_http)

func _dict_to_header_array(dict: Dictionary):
	if dict.size() < 1:
		return []

	var array = []
	for key in dict.keys():
		var value = "%s: %s" % [key, dict[key]]
		array.append(value)

	return array

func _get_api_url() -> String:
	return "https://%s.%s" % [ _title_id, _base_uri ]

func _http_request(request_method: int, body: Dictionary, path: String, callback: Callable, additional_headers: Dictionary = {}):
	var http_request = HTTPRequest.new()
	add_child(http_request)

	var json = JSON.stringify(body)
	
	# REVERTED: Restored the Content-Length header for standard SDK behavior
	var headers = [
		"Content-Type: application/json",
		"Content-Length: " + str(json.length()),
	]

	if _response_compression_enabled:
		headers.append("Accept-Encoding: gzip")

	headers.append_array(_dict_to_header_array(additional_headers))

	var request_uri = "%s%s" % [ _get_api_url(), path]
	var error = http_request.request(request_uri, headers, request_method, json)

	if error != OK:
		push_error("An error occurred in the HTTP request.")
		return

	var args = await http_request.request_completed
	http_request.queue_free()

	var response_code = args[1] as int
	var response_body = args[3] as PackedByteArray
	var response_body_string = response_body.get_string_from_utf8()
	
	var test_json_conv = JSON.new()
	var parse_error = test_json_conv.parse(response_body_string)
	var json_parse_result = test_json_conv.data

	var body_preview = response_body_string.substr(0, 200) + ("..." if response_body_string.length() > 200 else "")
	print(">> [NETWORK DEBUG] Path: ", path, " Code: ", response_code, " Length: ", response_body_string.length(), " Body: ", body_preview)

	if parse_error != OK:
		emit_signal("json_parse_error", json_parse_result)
		return
		
	if response_code >= 200 and response_code < 400:
		if callback != null:
			if callback.is_valid():
				callback.call(json_parse_result)
			else:
				push_error("Response callback is no longer valid!")
		return
	elif response_code >= 400 and response_code < 500:
		var apiErrorWrapper = ApiErrorWrapper.new()
		for key in json_parse_result.keys():
			apiErrorWrapper.set(key, json_parse_result[key])
		emit_signal("api_error", apiErrorWrapper)
		return
	elif response_code >= 500:
		emit_signal("server_error", path)
		return
