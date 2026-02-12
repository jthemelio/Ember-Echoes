# FloatingText.gd — lightweight floating feedback label
# Spawns at a position, drifts upward, fades out, then self-destructs.
extends Label

const FLOAT_DISTANCE := 60.0   # pixels to drift upward
const DURATION := 1.2           # seconds for full animation

func _ready() -> void:
	# Style: bold, centered, with a subtle outline for readability
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 18)
	add_theme_constant_override("outline_size", 3)
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	# Ensure we don't block clicks
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100

	# Animate: float up + fade out
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y - FLOAT_DISTANCE, DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "modulate:a", 0.0, DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)
