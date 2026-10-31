extends Control
@export_enum("heart", "heat", "weather", "leaf", "food", "water", "seeds") var kind = "heart"
var weather = "clear"
func _ready():
	custom_minimum_size = Vector2(24, 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func set_weather(value: String):
	if weather != value:
		weather = value
		queue_redraw()
func _draw():
	var tint = Color("d7dfb5")
	match kind:
		"heart":
			draw_colored_polygon(PackedVector2Array([Vector2(12,22),Vector2(2,12),Vector2(2,6),Vector2(7,3),Vector2(12,7),Vector2(17,3),Vector2(22,6),Vector2(22,12)]), Color("e38b78"))
		"heat":
			draw_line(Vector2(12,4),Vector2(12,16),Color("eac66d"),5,true)
			draw_circle(Vector2(12,18),5,Color("eac66d"))
			draw_arc(Vector2(12,5),5,PI,TAU,12,tint,1,true)
		"weather":
			if weather in ["clear", "heat"]:
				draw_circle(Vector2(12,12),5,Color("efcf79"))
				for i in range(8):
					var direction = Vector2.from_angle(i * TAU / 8)
					draw_line(Vector2(12,12)+direction*8,Vector2(12,12)+direction*11,tint,1.5,true)
			else:
				draw_circle(Vector2(8,11),5,tint)
				draw_circle(Vector2(14,8),6,tint)
				draw_circle(Vector2(19,12),4,tint)
				if weather == "rain":
					for x in [6,12,18]:
						draw_line(Vector2(x,18),Vector2(x-2,22),Color("9cbdd0"),2,true)
		"food":
			draw_circle(Vector2(10,14),7,Color("deb978"))
			draw_circle(Vector2(15,13),7,Color("deb978"))
			draw_line(Vector2(12,7),Vector2(14,2),Color("94be83"),3,true)
		"water":
			draw_colored_polygon(PackedVector2Array([Vector2(12,2),Vector2(3,15),Vector2(5,21),Vector2(12,23),Vector2(19,21),Vector2(21,15)]),Color("81bed9"))
		"seeds":
			for center in [Vector2(8,15),Vector2(16,9)]:
				draw_circle(center,5,Color("c7d391"))
				draw_line(center+Vector2(-2,2),center+Vector2(2,-2),Color("657041"),1.5,true)
		"leaf":
			draw_colored_polygon(PackedVector2Array([Vector2(3,20),Vector2(3,10),Vector2(10,4),Vector2(22,2),Vector2(20,14),Vector2(14,20)]),Color("94be83"))
			draw_line(Vector2(3,21),Vector2(18,6),Color("456044"),2,true)
