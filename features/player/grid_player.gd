extends Node3D
signal cell_entered(cell: Vector2i)
var facing = Vector2i.UP
var cell = Vector2i.ZERO
var grid: RefCounted
var moving = false
var move_tween: Tween

func configure(data: RefCounted):
	grid = data
	cell = grid.start
	position = grid.world_position(cell)

func _process(_delta):
	if moving or grid == null:
		return
	var direction = Vector2i.ZERO
	if Input.is_action_pressed("move_north"):
		direction = Vector2i.UP
	elif Input.is_action_pressed("move_south"):
		direction = Vector2i.DOWN
	elif Input.is_action_pressed("move_west"):
		direction = Vector2i.LEFT
	elif Input.is_action_pressed("move_east"):
		direction = Vector2i.RIGHT
	if direction != Vector2i.ZERO:
		try_move(direction)

func try_move(direction: Vector2i) -> bool:
	if moving or grid == null or abs(direction.x) + abs(direction.y) != 1:
		return false
	var target = cell + direction
	if not grid.traversable(target):
		return false
	facing = direction
	moving = true
	cell = target
	cell_entered.emit(cell)
	$Body.rotation.y = atan2(-direction.x, -direction.y)
	move_tween = create_tween()
	move_tween.tween_property(self, "position", grid.world_position(cell), 0.16).set_trans(Tween.TRANS_SINE)
	move_tween.finished.connect(func(): moving = false)
	return true
