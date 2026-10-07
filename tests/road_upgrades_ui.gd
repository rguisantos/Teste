extends SceneTree
var scene
func _initialize()->void:call_deferred("_run")
func touch(point:Vector2)->void:
	for pressed in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.position=point
		event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame
func tap(button:Button)->void:
	await process_frame
	assert(button.is_visible_in_tree())
	await touch(button.get_global_rect().get_center())
func map_touch(point:Vector2)->void:
	await touch(scene.city_camera.camera.unproject_position(Vector3(point.x,scene.terrain.height_at(point.x,point.y),point.y)))
func fit()->void:
	for button in scene.find_children("*","Button",true,false):
		if button.is_visible_in_tree() and button.get_viewport()==root:
			var rect:Rect2=button.get_global_rect()
			assert(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=1280 and rect.end.y<=640,button.text+str(rect))
func _run()->void:
	root.content_scale_size=Vector2i(1280,640)
	root.size=Vector2i(1280,640)
	scene=load("res://main.tscn").instantiate()
	scene.paused=true
	scene.store.base_path="user://road_upgrades_ui_test.json"
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.store.base_path+suffix))
	root.add_child(scene)
	await process_frame
	await process_frame
	assert(scene.model.commit(Vector2(-80,0),Vector2(60,0)))
	assert(scene.model.commit(Vector2(0,0),Vector2(0,60)))
	for x in [-35,30]:
		var lot:Dictionary=scene.model.housing.candidate(Vector2(x,9),scene.model.roads,scene.terrain.height_at,"residential","small")
		assert(not lot.is_empty() and scene.model.place_lot(lot).ok)
	scene.road_view.rebuild(scene.model.roads)
	scene._refresh_housing()
	await tap(scene.road_button)
	assert(scene.road_surface_button.visible and scene.upgrade_button.visible)
	await tap(scene.road_surface_button)
	assert(scene.selected_road_surface=="asphalt")
	await process_frame
	fit()
	await tap(scene.upgrade_button)
	assert(scene.upgrade_mode and not scene.shape_button.visible)
	var cash:int=scene.model.cash
	await map_touch(Vector2(-25,0))
	assert(not scene.upgrade_target.is_empty() and not scene.confirm_button.disabled)
	assert(scene.message_label.text.contains("R$ 3200") and scene.message_label.text.contains("Manutenção total"))
	assert(scene.model.cash==cash)
	await tap(scene.confirm_button)
	assert(scene.model.cash==cash-3200 and scene.model.housing.lots.size()==2)
	assert(scene.road_view.built.get_child_count()>=4,"Pista, calçadas, asfalto e faixas")
	await map_touch(Vector2(-25,0))
	assert(scene.confirm_button.disabled and scene.message_label.text.contains("já está asfaltado"))
	await tap(scene.upgrade_button)
	assert(not scene.upgrade_mode and scene.shape_button.visible)
	await map_touch(Vector2(0,0))
	await map_touch(Vector2(40,-40))
	assert(not scene.confirm_button.disabled and scene.message_label.text.contains("Asfalto com calçadas"))
	await tap(scene.confirm_button)
	assert(scene.model.roads[-1].surface=="asphalt")
	var saved:Dictionary=scene.store.load_city()
	var restored=preload("res://scripts/streets_model.gd").restore(saved)
	assert(restored!=null and restored.cash==scene.model.cash and restored.roads[-1].surface=="asphalt")
	await tap(scene.toolbar_buttons["Bulldozer"])
	await map_touch(Vector2(-25,0))
	assert(scene.demolition_dialog.visible)
	assert(scene.demolition_dialog.dialog_text.contains("Sem rua na frente: 1") and scene.demolition_dialog.dialog_text.contains("Isolados da entrada: 1"))
	cash=scene.model.cash
	scene.demolition_dialog.hide()
	scene._cancel_demolition()
	assert(scene.model.cash==cash)
	await tap(scene.toolbar_buttons["Zonear"])
	assert(not scene.road_surface_button.visible and not scene.upgrade_button.visible and not scene.upgrade_mode)
	await process_frame
	fit()
	scene.free()
	print("ROAD_UPGRADES_UI_OK: toque, prévias, cobrança, seleção repetida, salvar, impacto e layout 1280x640")
	quit()
