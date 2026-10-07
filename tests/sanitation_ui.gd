extends SceneTree
var scene
func _initialize()->void:call_deferred("_run")
func fits()->void:
	for child in scene.find_children("*","Button",true,false):
		if child.is_visible_in_tree():
			var rect:Rect2=child.get_global_rect()
			assert(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=1280 and rect.end.y<=640,"Botão cabe: "+child.text)
func tap(target:Button)->void:
	await process_frame
	assert(target.is_visible_in_tree())
	for pressed in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.position=target.get_global_rect().get_center()
		event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame
func _run()->void:
	root.content_scale_size=Vector2i(1280,640)
	root.size=Vector2i(1280,640)
	scene=load("res://main.tscn").instantiate()
	scene.paused=true
	scene.store.base_path="user://sanitation_ui_test.json"
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.store.base_path+suffix))
	root.add_child(scene)
	await process_frame
	await process_frame
	assert(scene.model.commit(Vector2(-80,0),Vector2(70,0)))
	scene.road_view.rebuild(scene.model.roads)
	scene._toggle_infrastructure()
	await process_frame
	await tap(scene.catalog_categories.sewage)
	await tap(scene.catalog_buttons.small)
	assert(scene.infrastructure_label.text.contains("ETE compacta") and scene.infrastructure_label.text.contains("R$ 3500"))
	fits()
	await tap(scene.catalog_build)
	assert(scene.selected_zone=="sewage" and scene.coverage_kind=="sewage")
	var position:=Vector3(20,scene.terrain.height_at(20,9),9)
	scene._map_tapped(scene.city_camera.camera.unproject_position(position))
	assert(not scene.selected_lot.is_empty() and scene.selected_lot.zone=="sewage")
	var before:int=scene.model.cash
	await tap(scene.confirm_button)
	assert(scene.model.cash==before-3500)
	assert(scene.store.load_city().residential.lots[0].zone=="sewage")
	scene.model.simulate(24.1)
	scene._refresh_housing()
	scene._set_coverage("sewage")
	await process_frame
	assert(scene.map_label.text.contains("tratado local"))
	assert(scene.service_view.get_child_count()>0 and not scene.housing_view.visible)
	scene._inspect_lot(scene.model.housing.lots[0])
	assert(scene.lot_label.text.contains("infiltração") and scene.lot_label.text.contains("Capacidade: 30"))
	scene._close_lot_panel()
	for kind in ["water","power","sewage","sources","access","zones"]:
		scene._set_coverage(kind)
		await process_frame
		await process_frame
		fits()
	assert(scene.map_panel.get_global_rect().end.y<=548,"Mapa preserva dock")
	scene._set_coverage("sources")
	assert(scene.map_label.text.contains("Aquífero Oeste") and scene.overlay.mesh!=null)
	scene._set_coverage("")
	assert(scene.housing_view.visible and scene.terrain.tree_root.visible)
	scene._toggle_infrastructure()
	await tap(scene.catalog_categories.water)
	await tap(scene.catalog_build)
	assert(scene.coverage_kind=="sources")
	print("SANITATION_UI_OK: catálogo, preço, esgoto por toque, consulta, seis mapas e layout 1280×640")
	scene.free()
	quit()
