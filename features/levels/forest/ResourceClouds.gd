extends Resource
## Visual defaults only. Runtime overrides are on Remote/ForestLevel/DeveloperTuning.
@export var enabled = true
## Base population; weather multipliers select a softly faded subset of the32-cloud pool.
@export_range(0,24,1) var count = 12
@export_range(0.0,3.0,0.05) var speed_multiplier = 1.0
@export_range(0.0,0.85,0.05) var opacity = 0.7
@export_range(0.5,3.0,0.1) var cloud_scale = 1.5
@export_range(2.0,16.0,0.5) var altitude = 7.0
## Half-width of the square drift area, in world units.
@export_range(12.0,36.0,1.0) var extent = 23.0
@export_range(0.0,2.0,0.05) var rain_density = 1.0
@export_range(0.0,1.0,0.05) var heat_density = 0.12
@export_range(0.0,1.0,0.05) var clear_density = 0.35
@export_range(0.0,1.0,0.05) var rain_darkening = 0.55
