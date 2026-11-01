extends Control
# Explicit world-space E/W sky compass: meaningful even without a visible horizon.
var source = Vector3.UP
var moon = false
func _ready(): mouse_filter = Control.MOUSE_FILTER_IGNORE
func set_source(value: Vector3, night: bool):
	source = value
	moon = night
	queue_redraw()
func _draw():
	var center = Vector2(75,48)
	draw_arc(center,36,PI,TAU,32,Color(0.65,0.75,0.8,0.5),1.5,true)
	var angle = atan2(source.y,source.x)
	var point = center+Vector2(cos(angle),-sin(angle))*36
	draw_circle(point,6,Color("c5d9ef") if moon else Color("ffe4a3"))
	if moon: draw_circle(point+Vector2(3,-2),4.5,Color("26363c"))
	var font = ThemeDB.fallback_font
	draw_string(font,Vector2(25,65),"W",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
	draw_string(font,Vector2(112,65),"E",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
	draw_string(font,Vector2(57,74),"Moon" if moon else "Sun",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)
