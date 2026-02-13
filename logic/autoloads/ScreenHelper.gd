# ScreenHelper.gd — Responsive layout helper for desktop vs mobile.
# Detects viewport width and provides scaling utilities.
# All desktop adaptations are gated behind is_desktop() so mobile stays untouched.
extends Node

signal viewport_mode_changed(is_desktop: bool)

## Viewport width threshold: anything above this is considered "desktop"
const DESKTOP_THRESHOLD := 700.0

## Maximum content width on desktop (keeps UI from stretching infinitely)
const MAX_CONTENT_WIDTH := 800.0

## UI scale factor applied on desktop (fonts, buttons, spacing)
const DESKTOP_UI_SCALE := 1.25

var _was_desktop: bool = false

func _ready() -> void:
	get_tree().root.size_changed.connect(_on_viewport_resized)
	# Evaluate once on startup
	_was_desktop = is_desktop()

func _on_viewport_resized() -> void:
	var now_desktop = is_desktop()
	if now_desktop != _was_desktop:
		_was_desktop = now_desktop
		viewport_mode_changed.emit(now_desktop)

## Gets the viewport size safely from a Node (not CanvasItem)
func _vp_width() -> float:
	var vp = get_viewport()
	if vp:
		return vp.get_visible_rect().size.x
	return 0.0

## Returns true when the viewport is wide enough to be a desktop browser
func is_desktop() -> bool:
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

## Returns the anchor ratio for the left edge of centered content (0.0 on mobile)
func get_content_anchor_left() -> float:
	if not is_desktop():
		return 0.0
	var vp_w = _vp_width()
	if vp_w <= 0:
		return 0.0
	return get_side_margin() / vp_w

## Returns the anchor ratio for the right edge of centered content (1.0 on mobile)
func get_content_anchor_right() -> float:
	if not is_desktop():
		return 1.0
	return 1.0 - get_content_anchor_left()
