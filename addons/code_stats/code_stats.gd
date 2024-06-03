@tool
extends EditorPlugin

const CODESTATS_ACCESS_TOKEN=""
var http: HTTPRequest
var timer: Timer
var verbose: bool = false
var regex = RegEx.new()
var inputsCount = 0

func _enter_tree():
	regex.compile("^([A-z]?|Backspace|Ctrl\\+X|Ctrl\\+V)$")

	var editor = get_editor_interface()
	if editor == null:
		push_error("Failed to attach code_stats script to editor! Please try to disable and reenable the plugin.")
		return

	var script_editor = editor.get_script_editor()
	if script_editor == null:
		push_error("Failed to attach code_stats script to editor! Please try to disable and reenable the plugin.")
		return
		
	script_editor.editor_script_changed.connect(_attachStatsCollector)
	
	for open_editor in script_editor.get_open_script_editors():
		if open_editor.has_signal("editor_input"):
			if !open_editor.is_connected("editor_input", _handleInputs):
				open_editor.connect("editor_input", _handleInputs)

	http = HTTPRequest.new()
	add_child(http)	
	http.request_completed.connect(_on_request_completed)
	http.use_threads = true

	timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(_submitInputs)
	timer.start(10)

	print("Code::Stats addon is now active!")

func _exit_tree():
	pass

func _handleInputs(input):
	if verbose:
		print("Code::Stats: Input: %s" % input)
	var matches = regex.search(input)
	if matches: 
		if verbose:
			print("Counted")
		inputsCount += 1

func _submitInputs():
	print("Code::Stats: Sending %d xp" % inputsCount)
	if inputsCount == 0:
		return

	var headers = [
		"User-Agent: CodeStats/1.0 (Godot)",
		"Accept: */*",
		"Content-Type: application/json",
		"X-API-Token: " + CODESTATS_ACCESS_TOKEN
	]
	
	var local_time = Time.get_datetime_dict_from_system();
	var utc_time = Time.get_datetime_dict_from_system(true);
	
	var diff_minutes = (local_time.hour - utc_time.hour) * 60
	var hour_offset = Time.get_offset_string_from_offset_minutes(diff_minutes)
	
	var body = JSON.stringify({
		"coded_at": Time.get_datetime_string_from_datetime_dict(local_time, false) + hour_offset,
		"xps": [
			{"language": "gdscript", "xp": inputsCount}
		]
	})
	if verbose:
		print("Payload: %s" % body)
	http.request("https://codestats.net/api/my/pulses", headers, HTTPClient.METHOD_POST, body)
	inputsCount = 0

func _on_request_completed(result, response_code, headers, body):
	if verbose:
		print("Response Result: ", result)
		print("Response Code: ", response_code)
		print("Response Headers: ", headers)
		print("Response Body: ", body)

func _attachStatsCollector(script: Script):
	var editor = get_editor_interface()
	if editor == null:
		return

	var script_editor = editor.get_script_editor()
	if script_editor == null:
		return

	for open_editor in script_editor.get_open_script_editors():
		if open_editor.has_signal("editor_input"):
			if !open_editor.is_connected("editor_input", _handleInputs):
				open_editor.connect("editor_input", _handleInputs)
