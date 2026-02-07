extends Node

# Reference the container where pages will be loaded
@onready var page_container = $MainLayout/ContentArea/PageContainer

# Preload your scenes for smooth transitions
var hero_scene = preload("res://scenes/pages/hero_tab.tscn")
var hunting_scene = preload("res://scenes/pages/hunting_grounds.tscn")

func _ready() -> void:
	# Load the Hero tab by default as the landing page
	switch_to_page(hero_scene)

func switch_to_page(new_page_scene: PackedScene):
	# 1. Clear the current page
	for child in page_container.get_children():
		child.queue_free()
	
	# 2. Add the new page
	var new_page = new_page_scene.instantiate()
	page_container.add_child(new_page)

# connected via signals in the editor
func _on_hero_button_pressed() -> void:
	switch_to_page(hero_scene)

func _on_idle_button_pressed() -> void:
	# Now properly loads hunting grounds which contains its own header
	switch_to_page(hunting_scene)
