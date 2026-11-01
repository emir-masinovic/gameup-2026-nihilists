extends Control
@export_enum("heart", "heat", "weather", "leaf", "food", "water", "seeds", "sprout", "drop", "trash", "planet") var kind = "heart"
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
		"sprout":
			draw_line(Vector2(12, 22), Vector2(12, 10), Color("456044"), 2, true)
			draw_colored_polygon(PackedVector2Array([Vector2(12, 14), Vector2(6, 10), Vector2(5, 7), Vector2(11, 10)]), Color("82c974"))
			draw_colored_polygon(PackedVector2Array([Vector2(12, 12), Vector2(18, 8), Vector2(19, 5), Vector2(13, 8)]), Color("9ee090"))
		"drop":
			draw_circle(Vector2(12, 15), 6, Color("5cb8f2"))
			draw_colored_polygon(PackedVector2Array([Vector2(6, 15), Vector2(18, 15), Vector2(12, 4)]), Color("5cb8f2"))
			draw_circle(Vector2(10, 13), 1.8, Color("9ee3ff"))
		"trash":
			draw_rect(Rect2(7, 8, 10, 13), Color("9eb5c2"), true)
			draw_line(Vector2(5, 7), Vector2(19, 7), Color("d0dde5"), 2, true)
			draw_line(Vector2(10, 11), Vector2(10, 18), Color("586872"), 1.5, true)
			draw_line(Vector2(14, 11), Vector2(14, 18), Color("586872"), 1.5, true)
		"planet":
			draw_circle(Vector2(12, 12), 7.5, Color("3a86b7"))
			draw_colored_polygon(PackedVector2Array([Vector2(8, 8), Vector2(13, 7), Vector2(15, 11), Vector2(11, 15), Vector2(7, 13)]), Color("5eb862"))
			draw_arc(Vector2(12, 12), 9.5, -0.4, PI * 0.9, 16, Color("9ee3ff"), 1.5, true)
