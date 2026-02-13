# WhatsNewPopup.gd — Overlay popup that displays unseen changelog entries.
# Instantiate, call show_unseen_entries(), and add to the scene tree.
extends Control

@onready var title_label: Label = $CenterContainer/Card/Margin/VBox/TitleLabel
@onready var content_vbox: VBoxContainer = $CenterContainer/Card/Margin/VBox/ScrollArea/ContentVBox
@onready var got_it_btn: Button = $CenterContainer/Card/Margin/VBox/GotItBtn

const VERSION_COLOR := Color(0.4, 0.8, 1.0)
const TITLE_COLOR := Color(1.0, 0.9, 0.4)

func _ready() -> void:
	got_it_btn.pressed.connect(_on_got_it)
	# Block input to stuff behind the popup
	mouse_filter = Control.MOUSE_FILTER_STOP

func show_unseen_entries(entries: Array) -> void:
	# Clear any previous content
	for child in content_vbox.get_children():
		child.queue_free()

	if entries.is_empty():
		var lbl = Label.new()
		lbl.text = "You're all caught up!"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content_vbox.add_child(lbl)
		return

	for entry in entries:
		_add_entry(entry)

func _add_entry(entry: Dictionary) -> void:
	var version = entry.get("v", "?.?.?")
	var date = entry.get("date", "")
	var title = entry.get("title", "Update")
	var changes = entry.get("changes", [])

	# Version + Date
	var header = Label.new()
	header.text = "v%s  —  %s" % [version, date]
	header.add_theme_color_override("font_color", VERSION_COLOR)
	header.add_theme_font_size_override("font_size", 14)
	content_vbox.add_child(header)

	# Title
	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.add_theme_color_override("font_color", TITLE_COLOR)
	title_lbl.add_theme_font_size_override("font_size", 16)
	content_vbox.add_child(title_lbl)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	content_vbox.add_child(spacer)

	# Bullet points
	for change_text in changes:
		var bullet = Label.new()
		bullet.text = "  •  %s" % change_text
		bullet.add_theme_font_size_override("font_size", 13)
		bullet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content_vbox.add_child(bullet)

	# Separator between entries
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	content_vbox.add_child(sep)

func _on_got_it() -> void:
	# Mark changelog as seen on PlayFab, then remove popup
	GameManager.mark_changelog_seen()
	queue_free()
