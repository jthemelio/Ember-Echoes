# CometDropEffect.gd — Full-screen sky flash overlay for rare drops.
# Comet: single bright purple flashbang.
# Wyrm Sphere: intense red flash with aftershock pulses.
extends ColorRect

var COMET_SHADER: Shader = null

var _duration: float = 1.5
var _item_name: String = "Comet"
var _is_wyrm: bool = false

func setup(item_name: String, is_wyrm: bool = false) -> void:
	_item_name = item_name
	_is_wyrm = is_wyrm
	_duration = 3.0 if is_wyrm else 1.5

func _ready() -> void:
	# ── Full-screen overlay that doesn't block input ──
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_tree().root.get_visible_rect().size
	z_index = 100

	# ── Load shader ──
	if COMET_SHADER == null:
		COMET_SHADER = load("res://assets/shaders/comet_flash.gdshader") as Shader
	if COMET_SHADER == null:
		push_warning("CometDropEffect: shader not found")
		queue_free()
		return

	var mat = ShaderMaterial.new()
	mat.shader = COMET_SHADER
	material = mat

	# ── Configure by drop type ──
	if _is_wyrm:
		# Wyrm Sphere: deep crimson/red, very intense, multiple aftershocks
		mat.set_shader_parameter("flash_color", Color(0.85, 0.12, 0.08, 1.0))
		mat.set_shader_parameter("core_color", Color(1.0, 0.7, 0.5, 1.0))
		mat.set_shader_parameter("intensity", 3.0)
		mat.set_shader_parameter("aftershocks", 3.0)
	else:
		# Comet: violet/purple, clean single flash
		mat.set_shader_parameter("flash_color", Color(0.55, 0.22, 0.82, 1.0))
		mat.set_shader_parameter("core_color", Color(0.95, 0.9, 1.0, 1.0))
		mat.set_shader_parameter("intensity", 1.3)
		mat.set_shader_parameter("aftershocks", 0.0)

	mat.set_shader_parameter("progress", 0.0)

	# ── Announcement label ──
	var label = Label.new()
	label.text = _item_name + " Drop!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.custom_minimum_size = Vector2(300, 60)
	label.position.y -= 30
	label.add_theme_font_size_override("font_size", 24)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.0

	if _is_wyrm:
		label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	else:
		label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))

	add_child(label)

	# ── Play ──
	_play(mat, label)

func _play(mat: ShaderMaterial, label: Label) -> void:
	# Shader progress tween
	var shader_tween = create_tween()
	shader_tween.tween_method(func(val: float):
		mat.set_shader_parameter("progress", val)
	, 0.0, 1.0, _duration)

	# Label: fade in after the initial flash, then float up and fade out
	var label_tween = create_tween()
	label_tween.set_parallel(false)
	# Slight delay so the flash hits first
	label_tween.tween_interval(0.15)
	# Fade in
	label_tween.tween_property(label, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Hold
	label_tween.tween_interval(_duration * 0.35)
	# Float up + fade out
	label_tween.set_parallel(true)
	label_tween.tween_property(label, "position:y", label.position.y - 40, _duration * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	label_tween.tween_property(label, "modulate:a", 0.0, _duration * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Clean up
	shader_tween.finished.connect(func():
		queue_free()
	)
