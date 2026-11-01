extends Resource
# Presentation tuning only; no climate state or gameplay/save authority.
@export_group("Grass Wind")
@export_range(0.0,3.0,0.05) var wind_deformation = 2.2
@export_range(0.0,1.0,0.05) var gust_strength = 0.85
@export_range(0.1,3.0,0.1) var gust_speed = 1.6
@export_range(0.0,1.0,0.05) var wind_line_opacity = 0.36
@export_group("Rain Impacts")
@export_range(0,256,1) var splash_count = 128
@export_range(0.1,3.0,0.1) var splash_size = 1.7
@export_range(0.0,1.0,0.05) var splash_opacity = 0.75
@export_group("Heat Tint")
@export_range(0.0,0.6,0.01) var forest_heat_strength = 0.34
@export_range(0.0,0.6,0.01) var wetlands_heat_strength = 0.28
@export_range(0.0,0.6,0.01) var drylands_heat_strength = 0.16

func heat_strength(biome: String) -> float:
	return drylands_heat_strength if biome == "drylands" else wetlands_heat_strength if biome == "wetlands" else forest_heat_strength
