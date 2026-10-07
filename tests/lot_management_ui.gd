extends SceneTree
var scene
func _initialize()->void: call_deferred("_run")
func tap(button: Button)->void:
	await process_frame
	for pressed in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.position=button.get_global_rect().get_center()
		event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame
func _run()->void:
	root.content_scale_size=Vector2i(1280,640)
	root.size=Vector2i(1280,640)
	scene=load("res://main.tscn").instantiate()
	scene.paused=true
	scene.store.base_path="user://lot_management_ui_test.json"
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.store.base_path+suffix))
	root.add_child(scene)
	await process_frame
	assert(scene.model.commit(Vector2(-80,0),Vector2(60,0)))
	scene.road_view.rebuild(scene.model.roads)
	var lot: Dictionary=scene.model.housing.candidate(Vector2(-25,-8),scene.model.roads,scene.terrain.height_at,"commercial","small")
	assert(not lot.is_empty())
	lot["utility_exempt"]=true # Isola a regra anterior; infraestrutura tem teste próprio.
	scene.model.housing.commit(lot)
	scene._refresh_housing()
	scene._navigate()
	var world:=Vector3(lot.x,scene.terrain.height_at(lot.x,lot.z),lot.z)
	scene._map_tapped(scene.city_camera.camera.unproject_position(world))
	assert(scene.lot_panel.visible and scene.inspected_lot_id==1,"Navegar abre consulta do imóvel")
	await process_frame
	await process_frame
	for button in scene.find_children("*","Button",true,false):
		if button.is_visible_in_tree(): assert(button.get_global_rect().end.y<=640 and button.get_global_rect().end.x<=1280)
	await tap(scene.lot_usage_buttons[0])
	assert(scene.model.housing.lots[0].zone=="residential")
	assert(scene.model.housing.lots[0].demand_pending,"Pausa não inicia a obra depois da troca")
	assert(scene.store.load_city().residential.lots[0].zone=="residential")
	await tap(scene.lot_cancel_button)
	assert(scene.lot_cancel_dialog.visible)
	assert(scene.model.housing.lots.size()==1,"Pedido de confirmação não remove lote")
	scene.lot_cancel_dialog.get_cancel_button().pressed.emit()
	await process_frame
	assert(scene.model.housing.lots.size()==1 and not scene.lot_cancel_dialog.visible)
	await tap(scene.lot_cancel_button)
	scene.lot_cancel_dialog.get_ok_button().pressed.emit()
	await process_frame
	assert(scene.model.housing.lots.is_empty() and not scene.lot_panel.visible)
	assert(scene.store.load_city().residential.lots.is_empty())
	# A obra pode concluir enquanto a confirmação fica aberta: recusar remoção.
	var race: Dictionary=scene.model.housing.candidate(Vector2(-25,-8),scene.model.roads,scene.terrain.height_at,"residential","small")
	assert(not race.is_empty())
	race["utility_exempt"]=true # Isola a regra anterior; infraestrutura tem teste próprio.
	scene.model.housing.commit(race)
	scene._open_lot_panel(1)
	scene._request_cancel_lot()
	scene.model.simulate(24.1)
	assert(scene.model.housing.lots[0].stage==2)
	scene.lot_cancel_dialog.get_ok_button().pressed.emit()
	await process_frame
	assert(scene.model.housing.lots.size()==1 and scene.model.housing.residents.size()>0)
	assert(scene.lot_cancel_button.disabled)
	# Imóvel pronto recebe consulta de moradores e ações de remoção ficam bloqueadas.
	var legacy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/city-0.0.10.json"))
	scene.model=preload("res://scripts/streets_model.gd").restore(legacy)
	scene._open_lot_panel(1)
	assert(scene.lot_panel.visible and scene.lot_cancel_button.disabled)
	assert(not scene.lot_usage_row.visible)
	assert(scene.lot_label.text.contains(scene.model.housing.residents[0].name))
	scene._request_cancel_lot()
	assert(not scene.lot_cancel_dialog.visible)
	print("LOT_MANAGEMENT_UI_OK: consulta em Navegar, troca por toque, confirmação/cancelamento, persistência e imóvel pronto")
	scene.free()
	quit()
