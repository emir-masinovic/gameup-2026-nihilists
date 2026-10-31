extends Node3D
# Onur's shared sprout meshes, staged by climate growth rather than a visual timer.
func update_growth(data: Dictionary):
	var age: float = data.get("growth_age", 0.0)
	var stage = preload("res://features/levels/forest/StatePlanting.gd").growth_stage(age)
	scale = Vector3.ONE * [0.9, 1.7, 2.8][stage]
	$Bud.visible = stage >= 1
	var dead: bool = data.tree_state == "dead" or data.get("burned", false)
	$LeafLeft.visible = not dead
	$LeafRight.visible = not dead
	$Bud.visible = $Bud.visible and not dead
