extends Control
signal perks_closed
var world: Node
var modal_kind = ""
var field_notes = "Survey the forest."
var refuge_ready = false
var current_fire_hazard = 0.0
var notification_queue: Array[Dictionary] = []
var notification_active: Array[Dictionary] = []
var notification_labels: Array[Label] = []
var notification_delay = 0.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Toast.hide()
	$Toast/Timer.stop()
	for i in range(3):
		var label = Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size",17)
		label.add_theme_color_override("font_outline_color",Color(0.02,0.03,0.02,0.95))
		label.add_theme_constant_override("outline_size",5)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(label)
		notification_labels.append(label)
	$Modal/Rows/Close.pressed.connect(close_modal)
	$Modal/Rows/Next.pressed.connect(func():
		close_modal()
		var flow = get_tree().root.get_node_or_null("SceneFlow") if get_tree() and get_tree().root else null
		if flow != null: flow.retry_game()
	)
	$Modal/Rows/Menu.pressed.connect(func():
		close_modal()
		var flow = get_tree().root.get_node_or_null("SceneFlow") if get_tree() and get_tree().root else null
		if flow != null: flow.main_menu()
	)
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

func notify(message: String, category: String = "normal"):
	if message.is_empty(): return
	if message.begins_with("Discovery:") or "Knowledge" in message: category = "important"
	for item in notification_queue+notification_active:
		if item.text == message: return
	if notification_queue.size() >= 24:
		var discard = -1
		for i in range(notification_queue.size()):
			if notification_queue[i].category != "important": discard = i; break
		if discard < 0: return
		notification_queue.remove_at(discard)
	var item = {"text":message,"category":category,"age":0.0,"duration":9.0 if category == "important" else (3.0 if category == "low" else 5.0)}
	if category == "important":
		var slot = 0
		while slot < notification_queue.size() and notification_queue[slot].category == "important": slot += 1
		notification_queue.insert(slot,item)
	else: notification_queue.append(item)
	if has_node("Toast"):
		$Toast.text = message

func _process(delta):
	if get_tree().paused: return
	for i in range(notification_active.size()-1,-1,-1):
		notification_active[i].age += delta
		if notification_active[i].age >= notification_active[i].duration: notification_active.remove_at(i)
	notification_delay -= delta
	if notification_active.size() < 3 and not notification_queue.is_empty() and notification_delay <= 0:
		notification_active.append(notification_queue.pop_front())
		notification_delay = 0.65
	for i in range(3):
		var label = notification_labels[i]
		label.visible = i < notification_active.size()
		if not label.visible: continue
		var item = notification_active[i]
		label.text = item.text
		label.position = Vector2(22,size.y-240+i*50)
		label.size = Vector2(minf(470,size.x-44),48)
		label.modulate.a = minf(clampf(item.age/0.25,0,1),clampf((item.duration-item.age)/1.2,0,1))*(1.0 if i == notification_active.size()-1 else 0.78)

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
	if trend < -0.05:
		$WorldStatus/Rows/Trend.text = "-%.1f C cooling" % absf(trend)
		$WorldStatus/Rows/Trend.modulate = Color("4ebd5f")
	else:
		$WorldStatus/Rows/Trend.text = "+%.1f C warming" % maxf(trend, 0.0)
		$WorldStatus/Rows/Trend.modulate = Color(0.9, 0.72, 0.45, 1)
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
	var hunger_val = roundi(state.hunger)
	var thirst_val = roundi(state.thirst)
	$PlayerStatus/Rows/Supplies/Food.text = "%d/10" % hunger_val
	$PlayerStatus/Rows/Supplies/Water.text = "%d/10" % thirst_val
	$PlayerStatus/Rows/Supplies/Food.modulate = Color("e05353") if hunger_val <= 0 else Color("edc647") if hunger_val <= 5 else Color.WHITE
	$PlayerStatus/Rows/Supplies/Water.modulate = Color("e05353") if thirst_val <= 0 else Color("edc647") if thirst_val <= 5 else Color.WHITE
	if $PlayerStatus/Rows/Supplies.has_node("Trash"):
		var trash_label: Label = $PlayerStatus/Rows/Supplies/Trash
		var t_val: int = int(state.trash_count) if "trash_count" in state else 0
		trash_label.text = "%d/3" % t_val
		if t_val >= 3:
			trash_label.modulate = Color("e05353")
			if $PlayerStatus/Rows/Supplies.has_node("TrashIcon"):
				$PlayerStatus/Rows/Supplies/TrashIcon.modulate = Color("e05353")
		else:
			trash_label.modulate = Color.WHITE
			if $PlayerStatus/Rows/Supplies.has_node("TrashIcon"):
				$PlayerStatus/Rows/Supplies/TrashIcon.modulate = Color.WHITE
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

func update_planet_health(percent: float):
	if has_node("WorldStatus/Rows/Planet/Label"):
		var p_val = roundi(clampf(percent, 0.0, 100.0))
		$WorldStatus/Rows/Planet/Label.text = "Planet %d%%" % p_val
		var color = Color("4ebd5f") if p_val >= 70 else (Color("edc647") if p_val >= 40 else Color("e05353"))
		$WorldStatus/Rows/Planet/Label.modulate = color
		if has_node("WorldStatus/Rows/Planet/Bar"):
			$WorldStatus/Rows/Planet/Bar.value = p_val
			$WorldStatus/Rows/Planet/Bar.modulate = color
		if has_node("WorldStatus/Rows/Planet/Icon"):
			$WorldStatus/Rows/Planet/Icon.modulate = color

func update_seeds(count: int):
	$PlayerStatus/Rows/Supplies/Seeds.text = str(count)

func set_wind(state: Dictionary):
	var direction: Vector2 = state.direction
	var sector = posmod(roundi(atan2(direction.x,-direction.y)/(PI/4.0)),8)
	$WorldStatus/Rows/Knowledge/Wind.text = "Wind %s %d%%" % [["N","NE","E","SE","S","SW","W","NW"][sector],roundi(state.strength*100.0)]
