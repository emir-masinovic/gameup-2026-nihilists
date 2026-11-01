extends SceneTree
var failures = 0
func check(ok, message):
	if not ok: failures += 1; push_error(message)
func _initialize(): call_deferred("run")
func run():
	var settings = root.get_node("SettingsManager")
	settings.storage_path = "user://density_test.cfg"
	settings.grass_density = "High"
	settings.save_settings()
	settings.grass_density = "Low"
	settings.load_settings()
	check(settings.grass_density == "High","Density reload")
	settings.reset_category("Video")
	check(settings.grass_density == "Off","Restore Defaults selects Off")
	var legacy = ConfigFile.new()
	legacy.set_value("video","fps_limit",144)
	legacy.save(settings.storage_path)
	settings.load_settings()
	check(settings.grass_density == "Medium" and settings.fps_limit == 144,"Legacy migration retains other preferences")
	for biome in ["forest","wetlands","drylands"]:
		var flow = root.get_node("SceneFlow")
		flow.run_regions = load("res://features/levels/forest/RunRegions.gd").new()
		flow.run_regions.configure(2026)
		flow.run_regions.current_id = biome
		flow.next_seed = 2026
		change_scene_to_file("res://features/levels/forest/forest_level.tscn")
		await process_frame
		await process_frame
		var cover = current_scene.ground_cover
		current_scene.set_process(false)
		var original = current_scene.grid.cells.duplicate(true)
		var children = cover.get_child_count()
		for quality in ["Off","Low","Medium","High","Off","Medium"]:
			settings.grass_density = quality
			settings.apply_settings()
			check(cover.batches.size() == 2 and cover.get_child_count() == children,"No accumulated renderers")
			check(cover.batches[0].renderer.visible == (quality != "Off"),"Grass visibility")
			check(current_scene.grid.cells == original,"Quality never changes ecology")
			print("DENSITY ",biome," ",quality," allocated=",cover.batches[0].indices.size()," reconfigure_ms=",cover.reconfigure_ms)
			var renderer = cover.batches[0].renderer
			settings.apply_settings()
			check(cover.batches[0].renderer == renderer,"Unrelated settings never rebuild grass")
		current_scene.queue_free()
		await process_frame
	var menu = load("res://features/menus/options_menu.tscn").instantiate()
	root.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.show_category("Video")
	for size in [Vector2i(1280,720),Vector2i(1600,900)]:
		root.size = size
		await process_frame
		await process_frame
		var buttons = menu.content.get_node("GrassDensityRow/GrassDensity")
		check(buttons.get_child_count() == 4,"Four density buttons")
		for button in buttons.get_children():check(button.size.x >= 40 and button.get_global_rect().end.x <= size.x,"Density buttons fit")
		if OS.has_environment("DENSITY_UI_OUT"):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("DENSITY_UI_OUT")+str(size.x)+".png")
		buttons.get_node("High").pressed.emit()
		check(settings.grass_density == "High","Video button dispatch")
		menu.show_category("Video")
		check(menu.content.get_node("GrassDensityRow/GrassDensity/High").button_pressed,"Selected preset remains synchronized")
	menu.queue_free()
	DirAccess.remove_absolute(settings.storage_path)
	await process_frame
	print("DENSITY failures=",failures)
	quit(failures)
