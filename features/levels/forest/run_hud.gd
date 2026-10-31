extends Control
signal perks_closed
var world: Node
var modal_kind = ""
var field_notes = "Survey the forest."
var refuge_ready = false
var current_fire_hazard = 0.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Modal/Rows/Close.pressed.connect(close_modal)
	$Modal/Rows/Next.pressed.connect(func(): close_modal(); SceneFlow.retry_game())
	$Modal/Rows/Menu.pressed.connect(func(): close_modal(); SceneFlow.main_menu())
	$Modal/Rows/QuickChop.pressed.connect(func(): _purchase("quick_chop"))
	$Modal/Rows/FireResilience.pressed.connect(func(): _purchase("fire_resilience"))
	$Modal/Rows/Upgrade.pressed.connect(func():
		if SaveManager.purchase_heat_resistance():
			notify("Heat Resistance purchased permanently")
		show_modal(modal_kind))

func _input(event):
	if $Modal.visible and event.is_action_pressed("pause"):
		if modal_kind in ["bonfire","perks"]:
			close_modal()
		get_viewport().set_input_as_handled()

func notify(message: String):
	$Toast.text = message
	$Toast/Timer.start()

func show_modal(kind: String):
	modal_kind = kind
	$Modal.show()
	$Dim.show()
	get_tree().paused = true
	$Modal/Rows/Title.text = {"bonfire": "Bonfire - safe shelter", "death": "The forest claimed this attempt", "success": "Wetlands refuge reached", "perks":"Perks"}[kind]
	$Modal/Rows/Progress.text = "Knowledge: %d | Discoveries: %d\nHeat Resistance: %s" % [SaveManager.progression.knowledge, SaveManager.progression.discoveries.size(), "Owned" if SaveManager.has_heat_resistance() else "Not purchased"]
	var names: PackedStringArray = []
	for id in SaveManager.progression.discoveries:
		names.append(id.get_slice(".", 1).replace("_", " ").capitalize())
	if not field_notes.is_empty(): $Modal/Rows/Progress.text += "\nField notes: " + field_notes
	$Modal/Rows/Progress.tooltip_text = "Discovered: " + (", ".join(names) if not names.is_empty() else "Explore to find something new")
	for pair in [["QuickChop", "quick_chop", "Quick Chop"], ["FireResilience", "fire_resilience", "Fire Resilience"]]:
		var button = get_node("Modal/Rows/" + pair[0])
		button.visible = kind in ["bonfire","perks"]
		button.disabled = SaveManager.has_upgrade(pair[1]) or SaveManager.progression.knowledge < SaveManager.upgrade_cost(pair[1])
		button.text = pair[2] + (" - Owned" if SaveManager.has_upgrade(pair[1]) else " - %d Knowledge" % SaveManager.upgrade_cost(pair[1]))
	$Modal/Rows/Upgrade.visible = kind in ["bonfire","perks"]
	$Modal/Rows/Upgrade.disabled = SaveManager.has_heat_resistance() or SaveManager.progression.knowledge < 3
	$Modal/Rows/Close.visible = kind in ["bonfire","perks"]
	$Modal/Rows/Close.text = "Back to Pause" if kind == "perks" else "Return to forest"
	$Modal/Rows/Next.visible = kind not in ["bonfire","perks"]
	if kind in ["bonfire","perks"]:
		$Modal/Rows/Close.grab_focus()
	else:
		$Modal/Rows/Next.grab_focus()

func close_modal():
	var from_pause = modal_kind == "perks"
	$Modal.hide()
	$Dim.hide()
	get_tree().paused = from_pause
	modal_kind = ""
	if from_pause: perks_closed.emit()

func _on_toast_timeout():
	$Toast.text = ""

func update_status(health: float, exposure: float, temperature: float, weather: String, trend: float, knowledge: int, safe: bool, chopping: bool, seeds: int = 0, water_ml: int = 500):
	$PlayerStatus/Rows/Health/Bar.value = health
	$PlayerStatus/Rows/Health/Value.text = str(roundi(health))
	$PlayerStatus/Rows/Heat/Bar.value = 37.0 + exposure / 30.0
	$PlayerStatus/Rows/Heat/Value.text = "%.1f°C" % (37.0 + exposure / 30.0)
	if has_node("PlayerStatus/Rows/Seeds/Value"):
		$PlayerStatus/Rows/Seeds/Value.text = str(seeds)
	if has_node("PlayerStatus/Rows/Water/Bar"):
		$PlayerStatus/Rows/Water/Bar.value = water_ml
	if has_node("PlayerStatus/Rows/Water/Value"):
		$PlayerStatus/Rows/Water/Value.text = "%d ml" % water_ml
	if has_node("PlayerStatus/Rows/Supplies/Seeds"):
		$PlayerStatus/Rows/Supplies/Seeds.text = str(seeds)
	$WorldStatus/Rows/Climate/Value.text = "%.1f C | %s" % [temperature, weather.capitalize()]
	$WorldStatus/Rows/Climate/Icon.set_weather(weather)
	$WorldStatus/Rows/Trend.text = "+%.1f C warming" % trend
	$WorldStatus/Rows/Knowledge/Value.text = "%d Knowledge" % knowledge
	$Context.text = "Chopping..." if chopping else "Bonfire shelter - Interact to rest" if safe else ""
	$Context.visible = not $Context.text.is_empty()

func damage_feedback(damaged: bool):
	$PlayerStatus/Rows/Health.modulate = Color(1, 0.55, 0.45) if damaged else Color.WHITE

func _purchase(id: String):
	if SaveManager.purchase_upgrade(id):
		notify("Permanent upgrade purchased")
	show_modal(modal_kind)

func set_environment_context(fire_hazard: float, notes: String, ready: bool):
	current_fire_hazard = fire_hazard
	field_notes = notes
	refuge_ready = ready
	$PlayerStatus/Rows/Heat/Icon.modulate = Color(1,0.4,0.2) if fire_hazard > 0 else Color.WHITE
	if fire_hazard > 0:
		$Context.text = "Fire nearby - seek wet ground or a cleared path"
		$Context.show()

func set_region(title: String):
	$WorldStatus/Rows/Region.text = title
	$WorldStatus/Rows/Region.tooltip_text = field_notes

func update_survival(state: RefCounted, canopy: float, eat_binding: String):
	$PlayerStatus/Rows/Heat/Bar.value = state.body_temperature
	$PlayerStatus/Rows/Heat/Value.text = "%.1f°C" % state.body_temperature
	$PlayerStatus/Rows/Heat.modulate = Color("e69e6a") if state.body_temperature >= 39.0 else Color("81bed9") if state.body_temperature <= 35.0 else Color.WHITE
	$PlayerStatus/Rows/Supplies/Food.text = str(roundi(state.hunger))
	$PlayerStatus/Rows/Supplies/Water.text = str(roundi(state.thirst))
	$PlayerStatus/Rows/Food.text = "Berries %d — [%s] Eat" % [state.berry_count, eat_binding]
	$PlayerStatus/Rows/Wetness.visible = state.wetness >= 1.0 or canopy > 0.05
	$PlayerStatus/Rows/Wetness.text = "Wet %d%%" % roundi(state.wetness) if state.wetness >= 1.0 else ""
	if canopy > 0.05:
		$PlayerStatus/Rows/Wetness.text += (" · " if state.wetness >= 1.0 else "") + "Canopy shelter"

func update_interaction(target: Dictionary, progress: float, active: bool, binding: String):
	$InteractionProgress.visible = active and float(target.get("duration", 0.0)) > 0.0
	$InteractionProgress.value = 100.0 * progress / maxf(float(target.get("duration", 1.0)), 0.01)
	if target.is_empty():
		$Context.text = "Fire nearby — seek shelter or a cleared path" if current_fire_hazard > 0.0 else ""
		$Context.visible = not $Context.text.is_empty()
		return
	var description = str(target.get("action", "Interact")) if target.get("available", true) else str(target.get("reason", "Unavailable"))
	$Context.show()
	$Context.text = "%s — [%s] %s%s" % [target.get("name", "Object"), binding, description, "..." if active else ""]

func update_seeds(count: int):
	$PlayerStatus/Rows/Supplies/Seeds.text = str(count)

func set_wind(state: Dictionary):
	var direction: Vector2 = state.direction
	var sector = posmod(roundi(atan2(direction.x,-direction.y)/(PI/4.0)),8)
	$WorldStatus/Rows/Knowledge/Wind.text = "Wind %s %d%%" % [["N","NE","E","SE","S","SW","W","NW"][sector],roundi(state.strength*100.0)]
