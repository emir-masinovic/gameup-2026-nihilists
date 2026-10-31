extends Node3D
# Onur's shared sprout meshes, staged by climate growth rather than a visual timer.
var _stage = -1
var _growth_tween: Tween
func _ready():
	for i in range(2):
		var tier = MeshInstance3D.new()
		tier.name = "LeafTier%d" % i
		tier.mesh = $LeafLeft.mesh
		tier.position = Vector3(0,0.24+i*0.12,0)
		tier.rotation.y = PI*0.5*i
		tier.scale = Vector3(1.8,1,1.5)
		tier.visible = false
		add_child(tier)

func update_growth(data: Dictionary):
	var age: float = data.get("growth_age", 0.0)
	var stage = preload("res://features/levels/forest/StatePlanting.gd").growth_stage(age)
	var target = Vector3.ONE * [0.9, 1.7, 2.8][stage]
	if stage != _stage:
		if is_instance_valid(_growth_tween): _growth_tween.kill()
		if _stage < 0: scale = target
		else:
			_growth_tween = create_tween()
			_growth_tween.tween_property(self,"scale",target,0.75).set_trans(Tween.TRANS_SINE)
		_stage = stage
	$Bud.visible = stage >= 1
	var dead: bool = data.tree_state == "dead" or data.get("burned", false)
	$LeafLeft.visible = not dead
	$LeafRight.visible = not dead
	$Bud.visible = $Bud.visible and not dead

	for i in range(2):
		get_node("LeafTier%d" % i).visible = not dead and stage > i
