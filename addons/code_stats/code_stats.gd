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
		
	var current_editor = script_editor.get_current_editor()
	if current_editor == null:
		push_error("Failed to attach code_stats script to editor! Please try to disable and reenable the plugin.")
		return
	
	if !current_editor.has_signal("editor_input"):
		push_error("Your Godot Engine build does not have the 'editor_input' event. This plugin will not work without!")
		return

	current_editor.connect("editor_input", _handleInputs)

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
		print("Input: %s" % input)
	var matches = regex.search(input)
	if matches: 
		if verbose:
			print("Counted")
		inputsCount += 1

func _submitInputs():
	if inputsCount == 0:
		return
	print("Code::Stats: Sending %d xp" % inputsCount)
	
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
