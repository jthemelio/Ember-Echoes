# ScreenHelper.gd — Responsive layout helper for desktop vs mobile.
# Detects viewport width and provides scaling utilities.
# All desktop adaptations are gated behind is_desktop() so mobile stays untouched.
extends Node

signal viewport_mode_changed(is_desktop: bool)

## Physical window width threshold for desktop detection (pixels)
const DESKTOP_THRESHOLD := 900

## Maximum content width on desktop in virtual pixels (keeps UI from stretching)
const MAX_CONTENT_WIDTH := 800.0

## UI scale factor applied on desktop (fonts, buttons, spacing)
## At 800px content width (vs 450px mobile), we're already ~1.8x wider.
## Keep scale at 1.0 so UI elements don't overflow the constrained area.
const DESKTOP_UI_SCALE := 1.0

var _was_desktop: bool = false

func _ready() -> void:
	get_tree().root.size_changed.connect(_on_viewport_resized)
	# Evaluate once on startup (deferred so window is fully set up)
	call_deferred("_initial_check")

func _initial_check() -> void:
	_was_desktop = is_desktop()
	var phys_w = DisplayServer.window_get_size().x
	var virt_w = _vp_width()
	print("ScreenHelper: physical_w=%d  virtual_w=%d  threshold=%d  is_desktop=%s  side_margin=%.0f" % [
		phys_w, int(virt_w), DESKTOP_THRESHOLD, str(_was_desktop), get_side_margin()])

func _on_viewport_resized() -> void:
	var now_desktop = is_desktop()
	if now_desktop != _was_desktop:
		_was_desktop = now_desktop
		viewport_mode_changed.emit(now_desktop)

## Returns the virtual viewport width (UI coordinate system)
func _vp_width() -> float:
	if get_tree() and get_tree().root:
		return get_tree().root.size.x
	return 450.0  # fallback to base project width

## Returns true when the window is wide enough to be a desktop browser
func is_desktop() -> bool:
	# Use the VIRTUAL viewport width — the only metric that's consistent
	# across F5 editor, web exports, and mobile devices.
	# With canvas_items + expand stretch mode:
	#   - Mobile portrait (base 450x800): virtual width stays ~450  -> false
	#   - Desktop/browser (wide window):  virtual width expands 1000+ -> true
	# DisplayServer.window_get_size() is unreliable: it can return physical
	# device pixels on mobile (1080+) which falsely triggers desktop mode.
	return _vp_width() > DESKTOP_THRESHOLD

## Returns 1.0 on mobile, DESKTOP_UI_SCALE on desktop
func get_ui_scale() -> float:
	return DESKTOP_UI_SCALE if is_desktop() else 1.0

## Returns the horizontal margin needed to center-constrain content to MAX_CONTENT_WIDTH
func get_side_margin() -> float:
	if not is_desktop():
		return 0.0
	var vp_w = _vp_width()
	var margin = (vp_w - MAX_CONTENT_WIDTH) / 2.0
	return max(margin, 0.0)

## Helper: scale a font size for desktop
func scaled_font(base_size: int) -> int:
	return int(base_size * get_ui_scale())

## Helper: scale a Vector2 minimum size for desktop (only Y component)
func scaled_min_height(base_height: float) -> float:
	return base_height * get_ui_scale()

## Returns the effective content width (capped on desktop, full on mobile)
func get_content_width() -> float:
	var vp_w = _vp_width()
	if is_desktop():
		return min(vp_w, MAX_CONTENT_WIDTH)
	return vp_w

## Returns desktop grid column count, or mobile fallback
func grid_columns(mobile_cols: int, desktop_cols: int) -> int:
	return desktop_cols if is_desktop() else mobile_cols

## (Deprecated — use get_side_margin() with offsets instead)
func get_content_anchor_left() -> float:
	if not is_desktop():
		return 0.0
	var vp_w = _vp_width()
	if vp_w <= 0:
		return 0.0
	return get_side_margin() / vp_w

func get_content_anchor_right() -> float:
	if not is_desktop():
		return 1.0
	return 1.0 - get_content_anchor_left()
