extends Control

# --- Game State ---
var gecko_name: String = "Gecko"
var hunger: int     = 100
var hydration: int  = 100
var temperature: int = 78
var lamp_on: bool   = true
var day: int        = 1
var alive: bool     = true

var gecko_x: int = 1
var gecko_y: int = 2

const GRID_COLS: int = 4
const GRID_ROWS: int = 6

const TEMP_MIN: int      = 65
const TEMP_MAX: int      = 95
const TEMP_SAFE_LOW: int  = 72
const TEMP_SAFE_HIGH: int = 88

const ROW_LABELS: Array = ["Top", "  ↕ ", "Mid", "  ↕ ", "Bot", "Sub"]

# --- UI Nodes ---
var name_screen: Control
var name_input: LineEdit
var game_screen: Control

var day_label: Label
var hunger_label: Label
var hydration_label: Label
var temperature_label: Label
var position_label: Label
var status_label: Label
var feed_button: Button
var water_button: Button
var lamp_button: Button
var end_turn_button: Button
var restart_button: Button
var log_container: VBoxContainer
var log_scroll: ScrollContainer

var tile_panels: Array = []
var tile_labels: Array = []


func _ready() -> void:
	_build_name_screen()
	_build_game_screen()
	game_screen.hide()


# ══════════════════════════════════════════════════════════════
# NAME SCREEN
# ══════════════════════════════════════════════════════════════

func _build_name_screen() -> void:
	name_screen = Control.new()
	name_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(name_screen)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(360, 0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	name_screen.add_child(vbox)

	var title = Label.new()
	title.text = "Gecko Enclosure Simulator"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "What will you name your gecko?"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	name_input = LineEdit.new()
	name_input.placeholder_text = "Enter a name..."
	name_input.custom_minimum_size = Vector2(360, 0)
	name_input.text = ""
	name_input.grab_focus()
	name_input.text_submitted.connect(_on_name_submitted)
	vbox.add_child(name_input)

	var start_btn = Button.new()
	start_btn.text = "Start Game"
	start_btn.pressed.connect(_on_start_pressed)
	vbox.add_child(start_btn)


func _on_name_submitted(_text: String) -> void:
	_on_start_pressed()

func _on_start_pressed() -> void:
	var entered = name_input.text.strip_edges()
	gecko_name = entered if entered.length() > 0 else "Gecko"
	name_screen.hide()
	game_screen.show()
	_update_display()


# ══════════════════════════════════════════════════════════════
# GAME SCREEN
# ══════════════════════════════════════════════════════════════

func _build_game_screen() -> void:
	game_screen = Control.new()
	game_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(game_screen)

	var root = MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left",   40)
	root.add_theme_constant_override("margin_right",  40)
	root.add_theme_constant_override("margin_top",    30)
	root.add_theme_constant_override("margin_bottom", 30)
	game_screen.add_child(root)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 40)
	root.add_child(hbox)

	_build_grid_column(hbox)
	_build_stats_column(hbox)


func _build_grid_column(parent: Node) -> void:
	var left = VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(left)

	var grid_title = Label.new()
	grid_title.text = "Enclosure"
	grid_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(grid_title)

	var grid_row = HBoxContainer.new()
	grid_row.alignment = BoxContainer.ALIGNMENT_CENTER
	grid_row.add_theme_constant_override("separation", 4)
	left.add_child(grid_row)

	var row_label_col = VBoxContainer.new()
	row_label_col.add_theme_constant_override("separation", 0)
	grid_row.add_child(row_label_col)

	for row_name in ROW_LABELS:
		var lbl = Label.new()
		lbl.text = row_name
		lbl.custom_minimum_size = Vector2(30, 70)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row_label_col.add_child(lbl)

	var grid = GridContainer.new()
	grid.columns = GRID_COLS
	grid_row.add_child(grid)

	tile_panels.resize(GRID_COLS * GRID_ROWS)
	tile_labels.resize(GRID_COLS * GRID_ROWS)

	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			var panel = PanelContainer.new()
			panel.custom_minimum_size = Vector2(90, 70)
			var lbl = Label.new()
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			panel.add_child(lbl)
			grid.add_child(panel)
			var idx = y * GRID_COLS + x
			tile_panels[idx] = panel
			tile_labels[idx] = lbl


func _build_stats_column(parent: Node) -> void:
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	parent.add_child(right)

	var title = Label.new()
	title.text = "=== Gecko Enclosure ==="
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(title)

	day_label = Label.new()
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(day_label)

	right.add_child(HSeparator.new())

	hunger_label      = Label.new(); right.add_child(hunger_label)
	hydration_label   = Label.new(); right.add_child(hydration_label)
	temperature_label = Label.new(); right.add_child(temperature_label)
	position_label    = Label.new(); right.add_child(position_label)

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

	lamp_button = Button.new()
	lamp_button.pressed.connect(_on_lamp_pressed)
	right.add_child(lamp_button)

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

	right.add_child(HSeparator.new())

	# Turn log
	var log_title = Label.new()
	log_title.text = "Turn Log"
	right.add_child(log_title)

	log_scroll = ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.custom_minimum_size = Vector2(0, 80)
	right.add_child(log_scroll)

	log_container = VBoxContainer.new()
	log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_container.add_theme_constant_override("separation", 2)
	log_scroll.add_child(log_container)


# ══════════════════════════════════════════════════════════════
# BUTTON HANDLERS
# ══════════════════════════════════════════════════════════════

func _on_feed_pressed() -> void:
	if not alive: return
	hunger = min(100, hunger + 30)
	_log("You fed %s.  Hunger → %d" % [gecko_name, hunger])
	_update_display()

func _on_water_pressed() -> void:
	if not alive: return
	hydration = min(100, hydration + 30)
	_log("You gave %s water.  Hydration → %d" % [gecko_name, hydration])
	_update_display()

func _on_lamp_pressed() -> void:
	if not alive: return
	lamp_on = not lamp_on
	_log("Heat lamp turned %s." % ("ON" if lamp_on else "OFF"))
	_update_display()

func _on_end_turn_pressed() -> void:
	if not alive: return
	day       += 1
	hunger     = max(0, hunger    - 20)
	hydration  = max(0, hydration - 25)
	if lamp_on:
		temperature = min(TEMP_MAX, temperature + 5)
	else:
		temperature = max(TEMP_MIN, temperature - 5)
	_move_gecko()

	# Build a turn summary
	var events: Array = []
	if hunger  == 0: events.append("starved")
	if hydration == 0: events.append("dehydrated")
	if temperature <= TEMP_MIN: events.append("froze")
	if temperature >= TEMP_MAX: events.append("overheated")

	if events.size() > 0:
		alive = false
		_log("Day %d: %s %s — game over." % [day, gecko_name, ", ".join(events)])
	else:
		var summary = "Day %d: hunger %d, hydration %d, temp %d°F." % [day, hunger, hydration, temperature]
		if hunger < 30 or hydration < 30 or temperature < TEMP_SAFE_LOW or temperature > TEMP_SAFE_HIGH:
			summary += "  ⚠ Needs attention!"
		_log(summary)

	_update_display()

func _on_restart_pressed() -> void:
	hunger      = 100
	hydration   = 100
	temperature = 78
	lamp_on     = true
	day         = 1
	alive       = true
	gecko_x     = 1
	gecko_y     = 2
	# Clear log
	for child in log_container.get_children():
		child.queue_free()
	_log("New game started. Good luck, %s!" % gecko_name)
	_update_display()


# ══════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════

func _move_gecko() -> void:
	var dirs = [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]
	dirs.shuffle()
	for d in dirs:
		var nx = gecko_x + d.x
		var ny = gecko_y + d.y
		if nx >= 0 and nx < GRID_COLS and ny >= 0 and ny < GRID_ROWS:
			gecko_x = nx
			gecko_y = ny
			break

func _log(text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_container.add_child(lbl)
	# Scroll to bottom on the next frame (after layout updates)
	await get_tree().process_frame
	log_scroll.scroll_vertical = log_scroll.get_v_scroll_bar().max_value

func _tile_color(x: int, y: int) -> Color:
	if x == gecko_x and y == gecko_y:
		return Color(0.25, 0.50, 0.15)
	if y == GRID_ROWS - 1:      return Color(0.22, 0.14, 0.06)
	if y >= GRID_ROWS - 3:      return Color(0.20, 0.16, 0.10)
	if y >= 2:                  return Color(0.18, 0.20, 0.14)
	return Color(0.20, 0.22, 0.18)

func _make_stylebox(color: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_border_width_all(1)
	s.border_color = Color(0.45, 0.32, 0.18)
	return s

func _update_display() -> void:
	# Grid
	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			var idx = y * GRID_COLS + x
			tile_panels[idx].add_theme_stylebox_override("panel", _make_stylebox(_tile_color(x, y)))
			tile_labels[idx].text = "🦎" if (x == gecko_x and y == gecko_y) else ""

	# Stats
	day_label.text         = "Day %d  —  %s" % [day, gecko_name]
	hunger_label.text      = "Hunger:      %d / 100" % hunger
	hydration_label.text   = "Hydration:   %d / 100" % hydration
	temperature_label.text = "Temperature: %d°F  (safe: %d–%d)" % [temperature, TEMP_SAFE_LOW, TEMP_SAFE_HIGH]
	lamp_button.text       = "Heat Lamp:  %s" % ("ON  🔆" if lamp_on else "OFF  🌑")

	var layer: String
	if gecko_y <= 1:   layer = "top layer"
	elif gecko_y <= 3: layer = "middle layer"
	elif gecko_y == 4: layer = "bottom layer"
	else:              layer = "substrate"
	position_label.text = "Location:    col %d, %s" % [gecko_x, layer]

	var warnings: Array = []
	if hunger      < 30: warnings.append("hungry")
	if hydration   < 30: warnings.append("thirsty")
	if temperature < TEMP_SAFE_LOW:  warnings.append("too cold")
	if temperature > TEMP_SAFE_HIGH: warnings.append("too hot")

	if not alive:
		status_label.text        = "%s didn't make it. Try again!" % gecko_name
		feed_button.disabled     = true
		water_button.disabled    = true
		lamp_button.disabled     = true
		end_turn_button.disabled = true
		restart_button.show()
	elif warnings.size() > 0:
		status_label.text = "Warning: %s is %s!" % [gecko_name, ", ".join(warnings)]
	else:
		status_label.text        = "%s is doing well." % gecko_name
		feed_button.disabled     = false
		water_button.disabled    = false
		lamp_button.disabled     = false
		end_turn_button.disabled = false
		restart_button.hide()
