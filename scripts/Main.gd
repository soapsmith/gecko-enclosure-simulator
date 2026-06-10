extends Control

# --- Game State ---
var gecko_name: String = "Gecko"
var hunger: int      = 100
var hydration: int   = 100
var temperature: int = 72
var lamp_on: bool    = true
var humidity: int    = 65
var time_of_day: int = 0    # 0=Dawn 1=Day 2=Dusk 3=Night
var day: int         = 1
var alive: bool      = true

var gecko_x: int = 1
var gecko_y: int = 2

# Plant
var plant_health: int   = 100
var plant_moisture: int = 60
var plant_alive: bool   = true
const PLANT_X: int = 2
const PLANT_Y: int = 1

# Crickets
var crickets: Array = []
var dust_mode: bool = false    # Whether next crickets will be calcium-dusted
const CRICKET_LIFESPAN: int        = 5
const CRICKET_HUNGER_RESTORE: int  = 25
const CRICKET_CALCIUM_RESTORE: int = 20

# Calcium
var calcium: int = 100

# Isopods and waste
var isopods: Array     = []   # each: {x, y, age}
var waste: Dictionary  = {}   # "x,y" -> int (0-100)

const ISOPOD_MAX_AGE: int        = 40
const ISOPOD_EAT_AMOUNT: int     = 10
const GECKO_WASTE_PER_TURN: int  = 4
const WASTE_STRESS_THRESHOLD: int = 40   # waste above this on gecko tile = stress

const GRID_COLS: int = 4
const GRID_ROWS: int = 6

const TEMP_MIN: int      = 65
const TEMP_MAX: int      = 95
const TEMP_SAFE_LOW: int  = 72
const TEMP_SAFE_HIGH: int = 88

const ROW_TEMP_BONUS: Array = [8, 6, 4, 2, 1, 0]

const TIME_NAMES: Array = ["Dawn 🌅", "Day ☀️", "Dusk 🌇", "Night 🌙"]

# Atmosphere: modulate applied to the whole grid node each time-of-day phase
# These multiply with tile colors — warm at dawn/dusk, bright at day, cool/dark at night
const ATMOSPHERE: Array = [
	Color(1.15, 0.88, 0.62),   # Dawn  — warm amber
	Color(1.05, 1.05, 0.97),   # Day   — clean bright
	Color(1.10, 0.72, 0.42),   # Dusk  — deep orange
	Color(0.48, 0.52, 0.82),   # Night — cool blue
]

const ROW_LABELS: Array = ["Top", "  ↕ ", "Mid", "  ↕ ", "Bot", "Sub"]

# --- UI Nodes ---
var name_screen: Control
var name_input: LineEdit
var game_screen: Control
var grid_node: Control       # The left VBox; modulate tweened for atmosphere

var day_label: Label
var time_label: Label
var hunger_label: Label
var hydration_label: Label
var base_temp_label: Label
var felt_temp_label: Label
var humidity_label: Label
var position_label: Label
var plant_label: Label
var cricket_label: Label
var isopod_label: Label
var status_label: Label
var calcium_label: Label
var help_screen: Control
var help_button: Button
var add_crickets_button: Button
var dust_button: Button
var water_button: Button
var lamp_button: Button
var mist_button: Button
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
	# Set initial atmosphere without tweening
	grid_node.modulate = ATMOSPHERE[time_of_day]
	_spawn_isopods(5)
	_log("Day 1 — %s: %s moves in. A pothos sits in the corner. 5 isopods settle into the substrate." % [TIME_NAMES[time_of_day], gecko_name])
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
	_build_log_column(hbox)
	_build_help_screen()


func _build_grid_column(parent: Node) -> void:
	grid_node = VBoxContainer.new()
	grid_node.alignment = BoxContainer.ALIGNMENT_CENTER
	grid_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid_node)

	var grid_title = Label.new()
	grid_title.text = "Enclosure"
	grid_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid_node.add_child(grid_title)

	var grid_row = HBoxContainer.new()
	grid_row.alignment = BoxContainer.ALIGNMENT_CENTER
	grid_row.add_theme_constant_override("separation", 4)
	grid_node.add_child(grid_row)

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


func _build_log_column(parent: Node) -> void:
	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	parent.add_child(col)

	var log_title = Label.new()
	log_title.text = "=== Turn Log ==="
	log_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(log_title)

	col.add_child(HSeparator.new())

	log_scroll = ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(log_scroll)

	log_container = VBoxContainer.new()
	log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_container.add_theme_constant_override("separation", 4)
	log_scroll.add_child(log_container)


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

	time_label = Label.new()
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(time_label)

	right.add_child(HSeparator.new())

	hunger_label    = Label.new(); right.add_child(hunger_label)
	hydration_label = Label.new(); right.add_child(hydration_label)
	calcium_label   = Label.new(); right.add_child(calcium_label)
	position_label  = Label.new(); right.add_child(position_label)
	felt_temp_label = Label.new(); right.add_child(felt_temp_label)
	base_temp_label = Label.new(); right.add_child(base_temp_label)
	humidity_label  = Label.new(); right.add_child(humidity_label)

	right.add_child(HSeparator.new())

	plant_label   = Label.new(); right.add_child(plant_label)
	cricket_label = Label.new(); right.add_child(cricket_label)
	isopod_label  = Label.new(); right.add_child(isopod_label)

	right.add_child(HSeparator.new())

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_child(status_label)

	right.add_child(HSeparator.new())

	help_button = Button.new()
	help_button.text = "? How to Play"
	help_button.pressed.connect(_on_help_pressed)
	right.add_child(help_button)

	right.add_child(HSeparator.new())

	add_crickets_button = Button.new()
	add_crickets_button.text = "Add Crickets 🦗  (drop 3 in enclosure)"
	add_crickets_button.pressed.connect(_on_add_crickets_pressed)
	right.add_child(add_crickets_button)

	dust_button = Button.new()
	dust_button.pressed.connect(_on_dust_pressed)
	right.add_child(dust_button)

	water_button = Button.new()
	water_button.text = "Give Water  (+30 hydration)"
	water_button.pressed.connect(_on_water_pressed)
	right.add_child(water_button)

	lamp_button = Button.new()
	lamp_button.pressed.connect(_on_lamp_pressed)
	right.add_child(lamp_button)

	mist_button = Button.new()
	mist_button.text = "Mist Enclosure 💧  (+moisture +humidity)"
	mist_button.pressed.connect(_on_mist_pressed)
	right.add_child(mist_button)

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


# ══════════════════════════════════════════════════════════════
# BUTTON HANDLERS
# ══════════════════════════════════════════════════════════════

func _on_add_crickets_pressed() -> void:
	if not alive: return
	var spawned = _spawn_crickets(3)
	var dust_note = " (dusted with calcium 🧂)" if dust_mode else ""
	_log("You dropped %d cricket%s into the enclosure%s." % [spawned, "s" if spawned != 1 else "", dust_note])
	_update_display()

func _on_dust_pressed() -> void:
	if not alive: return
	dust_mode = not dust_mode
	_log("Cricket dusting %s." % ("ON — next crickets will carry calcium" if dust_mode else "OFF"))
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

func _on_mist_pressed() -> void:
	if not alive: return
	humidity = min(100, humidity + 20)
	if plant_alive:
		plant_moisture = min(100, plant_moisture + 40)
		_log("You misted the enclosure.  Humidity → %d, plant moisture → %d" % [humidity, plant_moisture])
	else:
		_log("You misted the enclosure.  Humidity → %d" % humidity)
	_update_display()

func _on_end_turn_pressed() -> void:
	if not alive: return

	var prev_time = time_of_day
	time_of_day = (time_of_day + 1) % 4
	if time_of_day != prev_time:
		_log("— %s —" % TIME_NAMES[time_of_day])
		_tween_atmosphere(ATMOSPHERE[prev_time], ATMOSPHERE[time_of_day])

	day      += 1
	var waste_key    = "%d,%d" % [gecko_x, gecko_y]
	var waste_stress = 10 if waste.get(waste_key, 0) >= WASTE_STRESS_THRESHOLD else 0
	hunger    = max(0, hunger - 20 - waste_stress)
	var thirst_drain = 25 + (10 if humidity < 40 else 0)
	hydration = max(0, hydration - thirst_drain)
	calcium   = max(0, calcium - 5)
	if lamp_on:
		temperature = min(TEMP_MAX, temperature + 5)
	else:
		temperature = max(TEMP_MIN, temperature - 5)
	humidity = max(0, humidity - 8)

	var old_x = gecko_x
	var old_y = gecko_y
	_move_gecko()
	var caught = _gecko_hunt()
	_gecko_produce_waste()
	_advance_isopods()
	_advance_plant()
	_age_crickets()

	var felt = _felt_temp()
	var events: Array = []
	if hunger    == 0:        events.append("starved")
	if hydration == 0:        events.append("dehydrated")
	if calcium   == 0:        events.append("calcium deficiency")
	if felt <= TEMP_MIN:      events.append("froze")
	if felt >= TEMP_MAX:      events.append("overheated")

	if events.size() > 0:
		alive = false
		_log("Day %d: %s %s — game over." % [day, gecko_name, ", ".join(events)])
	else:
		var summary = "Day %d: hunger %d, hydration %d, felt temp %d°F, humidity %d%%." \
			% [day, hunger, hydration, felt, humidity]
		if _has_warnings():
			summary += "  ⚠ Needs attention!"
		_log(summary)

	_update_display()
	_animate_gecko_tile(gecko_x, gecko_y, caught)

func _on_restart_pressed() -> void:
	hunger         = 100
	hydration      = 100
	temperature    = 72
	lamp_on        = true
	humidity       = 65
	time_of_day    = 0
	day            = 1
	alive          = true
	gecko_x        = 1
	gecko_y        = 2
	plant_health   = 100
	plant_moisture = 60
	plant_alive    = true
	crickets.clear()
	isopods.clear()
	waste.clear()
	calcium   = 100
	dust_mode = false
	grid_node.modulate = ATMOSPHERE[0]
	_spawn_isopods(5)
	for child in log_container.get_children():
		child.queue_free()
	_log("New game. Good luck, %s!" % gecko_name)
	_update_display()


func _on_help_pressed() -> void:
	help_screen.show()

func _on_help_close_pressed() -> void:
	help_screen.hide()


# ══════════════════════════════════════════════════════════════
# HELP SCREEN
# ══════════════════════════════════════════════════════════════

func _build_help_screen() -> void:
	# Full-screen dimmed overlay
	help_screen = Control.new()
	help_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_screen.add_child(help_screen)

	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.72)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	help_screen.add_child(bg)

	# Panel fills the screen with a fixed inset so it never overflows
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left   =  60
	panel.offset_right  = -60
	panel.offset_top    =  40
	panel.offset_bottom = -40
	help_screen.add_child(panel)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   28)
	margin.add_theme_constant_override("margin_right",  28)
	margin.add_theme_constant_override("margin_top",    20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Title row
	var title_row = HBoxContainer.new()
	vbox.add_child(title_row)

	var title = Label.new()
	title.text = "How to Play — Gecko Enclosure Simulator"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "✕  Close"
	close_btn.pressed.connect(_on_help_close_pressed)
	title_row.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	# Scrollable two-column content
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var cols = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cols)

	_help_column(cols, [
		["STATS", ""],
		["Hunger", "Drops 20/turn. Gecko hunts crickets automatically. Hits 0 = game over."],
		["Hydration", "Drops 25/turn (more when humidity is low). Use Give Water. Hits 0 = game over."],
		["Calcium", "Drops 5/turn. Replenished only by dusted crickets. Hits 0 = game over."],
		["Felt Temp", "What the gecko actually feels based on its row. Keep between 72–88°F."],
		["Base Temp", "Ambient temp at the bottom. Lamp ON = +5°F/turn. Lamp OFF = -5°F/turn."],
		["Humidity", "Drops 8/turn. Below 30% isopods start dying and gecko gets thirstier."],
		["Pothos", "Needs moisture 20–80. Too dry or waterlogged = health loss."],
		["Crickets", "Crickets die after 5 turns if not eaten. Add fresh ones regularly."],
		["Isopods", "Clean up waste. Reproduce slowly in good humidity. Die in dry conditions."],
	])

	_help_column(cols, [
		["ACTIONS", ""],
		["Add Crickets 🦗", "Drops 3 crickets on random tiles. Gecko hunts them automatically."],
		["Cricket Dusting 🧂", "Toggle ON before adding crickets to coat them with calcium powder."],
		["Give Water", "Directly adds +30 hydration to the gecko."],
		["Heat Lamp", "Toggle to control base temperature. Watch felt temp, not just base."],
		["Mist Enclosure 💧", "Adds +20 humidity and +40 plant moisture. Do this every 2–3 turns."],
		["End Turn", "Advances one day. Gecko moves, eats, climate updates, plants grow."],
		["GRID SYMBOLS", ""],
		["🦎  Gecko", "Moves automatically. Hunts crickets. Thermoregulates by row."],
		["🌱 / 🍂  Plant", "Healthy pothos / dead pothos."],
		["🦗  Cricket", "Food. Dusted ones glow — check the log when gecko eats."],
		["🪲  Isopod", "Cleanup crew in the substrate. Keep humidity up to keep them alive."],
		["💩  Waste", "Gecko stress if standing here. Isopods will clean it up."],
	])

	help_screen.hide()


func _help_column(parent: Node, rows: Array) -> void:
	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	parent.add_child(col)

	for row in rows:
		if row[0] in ["STATS", "ACTIONS", "GRID SYMBOLS"]:
			var sep = HSeparator.new()
			col.add_child(sep)
			var heading = Label.new()
			heading.text = row[0]
			col.add_child(heading)
			col.add_child(HSeparator.new())
		else:
			var hbox = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 8)
			col.add_child(hbox)

			var key_lbl = Label.new()
			key_lbl.text = row[0]
			key_lbl.custom_minimum_size = Vector2(160, 0)
			hbox.add_child(key_lbl)

			var val_lbl = Label.new()
			val_lbl.text = row[1]
			val_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(val_lbl)


# ══════════════════════════════════════════════════════════════
# ANIMATIONS
# ══════════════════════════════════════════════════════════════

func _tween_atmosphere(from: Color, to: Color) -> void:
	# Smoothly shift the grid's overall tint between time-of-day phases
	var tween = create_tween()
	tween.tween_property(grid_node, "modulate", from, 0.0)  # snap to old first
	tween.tween_property(grid_node, "modulate", to,   0.8)  # fade to new over 0.8s

func _animate_gecko_tile(x: int, y: int, caught_cricket: bool) -> void:
	var panel = tile_panels[y * GRID_COLS + x]
	var tween = create_tween()
	if caught_cricket:
		# Bright yellow-white burst then settle
		tween.tween_property(panel, "modulate", Color(2.5, 2.2, 0.4), 0.08)
		tween.tween_property(panel, "modulate", Color(1.0, 1.0, 1.0), 0.35)
	else:
		# Soft white pulse for movement arrival
		tween.tween_property(panel, "modulate", Color(1.8, 1.8, 1.8), 0.08)
		tween.tween_property(panel, "modulate", Color(1.0, 1.0, 1.0), 0.25)


# ══════════════════════════════════════════════════════════════
# CLIMATE
# ══════════════════════════════════════════════════════════════

func _felt_temp() -> int:
	return temperature + ROW_TEMP_BONUS[gecko_y]

func _humidity_desc() -> String:
	if humidity < 30: return "very dry ⚠"
	if humidity < 50: return "dry"
	if humidity > 85: return "very humid"
	return "good"


# ══════════════════════════════════════════════════════════════
# CRICKET LOGIC
# ══════════════════════════════════════════════════════════════

func _spawn_crickets(count: int) -> int:
	var spawned = 0
	var attempts = 0
	while spawned < count and attempts < 30:
		attempts += 1
		var x = randi() % GRID_COLS
		var y = randi() % GRID_ROWS
		if x == gecko_x and y == gecko_y: continue
		if x == PLANT_X  and y == PLANT_Y:  continue
		if _cricket_at(x, y) != -1: continue
		crickets.append({"x": x, "y": y, "age": 0, "dusted": dust_mode})
		spawned += 1
	return spawned

func _cricket_at(x: int, y: int) -> int:
	for i in range(crickets.size()):
		if crickets[i].x == x and crickets[i].y == y:
			return i
	return -1

func _gecko_hunt() -> bool:
	var idx = _cricket_at(gecko_x, gecko_y)
	if idx != -1:
		var was_dusted = crickets[idx].get("dusted", false)
		crickets.remove_at(idx)
		hunger = min(100, hunger + CRICKET_HUNGER_RESTORE)
		if was_dusted:
			calcium = min(100, calcium + CRICKET_CALCIUM_RESTORE)
			_log("%s caught a dusted cricket! 🦗🧂  Hunger → %d  Calcium → %d" % [gecko_name, hunger, calcium])
		else:
			_log("%s caught a cricket! 🦗  Hunger → %d" % [gecko_name, hunger])
		return true
	return false

func _age_crickets() -> void:
	var died = 0
	var i = crickets.size() - 1
	while i >= 0:
		crickets[i].age += 1
		if crickets[i].age >= CRICKET_LIFESPAN:
			crickets.remove_at(i)
			died += 1
		i -= 1
	if died > 0:
		_log("%d cricket%s died of old age." % [died, "s" if died > 1 else ""])


# ══════════════════════════════════════════════════════════════
# ISOPOD & WASTE LOGIC
# ══════════════════════════════════════════════════════════════

func _spawn_isopods(count: int) -> void:
	for _i in range(count):
		var x = randi() % GRID_COLS
		var y = GRID_ROWS - 1   # substrate row
		isopods.append({"x": x, "y": y, "age": 0})

func _gecko_produce_waste() -> void:
	var key = "%d,%d" % [gecko_x, gecko_y]
	waste[key] = min(100, waste.get(key, 0) + GECKO_WASTE_PER_TURN)

func _advance_isopods() -> void:
	var died = 0

	for iso in isopods:
		# Eat waste on current tile
		var key = "%d,%d" % [iso.x, iso.y]
		if waste.get(key, 0) > 0:
			waste[key] = max(0, waste[key] - ISOPOD_EAT_AMOUNT)
			if waste[key] == 0:
				waste.erase(key)

		# Move — prefer adjacent tiles with waste, else random in bottom 2 rows
		var best_dir  = Vector2i(0, 0)
		var best_waste = -1
		var dirs = [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]
		dirs.shuffle()
		for d in dirs:
			var nx = iso.x + d.x
			var ny = iso.y + d.y
			if nx >= 0 and nx < GRID_COLS and ny >= GRID_ROWS - 2 and ny < GRID_ROWS:
				var w = waste.get("%d,%d" % [nx, ny], 0)
				if w > best_waste:
					best_waste = w
					best_dir   = d
		if best_dir != Vector2i(0, 0):
			iso.x += best_dir.x
			iso.y += best_dir.y

		iso.age += 1

	# Remove dead isopods (old age or dry conditions)
	var i = isopods.size() - 1
	while i >= 0:
		var iso = isopods[i]
		var dies_of_age = iso.age >= ISOPOD_MAX_AGE
		var dies_of_dryness = humidity < 30 and randf() < 0.3
		if dies_of_age or dies_of_dryness:
			isopods.remove_at(i)
			died += 1
		i -= 1

	if died > 0:
		_log("%d isopod%s died." % [died, "s" if died > 1 else ""])

	# Slow reproduction if conditions are good
	if isopods.size() > 0 and isopods.size() < 12 and humidity >= 50 and randf() < 0.35:
		_spawn_isopods(1)

	# Warn if waste is building up somewhere
	for k in waste:
		if waste[k] >= WASTE_STRESS_THRESHOLD:
			var parts = k.split(",")
			if int(parts[0]) == gecko_x and int(parts[1]) == gecko_y:
				_log("Waste is building up where %s is standing! 💩  Stress +10 hunger drain." % gecko_name)
				break


# ══════════════════════════════════════════════════════════════
# PLANT LOGIC
# ══════════════════════════════════════════════════════════════

func _advance_plant() -> void:
	if not plant_alive: return
	plant_moisture = max(0, plant_moisture - 15)
	if humidity > 60:
		plant_moisture = min(100, plant_moisture + 3)
	var light_bonus = 0
	if time_of_day == 1:                         light_bonus = 3
	elif time_of_day == 0 or time_of_day == 2:   light_bonus = 1
	if plant_moisture < 20:
		plant_health = max(0, plant_health - 10)
		_log("The pothos is drying out!  Health → %d" % plant_health)
	elif plant_moisture > 80:
		plant_health = max(0, plant_health - 3)
		_log("The pothos is waterlogged.  Health → %d" % plant_health)
	else:
		plant_health = min(100, plant_health + 2 + light_bonus)
	if plant_health == 0:
		plant_alive = false
		_log("The pothos has died. 🍂")


# ══════════════════════════════════════════════════════════════
# GECKO MOVEMENT
# ══════════════════════════════════════════════════════════════

func _move_gecko() -> void:
	var dirs = [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]

	# Adjacent cricket — always move to it
	for d in dirs:
		var nx = gecko_x + d.x
		var ny = gecko_y + d.y
		if nx >= 0 and nx < GRID_COLS and ny >= 0 and ny < GRID_ROWS:
			if _cricket_at(nx, ny) != -1:
				gecko_x = nx
				gecko_y = ny
				return

	# Thermoregulate: too hot → move down, too cold → move up
	var felt = _felt_temp()
	if felt > TEMP_SAFE_HIGH and gecko_y < GRID_ROWS - 1:
		gecko_y += 1
		return
	if felt < TEMP_SAFE_LOW and gecko_y > 0:
		gecko_y -= 1
		return

	# Bias toward nearest cricket (70%)
	var nearest = _nearest_cricket()
	if nearest != Vector2i(-1, -1) and randf() < 0.7:
		var best_dir = Vector2i(0, 0)
		var best_dist = INF
		for d in dirs:
			var nx = gecko_x + d.x
			var ny = gecko_y + d.y
			if nx >= 0 and nx < GRID_COLS and ny >= 0 and ny < GRID_ROWS:
				var dist = abs(nx - nearest.x) + abs(ny - nearest.y)
				if dist < best_dist:
					best_dist = dist
					best_dir  = d
		if best_dir != Vector2i(0, 0):
			gecko_x += best_dir.x
			gecko_y += best_dir.y
			return

	# Random wander
	dirs.shuffle()
	for d in dirs:
		var nx = gecko_x + d.x
		var ny = gecko_y + d.y
		if nx >= 0 and nx < GRID_COLS and ny >= 0 and ny < GRID_ROWS:
			gecko_x = nx
			gecko_y = ny
			break

func _nearest_cricket() -> Vector2i:
	var best = Vector2i(-1, -1)
	var best_dist = INF
	for c in crickets:
		var dist = abs(gecko_x - c.x) + abs(gecko_y - c.y)
		if dist < best_dist:
			best_dist = dist
			best = Vector2i(c.x, c.y)
	return best


# ══════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════

func _log(text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_container.add_child(lbl)
	await get_tree().process_frame
	log_scroll.scroll_vertical = log_scroll.get_v_scroll_bar().max_value

func _has_warnings() -> bool:
	var felt = _felt_temp()
	return hunger < 30 or hydration < 30 or calcium < 30 \
		or felt < TEMP_SAFE_LOW or felt > TEMP_SAFE_HIGH \
		or humidity < 30 \
		or (plant_alive and plant_moisture < 20) \
		or (crickets.is_empty() and hunger < 50)

func _isopod_at(x: int, y: int) -> bool:
	for iso in isopods:
		if iso.x == x and iso.y == y:
			return true
	return false

func _tile_emoji(x: int, y: int) -> String:
	var parts: Array = []
	if x == gecko_x and y == gecko_y:                     parts.append("🦎")
	if plant_alive  and x == PLANT_X and y == PLANT_Y:    parts.append("🌱")
	if not plant_alive and x == PLANT_X and y == PLANT_Y: parts.append("🍂")
	if _cricket_at(x, y) != -1:                           parts.append("🦗")
	if _isopod_at(x, y):                                  parts.append("🪲")
	var w = waste.get("%d,%d" % [x, y], 0)
	if w >= WASTE_STRESS_THRESHOLD:                        parts.append("💩")
	return "".join(parts)

func _tile_color(x: int, y: int) -> Color:
	if x == gecko_x and y == gecko_y:
		return Color(0.25, 0.50, 0.15)
	if plant_alive and x == PLANT_X and y == PLANT_Y:
		var t = plant_health / 100.0
		return Color(0.10 + 0.15 * t, 0.30 + 0.20 * t, 0.08)
	if y == GRID_ROWS - 1:  return Color(0.22, 0.14, 0.06)
	if y >= GRID_ROWS - 3:  return Color(0.20, 0.16, 0.10)
	if y >= 2:              return Color(0.18, 0.20, 0.14)
	return Color(0.20, 0.22, 0.18)

func _make_stylebox(color: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_border_width_all(1)
	s.border_color = Color(0.45, 0.32, 0.18)
	return s

func _plant_status_text() -> String:
	if not plant_alive:
		return "Pothos:      dead 🍂"
	var desc: String
	if plant_moisture < 20:   desc = "bone dry ⚠"
	elif plant_moisture < 40: desc = "dry"
	elif plant_moisture > 80: desc = "waterlogged"
	else:                     desc = "good"
	return "Pothos:      health %d  moisture %d (%s)" % [plant_health, plant_moisture, desc]

func _update_display() -> void:
	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			var idx = y * GRID_COLS + x
			tile_panels[idx].add_theme_stylebox_override("panel", _make_stylebox(_tile_color(x, y)))
			tile_labels[idx].text = _tile_emoji(x, y)

	var felt  = _felt_temp()
	var layer: String
	if gecko_y <= 1:   layer = "top"
	elif gecko_y <= 3: layer = "middle"
	elif gecko_y == 4: layer = "bottom"
	else:              layer = "substrate"

	day_label.text       = "Day %d  —  %s" % [day, gecko_name]
	time_label.text      = TIME_NAMES[time_of_day]
	hunger_label.text    = "Hunger:      %d / 100" % hunger
	hydration_label.text = "Hydration:   %d / 100" % hydration
	calcium_label.text   = "Calcium:     %d / 100%s" % [calcium, "  ⚠" if calcium < 30 else ""]
	dust_button.text     = "Cricket Dusting:  %s" % ("ON 🧂 (next crickets carry calcium)" if dust_mode else "OFF")
	position_label.text  = "Location:    col %d, %s layer" % [gecko_x, layer]
	felt_temp_label.text = "Felt temp:   %d°F  (safe %d–%d)" % [felt, TEMP_SAFE_LOW, TEMP_SAFE_HIGH]
	base_temp_label.text = "Base temp:   %d°F  lamp %s" % [temperature, "ON" if lamp_on else "OFF"]
	humidity_label.text  = "Humidity:    %d%%  (%s)" % [humidity, _humidity_desc()]
	lamp_button.text     = "Heat Lamp:  %s" % ("ON  🔆" if lamp_on else "OFF  🌑")
	plant_label.text     = _plant_status_text()
	cricket_label.text   = "Crickets:    %d in enclosure" % crickets.size()
	var total_waste = 0
	for w in waste.values(): total_waste += w
	var waste_desc = "none" if total_waste == 0 else ("low" if total_waste < 40 else ("moderate" if total_waste < 100 else "high ⚠"))
	isopod_label.text    = "Isopods:     %d in colony  |  Waste: %s" % [isopods.size(), waste_desc]

	var warnings: Array = []
	if hunger    < 30:                          warnings.append("hungry")
	if hydration < 30:                          warnings.append("thirsty")
	if calcium   < 30:                          warnings.append("low calcium")
	if felt      < TEMP_SAFE_LOW:               warnings.append("too cold")
	if felt      > TEMP_SAFE_HIGH:              warnings.append("too hot")
	if humidity  < 30:                          warnings.append("air too dry")
	if plant_alive and plant_moisture < 20:     warnings.append("plant needs water")
	if crickets.is_empty() and hunger < 50:     warnings.append("no crickets in enclosure")
	if isopods.is_empty():                      warnings.append("no isopods — waste will build up")
	var gecko_waste = waste.get("%d,%d" % [gecko_x, gecko_y], 0)
	if gecko_waste >= WASTE_STRESS_THRESHOLD:   warnings.append("gecko standing in waste")

	if not alive:
		status_label.text              = "%s didn't make it. Try again!" % gecko_name
		add_crickets_button.disabled   = true
		dust_button.disabled           = true
		water_button.disabled          = true
		lamp_button.disabled           = true
		mist_button.disabled           = true
		end_turn_button.disabled       = true
		restart_button.show()
	elif warnings.size() > 0:
		status_label.text = "Warning: %s!" % ", ".join(warnings)
	else:
		status_label.text              = "%s is doing well." % gecko_name
		add_crickets_button.disabled   = false
		dust_button.disabled           = false
		water_button.disabled          = false
		lamp_button.disabled           = false
		mist_button.disabled           = false
		end_turn_button.disabled       = false
		restart_button.hide()
