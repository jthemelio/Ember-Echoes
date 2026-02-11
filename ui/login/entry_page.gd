extends Control

# UI References
@onready var splash_overlay: TextureRect = $SplashOverlay
@onready var login_panel: Control = $LoginPanel
@onready var background_rect: TextureRect = $TextureRect
@onready var email_input = $LoginPanel/VBoxContainer/CustomIDInput
@onready var password_input = $LoginPanel/VBoxContainer/PasswordInput
@onready var login_button = $LoginPanel/VBoxContainer/LoginButton

var _login_timeout_timer: Timer

func _ready():
	# 1. Setup initial visibility
	login_panel.modulate.a = 0.0
	splash_overlay.visible = true
	splash_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 2. Force Initial Guest State
	login_button.text = "Guest Login"
	password_input.visible = false
	
	# 3. Connect PlayFab signals (Crucial for this SDK)
	# These catch the results from the calls below
	PlayFabManager.client.logged_in.connect(_on_login_success)
	PlayFabManager.client.api_error.connect(_on_api_error)
	PlayFabManager.client.registered.connect(_on_register_success)
	
	# 4. Connect UI signals
	login_button.pressed.connect(_on_login_pressed)
	if not email_input.text_changed.is_connected(_on_custom_id_input_text_changed):
		email_input.text_changed.connect(_on_custom_id_input_text_changed)
	# Mobile: ensure tap on email field grabs focus so virtual keyboard can show
	if not email_input.gui_input.is_connected(_on_email_gui_input):
		email_input.gui_input.connect(_on_email_gui_input)

	# Timeout so mobile users aren't stuck on "Authenticating..." if request never completes (e.g. Safari/network)
	_login_timeout_timer = Timer.new()
	_login_timeout_timer.one_shot = true
	_login_timeout_timer.wait_time = 20.0
	_login_timeout_timer.timeout.connect(_on_login_timeout)
	add_child(_login_timeout_timer)

func _input(event):
	# Dismiss splash on tap (mouse or touch; mobile Safari sends touch, not mouse)
	var is_tap = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if is_tap and splash_overlay.visible:
		fade_to_login()

func fade_to_login():
	background_rect.show()
	background_rect.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(splash_overlay, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(login_panel, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(splash_overlay.hide)
	splash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Give email field focus after panel is visible so next tap can show keyboard (mobile)
	tween.tween_callback(func(): email_input.call_deferred("grab_focus"))

func _on_login_pressed():
	login_button.disabled = true
	login_button.text = "Authenticating..."
	_login_timeout_timer.start()

	var info_params = GetPlayerCombinedInfoRequestParams.new()
	var input_text = email_input.text.strip_edges()
	var password_text = password_input.text.strip_edges()

	if input_text == "":
		# On web/mobile Safari, OS.get_unique_id() can be empty or restricted; use fallback so request is sent
		var device_id = OS.get_unique_id()
		if device_id.is_empty():
			device_id = "web_%d_%d" % [Time.get_ticks_msec(), randi()]
		print("Attempting Silent Device Login... (id: ", device_id.length(), " chars)")
		PlayFabManager.client.login_with_custom_id(device_id, true, info_params)
	else:
		if password_text.length() < 6:
			login_button.disabled = false
			login_button.text = "Sign In / Register"
			_on_api_error({"errorMessage": "Password must be at least 6 characters."})
			return

		print("Attempting Email Login for: ", input_text)
		# Matches: (email, password, custom_tags, info_params)
		# We pass an empty dictionary {} for custom_tags
		PlayFabManager.client.login_with_email(input_text, password_text, {}, info_params)

func _on_login_success(result):
	_login_timeout_timer.stop()
	# 1. Fetch Title Data immediately after login
	var title_data_request = GetTitleDataRequest.new()
	
	PlayFabManager.client.get_title_data(title_data_request, func(t_result):
		# Access the raw JSON string from your Title Data
		var raw_json = t_result.data.Data.get("GameData", "")
		if raw_json != "":
			var parsed_data = JSON.parse_string(raw_json)
			# 2. Feed the JSON to the Calculator
			StatCalculator.initialize_from_playfab(parsed_data)
			print("StatCalculator Initialized!")
		
		# 3. Proceed to character selection once data is ready
		get_tree().change_scene_to_file("res://ui/character_creation/character_selection.tscn")
	)

func show_link_account_reminder():
	# This would trigger a UI popup you've designed
	# "Warning: You are playing as a Guest. Link an email to save your progress!"
	print("REMINDER: Player is a guest. Suggest linking an account.")

func _on_api_error(error):
	_login_timeout_timer.stop()
	# The SDK passes an ApiErrorWrapper object, not a Dictionary.
	# We check the 'error' property for the string "AccountNotFound"
	if error.error == "AccountNotFound":
		print("Account not found. Attempting to register...")
		register_new_user()
		return
	
	# Reset the UI so the player can try again
	login_button.disabled = false
	login_button.text = "Sign In / Register"
	
	# Access the errorMessage property directly from the ApiErrorWrapper
	var msg = error.errorMessage if error.errorMessage != "" else "Unknown PlayFab Error"
	print("PlayFab Error: ", msg)

func register_new_user():
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	var info_params = GetPlayerCombinedInfoRequestParams.new()
	
	# Create a temporary username from the email (e.g., "player" from "player@test.com")
	var temp_username = email.split("@")[0]
	
	print("Registering new user: ", email)
	# Matches: (username, email, password, info_params)
	PlayFabManager.client.register_email_password(temp_username, email, password, info_params)

func _on_login_timeout():
	if login_button.text == "Authenticating...":
		login_button.disabled = false
		login_button.text = "Timed out. Try again."

func _on_register_success(result):
	print("SUCCESS! New account created: ", result.PlayFabId)
	_on_login_success(result)

func _on_email_gui_input(event: InputEvent):
	# On mobile, explicitly grab focus on tap so the browser shows the virtual keyboard
	if event is InputEventScreenTouch and event.pressed:
		email_input.grab_focus()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		email_input.grab_focus()

func _on_custom_id_input_text_changed(new_text: String) -> void:
	var text_trimmed = new_text.strip_edges()
	if text_trimmed == "":
		login_button.text = "Guest Login"
		password_input.visible = false
	else:
		login_button.text = "Sign In / Register"
		password_input.visible = true
