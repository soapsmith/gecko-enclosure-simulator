extends Control

# --- Game State ---
var gecko_name: String = "Gecko"
var hunger: int      = 100
var hydration: int   = 100
var temperature: int = 72   # Base ambient temp (bottom of enclosure)
var lamp_on: bool    = true
var humidity: int    = 65   # Global humidity 0-100
var time_of_day: int = 0    # 0=Dawn 1=Day 2=Dusk 3=Night, cycles each turn
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
const CRICKET_LIFESPAN: int      = 5
const CRICKET_HUNGER_RESTORE: int = 25

const GRID_COLS: int = 4
const GRID_ROWS: int = 6

const TEMP_MIN: int      = 65
const TEMP_MAX: int      = 95
const TEMP_SAFE_LOW: int  = 72
const TEMP_SAFE_HIGH: int = 88

# How much warmer each row feels vs the base temp (heat rises, lamp at top)
# Index 0 = top row, index 5 = substrate
const ROW_TEMP_BONUS: Array = [8, 6, 4, 2, 1, 0]

const TIME_NAMES:  Array = ["Dawn 🌅", "Day ☀️", "Dusk 🌇", "Night 🌙"]

const ROW_LABELS: Array = ["Top", "  ↕ ", "Mid", "  ↕ ", "Bot", "Sub"]

# --- UI Nodes ---
var name_screen: Control
var name_input: LineEdit
var game_screen: Control

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
var status_label: Label
var add_crickets_button: Button
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
	_log("Day 1 — %s: %s moves in. A pothos sits in the corner." % [TIME_NAMES[time_of_day], gecko_name])
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
	position_label  = Label.new(); right.add_child(position_label)
	felt_temp_label = Label.new(); right.add_child(felt_temp_label)
	base_temp_label = Label.new(); right.add_child(base_temp_label)
	humidity_label  = Label.new(); right.add_child(humidity_label)

	right.add_child(HSeparator.new())

	plant_label   = Label.new(); right.add_child(plant_label)
	cricket_label = Label.new(); right.add_child(cricket_label)

	right.add_child(HSeparator.new())

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_child(status_label)

	right.add_child(HSeparator.new())

	add_crickets_button = Button.new()
	add_crickets_button.text = "Add Crickets 🦗  (drop 3 in enclosure)"
	add_crickets_button.pressed.connect(_on_add_crickets_pressed)
	right.add_child(add_crickets_button)

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
	_log("You dropped %d cricket%s into the enclosure." % [spawned, "s" if spawned != 1 else ""])
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

	# Advance time of day and announce phase changes
	var prev_time = time_of_day
	time_of_day = (time_of_day + 1) % 4
	if time_of_day != prev_time:
		_log("— %s —" % TIME_NAMES[time_of_day])

	day      += 1
	hunger    = max(0, hunger    - 20)

	# Dry air makes the gecko thirstier
	var thirst_drain = 25 + (10 if humidity < 40 else 0)
	hydration = max(0, hydration - thirst_drain)

	# Lamp raises base temp; it cools overnight without it
	if lamp_on:
		temperature = min(TEMP_MAX, temperature + 5)
	else:
		temperature = max(TEMP_MIN, temperature - 5)

	# Humidity drops naturally each turn
	humidity = max(0, humidity - 8)

	_move_gecko()
	_gecko_hunt()
	_advance_plant()
	_age_crickets()

	# Gecko's felt temp depends on its row
	var felt = _felt_temp()
	var events: Array = []
	if hunger      == 0:           events.append("starved")
	if hydration   == 0:           events.append("dehydrated")
	if felt        <= TEMP_MIN:    events.append("froze")
	if felt        >= TEMP_MAX:    events.append("overheated")

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
	for child in log_container.get_children():
		child.queue_free()
	_log("New game. Good luck, %s!" % gecko_name)
	_update_display()


# ══════════════════════════════════════════════════════════════
# CLIMATE
# ══════════════════════════════════════════════════════════════

func _felt_temp() -> int:
	# Gecko feels the base temp plus the warmth bonus of its current row
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
		crickets.append({"x": x, "y": y, "age": 0})
		spawned += 1
	return spawned

func _cricket_at(x: int, y: int) -> int:
	for i in range(crickets.size()):
		if crickets[i].x == x and crickets[i].y == y:
			return i
	return -1

func _gecko_hunt() -> void:
	var idx = _cricket_at(gecko_x, gecko_y)
	if idx != -1:
		crickets.remove_at(idx)
		hunger = min(100, hunger + CRICKET_HUNGER_RESTORE)
		_log("%s caught a cricket! 🦗  Hunger → %d" % [gecko_name, hunger])

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
# PLANT LOGIC
# ══════════════════════════════════════════════════════════════

func _advance_plant() -> void:
	if not plant_alive: return

	plant_moisture = max(0, plant_moisture - 15)

	# High humidity slows drying a little
	if humidity > 60:
		plant_moisture = min(100, plant_moisture + 3)

	# Light bonus during Day phase
	var light_bonus = 0
	if time_of_day == 1:    light_bonus = 3   # full day
	elif time_of_day == 0 or time_of_day == 2:
		light_bonus = 1                        # dawn / dusk

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

	# Thermoregulation: if too hot move down, if too cold move up
	var felt = _felt_temp()
	if felt > TEMP_SAFE_HIGH and gecko_y < GRID_ROWS - 1:
		gecko_y += 1
		return
	if felt < TEMP_SAFE_LOW and gecko_y > 0:
		gecko_y -= 1
		return

	# Bias toward nearest cricket (70% chance)
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
	return hunger < 30 or hydration < 30 \
		or felt < TEMP_SAFE_LOW or felt > TEMP_SAFE_HIGH \
		or humidity < 30 \
		or (plant_alive and plant_moisture < 20) \
		or (crickets.is_empty() and hunger < 50)

func _tile_emoji(x: int, y: int) -> String:
	var parts: Array = []
	if x == gecko_x and y == gecko_y:                    parts.append("🦎")
	if plant_alive  and x == PLANT_X and y == PLANT_Y:   parts.append("🌱")
	if not plant_alive and x == PLANT_X and y == PLANT_Y: parts.append("🍂")
	if _cricket_at(x, y) != -1:                           parts.append("🦗")
	return "".join(parts)

func _tile_color(x: int, y: int) -> Color:
	if x == gecko_x and y == gecko_y:
		return Color(0.25, 0.50, 0.15)
	if plant_alive and x == PLANT_X and y == PLANT_Y:
		var t = plant_health / 100.0
		return Color(0.10 + 0.15 * t, 0.30 + 0.20 * t, 0.08)
	# Night darkens the top rows slightly
	var night_dim = 0.04 if time_of_day == 3 else 0.0
	if y == GRID_ROWS - 1:  return Color(0.22, 0.14, 0.06)
	if y >= GRID_ROWS - 3:  return Color(0.20, 0.16, 0.10)
	if y >= 2:              return Color(0.18, 0.20 - night_dim, 0.14)
	return Color(0.20, 0.22 - night_dim, 0.18)

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
	# Grid
	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			var idx = y * GRID_COLS + x
			tile_panels[idx].add_theme_stylebox_override("panel", _make_stylebox(_tile_color(x, y)))
			tile_labels[idx].text = _tile_emoji(x, y)

	var felt = _felt_temp()
	var layer: String
	if gecko_y <= 1:   layer = "top"
	elif gecko_y <= 3: layer = "middle"
	elif gecko_y == 4: layer = "bottom"
	else:              layer = "substrate"

	day_label.text      = "Day %d  —  %s" % [day, gecko_name]
	time_label.text     = TIME_NAMES[time_of_day]
	hunger_label.text   = "Hunger:      %d / 100" % hunger
	hydration_label.text = "Hydration:   %d / 100" % hydration
	position_label.text = "Location:    col %d, %s layer" % [gecko_x, layer]
	felt_temp_label.text = "Felt temp:   %d°F  (safe %d–%d)" % [felt, TEMP_SAFE_LOW, TEMP_SAFE_HIGH]
	base_temp_label.text = "Base temp:   %d°F  lamp %s" % [temperature, "ON" if lamp_on else "OFF"]
	humidity_label.text  = "Humidity:    %d%%  (%s)" % [humidity, _humidity_desc()]
	lamp_button.text     = "Heat Lamp:  %s" % ("ON  🔆" if lamp_on else "OFF  🌑")
	plant_label.text     = _plant_status_text()
	cricket_label.text   = "Crickets:    %d in enclosure" % crickets.size()
	mist_button.disabled = false

	# Warnings
	var warnings: Array = []
	if hunger      < 30:                          warnings.append("hungry")
	if hydration   < 30:                          warnings.append("thirsty")
	if felt        < TEMP_SAFE_LOW:               warnings.append("too cold")
	if felt        > TEMP_SAFE_HIGH:              warnings.append("too hot")
	if humidity    < 30:                          warnings.append("air too dry")
	if plant_alive and plant_moisture < 20:       warnings.append("plant needs water")
	if crickets.is_empty() and hunger < 50:       warnings.append("no crickets in enclosure")

	if not alive:
		status_label.text              = "%s didn't make it. Try again!" % gecko_name
		add_crickets_button.disabled   = true
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
		water_button.disabled          = false
		lamp_button.disabled           = false
		end_turn_button.disabled       = false
		restart_button.hide()
