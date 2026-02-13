extends Control

# ─── UI References ───
@onready var splash_overlay: TextureRect = $SplashOverlay
@onready var login_panel: CenterContainer = $LoginPanel
@onready var background_rect: TextureRect = $TextureRect
@onready var guest_btn: Button = $LoginPanel/Card/Margin/VBox/GuestBtn
@onready var email_input: LineEdit = $LoginPanel/Card/Margin/VBox/EmailInput
@onready var password_input: LineEdit = $LoginPanel/Card/Margin/VBox/PasswordInput
@onready var sign_in_btn: Button = $LoginPanel/Card/Margin/VBox/ButtonRow/SignInBtn
@onready var register_btn: Button = $LoginPanel/Card/Margin/VBox/ButtonRow/RegisterBtn
@onready var status_label: Label = $LoginPanel/Card/Margin/VBox/StatusLabel

var _login_timeout_timer: Timer

func _ready():
	# 1. Setup initial visibility
	login_panel.modulate.a = 0.0
	splash_overlay.visible = true
	splash_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	status_label.text = ""

	# 2. Connect PlayFab signals
	PlayFabManager.client.logged_in.connect(_on_login_success)
	PlayFabManager.client.api_error.connect(_on_api_error)
	PlayFabManager.client.registered.connect(_on_register_success)

	# 3. Connect UI signals
	guest_btn.pressed.connect(_on_guest_pressed)
	sign_in_btn.pressed.connect(_on_sign_in_pressed)
	register_btn.pressed.connect(_on_register_pressed)

	# Mobile: ensure tap on email field grabs focus so virtual keyboard shows
	email_input.gui_input.connect(_on_field_gui_input.bind(email_input))
	password_input.gui_input.connect(_on_field_gui_input.bind(password_input))

	# Timeout so mobile users aren't stuck on "Authenticating..." if request never completes
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

# ─── Button Handlers ───

func _on_guest_pressed():
	_set_busy("Logging in as guest...")
	_login_timeout_timer.start()

	var info_params = GetPlayerCombinedInfoRequestParams.new()
	# On web/mobile Safari, OS.get_unique_id() can be empty; use fallback
	var device_id = OS.get_unique_id()
	if device_id.is_empty():
		device_id = "web_%d_%d" % [Time.get_ticks_msec(), randi()]
	print("Guest login with device ID (%d chars, web: %s)" % [device_id.length(), str(OS.has_feature("web"))])
	PlayFabManager.client.login_with_custom_id(device_id, true, info_params)

func _on_sign_in_pressed():
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()

	if email == "":
		_show_status("Please enter your email.", Color(1, 0.5, 0.5))
		return
	if password.length() < 6:
		_show_status("Password must be at least 6 characters.", Color(1, 0.5, 0.5))
		return

	_set_busy("Signing in...")
	_login_timeout_timer.start()

	var info_params = GetPlayerCombinedInfoRequestParams.new()
	print("Signing in: %s" % email)
	PlayFabManager.client.login_with_email(email, password, {}, info_params)

func _on_register_pressed():
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()

	if email == "":
		_show_status("Please enter your email.", Color(1, 0.5, 0.5))
		return
	if password.length() < 6:
		_show_status("Password must be at least 6 characters.", Color(1, 0.5, 0.5))
		return

	_set_busy("Creating account...")
	_login_timeout_timer.start()

	var info_params = GetPlayerCombinedInfoRequestParams.new()
	var temp_username = email.split("@")[0]
	print("Registering new user: %s" % email)
	PlayFabManager.client.register_email_password(temp_username, email, password, info_params)

# ─── PlayFab Callbacks ───

func _on_login_success(result):
	_login_timeout_timer.stop()
	_show_status("Success! Loading game...", Color(0.3, 1.0, 0.3))

	# Fetch Title Data immediately after login
	var title_data_request = GetTitleDataRequest.new()
	PlayFabManager.client.get_title_data(title_data_request, func(t_result):
		var raw_json = t_result.data.Data.get("GameData", "")
		if raw_json != "":
			var parsed_data = JSON.parse_string(raw_json)
			StatCalculator.initialize_from_playfab(parsed_data)
			print("StatCalculator Initialized!")

		get_tree().change_scene_to_file("res://ui/character_creation/character_selection.tscn")
	)

func _on_register_success(result):
	print("SUCCESS! New account created: %s" % result.PlayFabId)
	_show_status("Account created!", Color(0.3, 1.0, 0.3))
	_on_login_success(result)

func _on_api_error(error):
	_login_timeout_timer.stop()

	# Handle both ApiErrorWrapper objects and plain Dictionaries (from local validation)
	var error_code = ""
	var error_msg = "Unknown error"
	if error is Dictionary:
		error_code = error.get("error", "")
		error_msg = error.get("errorMessage", error_msg)
	else:
		error_code = str(error.error) if error.error != null else ""
		error_msg = error.errorMessage if error.errorMessage != null and str(error.errorMessage) != "" else error_msg

	print("PlayFab Error: [%s] %s" % [error_code, error_msg])

	# User-friendly messages for common errors
	var display_msg = error_msg
	match error_code:
		"AccountNotFound":
			display_msg = "No account found with that email."
		"InvalidEmailOrPassword":
			display_msg = "Invalid email or password."
		"EmailAddressNotAvailable":
			display_msg = "An account with that email already exists."
		"InvalidPassword":
			display_msg = "Password is incorrect."

	_set_idle()
	_show_status(display_msg, Color(1, 0.5, 0.5))

func _on_login_timeout():
	print("Login timeout triggered after 20s. web=%s mobile=%s" % [str(OS.has_feature("web")), str(OS.has_feature("mobile"))])
	_set_idle()
	_show_status("Request timed out. Please try again.", Color(1, 0.7, 0.3))

# ─── UI Helpers ───

func _set_busy(msg: String) -> void:
	guest_btn.disabled = true
	sign_in_btn.disabled = true
	register_btn.disabled = true
	_show_status(msg, Color(0.8, 0.8, 0.8))

func _set_idle() -> void:
	guest_btn.disabled = false
	sign_in_btn.disabled = false
	register_btn.disabled = false

func _show_status(msg: String, color: Color = Color.WHITE) -> void:
	status_label.text = msg
	status_label.add_theme_color_override("font_color", color)

func _on_field_gui_input(event: InputEvent, field: LineEdit):
	# On mobile, explicitly grab focus on tap so the browser shows the virtual keyboard
	if event is InputEventScreenTouch and event.pressed:
		field.grab_focus()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		field.grab_focus()
