extends Control

# --- Game State ---
var hunger: int     = 100
var hydration: int  = 100
var temperature: int = 78
var lamp_on: bool   = true
var day: int        = 1
var alive: bool     = true

# Gecko position on the 4-wide x 6-tall grid
# Row 0 = top (warm, bright)   Row 5 = substrate (cool, dark)
var gecko_x: int = 1
var gecko_y: int = 2

const GRID_COLS: int = 4
const GRID_ROWS: int = 6

const TEMP_MIN: int      = 65
const TEMP_MAX: int      = 95
const TEMP_SAFE_LOW: int  = 72
const TEMP_SAFE_HIGH: int = 88

# Row labels shown to the left of the grid
const ROW_LABELS: Array = ["Top", "  ↕ ", "Mid", "  ↕ ", "Bot", "Sub"]

# --- UI Nodes ---
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

# One PanelContainer and one Label per tile, stored flat: index = y * GRID_COLS + x
var tile_panels: Array = []
var tile_labels: Array = []


func _ready() -> void:
	_build_ui()
	_update_display()


func _build_ui() -> void:
	var root = MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left",   40)
	root.add_theme_constant_override("margin_right",  40)
	root.add_theme_constant_override("margin_top",    40)
	root.add_theme_constant_override("margin_bottom", 40)
	add_child(root)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 40)
	root.add_child(hbox)

	# ── Left column: grid ──────────────────────────────────────────
	var left = VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(left)

	var grid_title = Label.new()
	grid_title.text = "Enclosure"
	grid_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(grid_title)

	# Row-label + grid side by side
	var grid_row = HBoxContainer.new()
	grid_row.alignment = BoxContainer.ALIGNMENT_CENTER
	grid_row.add_theme_constant_override("separation", 4)
	left.add_child(grid_row)

	# Narrow column of row labels
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

	# The actual tile grid
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

	# ── Right column: stats + buttons ─────────────────────────────
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


# --- Button Handlers ---

func _on_feed_pressed() -> void:
	if not alive: return
	hunger = min(100, hunger + 30)
	_update_display()

func _on_water_pressed() -> void:
	if not alive: return
	hydration = min(100, hydration + 30)
	_update_display()

func _on_lamp_pressed() -> void:
	if not alive: return
	lamp_on = not lamp_on
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
	if hunger == 0 or hydration == 0 or temperature <= TEMP_MIN or temperature >= TEMP_MAX:
		alive = false
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
	_update_display()


# --- Gecko Movement ---

func _move_gecko() -> void:
	# Try a random adjacent tile (up/down/left/right); skip if out of bounds
	var dirs = [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]
	dirs.shuffle()
	for d in dirs:
		var nx = gecko_x + d.x
		var ny = gecko_y + d.y
		if nx >= 0 and nx < GRID_COLS and ny >= 0 and ny < GRID_ROWS:
			gecko_x = nx
			gecko_y = ny
			break


# --- Tile coloring ---

func _tile_color(x: int, y: int) -> Color:
	if x == gecko_x and y == gecko_y:
		return Color(0.25, 0.50, 0.15)   # green highlight for gecko
	if y == GRID_ROWS - 1:
		return Color(0.22, 0.14, 0.06)   # substrate row (darkest brown)
	if y >= GRID_ROWS - 3:
		return Color(0.20, 0.16, 0.10)   # bottom layer (dark)
	if y >= 2:
		return Color(0.18, 0.20, 0.14)   # middle layer
	return Color(0.20, 0.22, 0.18)       # top layer (slightly lighter)


func _make_stylebox(color: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_border_width_all(1)
	s.border_color = Color(0.45, 0.32, 0.18)
	return s


# --- Refresh everything ---

func _update_display() -> void:
	# Grid
	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			var idx = y * GRID_COLS + x
			tile_panels[idx].add_theme_stylebox_override("panel", _make_stylebox(_tile_color(x, y)))
			tile_labels[idx].text = "🦎" if (x == gecko_x and y == gecko_y) else ""

	# Stats
	day_label.text        = "Day %d" % day
	hunger_label.text     = "Hunger:      %d / 100" % hunger
	hydration_label.text  = "Hydration:   %d / 100" % hydration
	temperature_label.text = "Temperature: %d°F  (safe: %d–%d)" % [temperature, TEMP_SAFE_LOW, TEMP_SAFE_HIGH]
	lamp_button.text      = "Heat Lamp:  %s" % ("ON  🔆" if lamp_on else "OFF  🌑")

	var layer: String
	if gecko_y <= 1:   layer = "top layer"
	elif gecko_y <= 3: layer = "middle layer"
	elif gecko_y == 4: layer = "bottom layer"
	else:              layer = "substrate"
	position_label.text = "Location:    col %d, %s" % [gecko_x, layer]

	# Warnings
	var warnings: Array = []
	if hunger      < 30: warnings.append("hungry")
	if hydration   < 30: warnings.append("thirsty")
	if temperature < TEMP_SAFE_LOW:  warnings.append("too cold")
	if temperature > TEMP_SAFE_HIGH: warnings.append("too hot")

	if not alive:
		status_label.text        = "Your gecko didn't make it. Try again!"
		feed_button.disabled     = true
		water_button.disabled    = true
		lamp_button.disabled     = true
		end_turn_button.disabled = true
		restart_button.show()
	elif warnings.size() > 0:
		status_label.text = "Warning: gecko is %s!" % ", ".join(warnings)
	else:
		status_label.text        = "Gecko is doing well."
		feed_button.disabled     = false
		water_button.disabled    = false
		lamp_button.disabled     = false
		end_turn_button.disabled = false
		restart_button.hide()
