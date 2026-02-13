# ScreenHelper.gd — Responsive layout helper for desktop vs mobile.
# Detects viewport width and provides scaling utilities.
# All desktop adaptations are gated behind is_desktop() so mobile stays untouched.
extends Node

signal viewport_mode_changed(is_desktop: bool)

## Physical window width threshold for desktop detection (pixels)
const DESKTOP_THRESHOLD := 900

## Maximum content width on desktop in virtual pixels (keeps UI from stretching)
const MAX_CONTENT_WIDTH := 850.0

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
	var ds = DisplayServer.window_get_size()
	var root = get_tree().root
	var cs = root.content_scale_size if root else Vector2i.ZERO
	print("ScreenHelper INIT: DS=%s  root.size=%s  content_scale=%s  vp_w=%.0f  is_desktop=%s" % [
		str(ds), str(root.size) if root else "null", str(cs), _vp_width(), str(_was_desktop)])

func _on_viewport_resized() -> void:
	var now_desktop = is_desktop()
	if now_desktop != _was_desktop:
		_was_desktop = now_desktop
		viewport_mode_changed.emit(now_desktop)

## Returns the physical window/canvas width using DisplayServer (most reliable).
func _window_width() -> float:
	var ds = DisplayServer.window_get_size()
	if ds.x > 0:
		return float(ds.x)
	var root = get_tree().root if get_tree() else null
	if root and root.size.x > 0:
		return float(root.size.x)
	return 450.0

## Returns the physical window/canvas height using DisplayServer.
func _window_height() -> float:
	var ds = DisplayServer.window_get_size()
	if ds.y > 0:
		return float(ds.y)
	var root = get_tree().root if get_tree() else null
	if root and root.size.y > 0:
		return float(root.size.y)
	return 800.0

## Returns the virtual viewport width (UI / Control coordinate system).
## With canvas_items + expand stretch, the virtual VP is wider or taller
## than the base content_scale_size (450x800 from project settings).
## We compute it from the physical window size and stretch formula.
func _vp_width() -> float:
	var window_w := _window_width()
	var window_h := _window_height()
	# Base viewport from project settings (fallback if content_scale_size is zero)
	var base_w := 450.0
	var base_h := 800.0
	var root = get_tree().root if get_tree() else null
	if root:
		var cs := root.content_scale_size
		if cs.x > 0:
			base_w = float(cs.x)
		if cs.y > 0:
			base_h = float(cs.y)
	var sc := minf(window_w / base_w, window_h / base_h)
	if sc > 0.0:
		return window_w / sc
	return 450.0

## Returns true when the virtual viewport is wider than a phone layout.
## Canvas is CSS-constrained (max 900px), so on desktop the virtual VP
## is ~667px vs ~450px on mobile.  Threshold of 550 cleanly separates them.
func is_desktop() -> bool:
	return _vp_width() > 550

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

## Returns the effective content width (always capped to MAX_CONTENT_WIDTH on wide viewports)
func get_content_width() -> float:
	var vp_w = _vp_width()
	return min(vp_w, MAX_CONTENT_WIDTH)

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
