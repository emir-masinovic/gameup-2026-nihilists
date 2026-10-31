extends RefCounted
## Descriptors are shared Dictionaries. Callbacks take no arguments; tick emits
## a descriptor copy with kind completed/cancelled. Progress is elapsed seconds.
var active: Dictionary = {}
var progress: float = 0.0
var _origin := Vector2i.ZERO

func select(candidates: Array, player_cell: Vector2i, facing: Vector2i) -> Dictionary:
	var eligible: Array[Dictionary] = []
	for candidate in candidates:
		if candidate is Dictionary and candidate.get("cell") is Vector2i and _in_range(candidate, player_cell):
			eligible.append(candidate)
	eligible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := _distance(a.cell, player_cell)
		var db := _distance(b.cell, player_cell)
		if da != db:
			return da < db
		var af: int = (a.cell.x - player_cell.x) * facing.x + (a.cell.y - player_cell.y) * facing.y
		var bf: int = (b.cell.x - player_cell.x) * facing.x + (b.cell.y - player_cell.y) * facing.y
		if af != bf:
			return af > bf
		if int(a.get("priority", 0)) != int(b.get("priority", 0)):
			return int(a.get("priority", 0)) > int(b.get("priority", 0))
		return str(a.get("id", "")) < str(b.get("id", "")))
	return eligible[0] if not eligible.is_empty() else {}

func begin(descriptor: Dictionary, player_cell: Vector2i) -> bool:
	if not active.is_empty() or descriptor.is_empty() or not descriptor.get("available", true):
		return false
	if not descriptor.get("cell") is Vector2i or not _in_range(descriptor, player_cell):
		return false
	active = descriptor
	_origin = player_cell
	progress = 0.0
	return true

func tick(delta: float, player_cell: Vector2i, paused: bool = false) -> Dictionary:
	if active.is_empty() or paused:
		return {}
	if player_cell != _origin or not _in_range(active, player_cell) or not active.get("available", true):
		var event := active.duplicate()
		event.kind = "cancelled"
		event.reason = "Movement interrupted the action" if player_cell != _origin else str(active.get("reason", "Target unavailable"))
		cancel()
		return event
	if not is_finite(delta) or delta <= 0.0:
		return {}
	progress += delta
	if progress < maxf(float(active.get("duration", 0.0)), 0.0):
		return {}
	var event := active.duplicate()
	event.kind = "completed"
	var callback: Callable = active.get("complete", Callable())
	active = {}
	progress = 0.0
	if callback.is_valid():
		callback.call()
	return event

func cancel() -> void:
	var callback: Callable = active.get("cancel", Callable())
	active = {}
	progress = 0.0
	if callback.is_valid():
		callback.call()

func _in_range(descriptor: Dictionary, player_cell: Vector2i) -> bool:
	return _distance(descriptor.cell, player_cell) <= maxf(float(descriptor.get("range", 1.0)), 0.0)

func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
