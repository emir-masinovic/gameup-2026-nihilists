extends Node3D
# Onur's shared sprout meshes, staged by climate growth rather than a visual timer.
func update_growth(data: Dictionary):
	var age: float = data.get("growth_age", 0.0)
	var stage = 0 if age < 60.0 else 1 if age < 120.0 else 2
	scale = Vector3.ONE * [0.9, 1.5, 2.3][stage]
	$Bud.visible = stage >= 1
	var dead: bool = data.tree_state == "dead" or data.get("burned", false)
	$LeafLeft.visible = not dead
	$LeafRight.visible = not dead
	$Bud.visible = $Bud.visible and not dead
