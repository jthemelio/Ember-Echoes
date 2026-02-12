extends Control
class_name LightningBoltEffect
## Spawns real Line2D zigzag lightning bolts that flash in, hold, and fade out.
## Placed behind the item icon in InventorySlot. Configured per quality tier.

# --- Configurable per tier ---
var bolt_color := Color.WHITE
var spawn_interval := 0.2     # seconds between new bolts
var bolt_lifetime := 0.45     # total lifetime per bolt
var width_core := 1.5         # thin bright centre line
var width_glow := 5.0         # wider dim glow line
var segment_count := 8        # zigzag joints per bolt
var jag_amount := 12.0        # max lateral offset in pixels
var active := false

var _timer := 0.0

# --- Process ---

func _process(delta: float) -> void:
	if not active or not visible:
		return

	_timer -= delta
	if _timer <= 0.0:
		_spawn_bolt()
		_timer = spawn_interval

# --- Spawn a bolt ---

func _spawn_bolt() -> void:
	var s = size
	if s.x < 2.0 or s.y < 2.0:
		return

	var p0 = _random_point(s)
	var p1 = _random_point(s)

	# Ensure minimum bolt length (~30% of slot diagonal)
	var min_len = s.length() * 0.3
	var attempts = 0
	while p0.distance_to(p1) < min_len and attempts < 5:
		p1 = _random_point(s)
		attempts += 1

	var points = _make_zigzag(p0, p1)
	var core_color = bolt_color.lerp(Color.WHITE, 0.7)

	# Glow line (wider, dimmer, tier-coloured)
	var glow = Line2D.new()
	glow.points = points
	glow.width = width_glow
	glow.default_color = Color(bolt_color, 0.35)
	glow.antialiased = true
	add_child(glow)

	# Core line (thin, bright white-ish)
	var core = Line2D.new()
	core.points = points
	core.width = width_core
	core.default_color = core_color
	core.antialiased = true
	add_child(core)

	# Animate: quick flash in → hold → fade out → free
	glow.modulate.a = 0.0
	core.modulate.a = 0.0

	var tw = create_tween()
	var fade_in  = bolt_lifetime * 0.1
	var hold     = bolt_lifetime * 0.5
	var fade_out = bolt_lifetime * 0.4

	tw.tween_property(core, "modulate:a", 1.0, fade_in)
	tw.parallel().tween_property(glow, "modulate:a", 1.0, fade_in)
	tw.tween_interval(hold)
	tw.tween_property(core, "modulate:a", 0.0, fade_out)
	tw.parallel().tween_property(glow, "modulate:a", 0.0, fade_out)
	tw.tween_callback(glow.queue_free)
	tw.tween_callback(core.queue_free)

# --- Zigzag generation ---

func _make_zigzag(p0: Vector2, p1: Vector2) -> PackedVector2Array:
	var pts = PackedVector2Array()
	var dir = (p1 - p0).normalized()
	var perp = Vector2(-dir.y, dir.x)

	pts.append(p0)
	for i in range(1, segment_count):
		var t = float(i) / float(segment_count)
		var base = p0.lerp(p1, t)
		pts.append(base + perp * randf_range(-jag_amount, jag_amount))
	pts.append(p1)
	return pts

# --- Random point (30% chance on an edge for dramatic "striking from outside") ---

func _random_point(s: Vector2) -> Vector2:
	if randf() < 0.3:
		match randi() % 4:
			0: return Vector2(randf() * s.x, 0.0)
			1: return Vector2(randf() * s.x, s.y)
			2: return Vector2(0.0, randf() * s.y)
			3: return Vector2(s.x, randf() * s.y)
	return Vector2(randf() * s.x, randf() * s.y)

# --- Public API ---

func configure(settings: Dictionary) -> void:
	bolt_color = settings.get("color", Color.WHITE)
	spawn_interval = settings.get("spawn_interval", 0.2)
	bolt_lifetime = settings.get("lifetime", 0.45)
	width_core = settings.get("width_core", 1.5)
	width_glow = settings.get("width_glow", 5.0)
	jag_amount = settings.get("jag_amount", 12.0)
	active = true
	visible = true
	_timer = 0.0  # spawn first bolt immediately

func deactivate() -> void:
	active = false
	visible = false
	for child in get_children():
		child.queue_free()
