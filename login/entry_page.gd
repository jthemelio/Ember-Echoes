extends Control

# UI References
@onready var splash_overlay: TextureRect = $SplashOverlay
@onready var login_panel: Control = $LoginPanel
@onready var background_rect: TextureRect = $TextureRect
@onready var email_input = $LoginPanel/VBoxContainer/CustomIDInput
@onready var password_input = $LoginPanel/VBoxContainer/PasswordInput
@onready var login_button = $LoginPanel/VBoxContainer/LoginButton

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
	
	# 4. Connect UI signals
	login_button.pressed.connect(_on_login_pressed)
	if not email_input.text_changed.is_connected(_on_custom_id_input_text_changed):
		email_input.text_changed.connect(_on_custom_id_input_text_changed)

func _input(event):
	if event is InputEventMouseButton and event.pressed and splash_overlay.visible:
		fade_to_login()

func fade_to_login():
	background_rect.show()
	background_rect.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(splash_overlay, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(login_panel, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(splash_overlay.hide)
	splash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_login_pressed():
	login_button.disabled = true
	login_button.text = "Authenticating..."
	
	var info_params = GetPlayerCombinedInfoRequestParams.new()
	var input_text = email_input.text.strip_edges()
	var password_text = password_input.text.strip_edges()
	
	if input_text == "":
		var device_id = OS.get_unique_id()
		print("Attempting Silent Device Login...")
		# Matches: (custom_id: String, create_user: bool, info_params: GetPlayerCombinedInfoRequestParams)
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
	# Check if the login type was CustomID (Guest)
	if PlayFabManager.client_config.login_type == PlayFabClientConfig.LoginType.LOGIN_CUSTOM_ID:
		show_link_account_reminder()
	
	# Proceed to character creation
	get_tree().change_scene_to_file("res://scenes/character_creation.tscn")

func show_link_account_reminder():
	# This would trigger a UI popup you've designed
	# "Warning: You are playing as a Guest. Link an email to save your progress!"
	print("REMINDER: Player is a guest. Suggest linking an account.")

func _on_api_error(error):
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

func _on_register_success(result):
	print("SUCCESS! New account created: ", result.PlayFabId)
	_on_login_success(result)

func _on_custom_id_input_text_changed(new_text: String) -> void:
	var text_trimmed = new_text.strip_edges()
	if text_trimmed == "":
		login_button.text = "Guest Login"
		password_input.visible = false
	else:
		login_button.text = "Sign In / Register"
		password_input.visible = true
