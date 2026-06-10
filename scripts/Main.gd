extends Control

# --- Game State ---
var hunger: int = 100
var hydration: int = 100
var day: int = 1
var alive: bool = true

# --- UI Nodes (created in _ready) ---
var day_label: Label
var hunger_label: Label
var hydration_label: Label
var status_label: Label
var feed_button: Button
var water_button: Button
var end_turn_button: Button
var restart_button: Button
var gecko_image: TextureRect


func _ready() -> void:
	_build_ui()
	_update_display()


func _build_ui() -> void:
	# Full-screen container
	var root = MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left",   40)
	root.add_theme_constant_override("margin_right",  40)
	root.add_theme_constant_override("margin_top",    40)
	root.add_theme_constant_override("margin_bottom", 40)
	add_child(root)

	# Two columns: gecko image left, info right
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 40)
	root.add_child(hbox)

	# --- Left column: gecko image ---
	var left = VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(left)

	gecko_image = TextureRect.new()
	gecko_image.texture = load("res://assets/gecko.svg")
	gecko_image.custom_minimum_size = Vector2(300, 300)
	gecko_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gecko_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(gecko_image)

	# --- Right column: stats + buttons ---
	var right = VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	hbox.add_child(right)

	var title = Label.new()
	title.text = "=== Gecko Enclosure ==="
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(title)

	day_label = Label.new()
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(day_label)

	right.add_child(HSeparator.new())

	hunger_label = Label.new()
	right.add_child(hunger_label)

	hydration_label = Label.new()
	right.add_child(hydration_label)

	right.add_child(HSeparator.new())

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_child(status_label)

	right.add_child(HSeparator.new())

	feed_button = Button.new()
	feed_button.text = "Feed Gecko  (+30 hunger)"
	feed_button.pressed.connect(_on_feed_pressed)
	right.add_child(feed_button)

	water_button = Button.new()
	water_button.text = "Give Water  (+30 hydration)"
	water_button.pressed.connect(_on_water_pressed)
	right.add_child(water_button)

	right.add_child(HSeparator.new())

	end_turn_button = Button.new()
	end_turn_button.text = "End Turn  →  Next Day"
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	right.add_child(end_turn_button)

	restart_button = Button.new()
	restart_button.text = "Restart"
	restart_button.pressed.connect(_on_restart_pressed)
	restart_button.hide()
	right.add_child(restart_button)


# --- Button Handlers ---

func _on_feed_pressed() -> void:
	if not alive:
		return
	hunger = min(100, hunger + 30)
	_update_display()


func _on_water_pressed() -> void:
	if not alive:
		return
	hydration = min(100, hydration + 30)
	_update_display()


func _on_end_turn_pressed() -> void:
	if not alive:
		return
	day += 1
	hunger    = max(0, hunger    - 20)
	hydration = max(0, hydration - 25)
	if hunger == 0 or hydration == 0:
		alive = false
	_update_display()


func _on_restart_pressed() -> void:
	hunger    = 100
	hydration = 100
	day       = 1
	alive     = true
	_update_display()


# --- Refresh the screen ---

func _update_display() -> void:
	day_label.text       = "Day %d" % day
	hunger_label.text    = "Hunger:     %d / 100" % hunger
	hydration_label.text = "Hydration:  %d / 100" % hydration

	if not alive:
		status_label.text        = "Your gecko didn't make it. Try again!"
		feed_button.disabled     = true
		water_button.disabled    = true
		end_turn_button.disabled = true
		restart_button.show()
		gecko_image.modulate     = Color(0.4, 0.4, 0.4)  # grey out the gecko
	elif hunger < 30 or hydration < 30:
		status_label.text    = "Warning: gecko needs attention soon!"
		gecko_image.modulate = Color(1, 0.7, 0.3)  # tint orange as warning
	else:
		status_label.text    = "Gecko is doing well."
		gecko_image.modulate = Color(1, 1, 1)  # normal color
		feed_button.disabled     = false
		water_button.disabled    = false
		end_turn_button.disabled = false
		restart_button.hide()
