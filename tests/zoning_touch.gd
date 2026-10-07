extends SceneTree
var scene
func _initialize() -> void:
	call_deferred("_run")
func tap(button: Button) -> void:
	await process_frame
	for pressed in [true,false]:
		var event := InputEventScreenTouch.new()
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
func _run() -> void:
	root.size = Vector2i(1280,720)
	scene = load("res://main.tscn").instantiate()
	scene.store.base_path = "user://residential_ui_test.json"
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.store.base_path + suffix))
	root.add_child(scene)
	await process_frame
	assert(scene.model.commit(Vector2(-80,0), Vector2(60,0)))
	scene.road_view.rebuild(scene.model.roads)
	await tap(scene.residential_button)
	assert(scene.zone_panel.visible)
	await process_frame
	await process_frame
	for button in scene.find_children("*","Button",true,false):
		if button.text=="Zonear no mapa":
			await tap(button)
	assert(scene.residential_mode)
	for button in scene.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			assert(button.get_global_rect().end.x <= 1280, "Botões devem caber na tela")
	var target := Vector2(-25,11)
	var world := Vector3(target.x,scene.terrain.height_at(target.x,target.y),target.y)
	scene._map_tapped(scene.city_camera.camera.unproject_position(world))
	assert(not scene.selected_lot.is_empty())
	scene._cancel_preview()
	assert(scene.model.housing.lots.is_empty())
	scene._map_tapped(scene.city_camera.camera.unproject_position(world))
	scene.selected_lot["utility_exempt"]=true
	await tap(scene.confirm_button)
	assert(scene.model.housing.lots.size() == 1)
	scene.model.housing.lots[0]["sewer_exempt"]=true # Isola o teste de telhado/gestos; esgoto tem integração própria.
	scene.model.housing.advance(24)
	scene._refresh_housing()
	for child in scene.housing_view.get_children():
		if child is MeshInstance3D:
			var arrays = child.mesh.surface_get_arrays(0)
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for normal in normals:
				assert(normal.y >= -0.01, "Telhado deve apontar para fora e para cima")
	scene._save_city()
	scene._load_city()
	assert(scene.model.housing.lots.size() == 1 and scene.model.housing.residents.size() == 3)
	assert(scene._snapshot().prototype_version==ProjectSettings.get_setting("application/config/version"))
	await tap(scene.residential_button)
	assert(scene.zone_panel.visible)
	await process_frame
	await process_frame
	for button in scene.find_children("*","Button",true,false):
		if button.text=="Comércio": await tap(button)
		if button.text=="Pequeno 4×6" and button.is_visible_in_tree(): await tap(button)
	assert(scene.selected_zone=="commercial" and scene.selected_size=="small")
	await process_frame
	for button in scene.find_children("*","Button",true,false):
		if button.is_visible_in_tree():
			assert(button.get_global_rect().end.x<=1280 and button.get_global_rect().end.y<=720)
	scene.zone_panel.visible=false
	scene._toggle_options()
	await process_frame
	await process_frame
	await tap(scene.time_button)
	assert(scene.paused)
	var day: int=scene.model.housing.economy.day
	scene._process(30)
	assert(scene.model.housing.economy.day==day)
	await tap(scene.time_button)
	assert(not scene.paused)
	scene.options_panel.visible=false
	scene._navigate()
	var workplace: Dictionary=scene.model.housing.candidate(Vector2(30,11),scene.model.roads,scene.terrain.height_at,"industrial","small")
	assert(not workplace.is_empty())
	workplace["utility_exempt"]=true # Isola a regra anterior; infraestrutura tem teste próprio.
	scene.model.housing.commit(workplace)
	scene.model.housing.advance(24)
	scene.model.simulate(2)
	scene.paused=true
	scene.citizen_view.refresh(scene.model,scene.terrain,0)
	assert(scene.model.travel.moving_count()>0)
	var agent: Dictionary=scene.model.travel.agents[0]
	var before: float=agent.distance
	var position: Vector2=scene.model.travel.position(agent,scene.model.housing)
	var screen: Vector2=scene.city_camera.camera.unproject_position(Vector3(position.x,scene.terrain.height_at(position.x,position.y)+1,position.y))
	scene._map_tapped(screen)
	assert(scene.selected_citizen>0)
	assert(scene.message_label.text.contains("R$"))
	scene._process(0.2)
	assert(agent.distance==before,"Pausa congela deslocamentos")
	# Interface deve explicar a fila e caber também em uma tela mais baixa.
	for x in [-55,-40]:
		var shop: Dictionary=scene.model.housing.candidate(Vector2(x,-8),scene.model.roads,scene.terrain.height_at,"commercial","small")
		assert(not shop.is_empty())
		shop["utility_exempt"]=true # Isola a regra anterior; infraestrutura tem teste próprio.
		scene.model.housing.commit(shop)
	scene.model.housing.advance(1)
	var waiting: Dictionary=scene.model.housing.lots[-1]
	assert(waiting.demand_pending)
	scene._refresh_housing()
	scene._refresh_status()
	assert(scene.demand_status.text.contains("Demanda:"))
	scene._inspect_lot(waiting)
	assert(scene.message_label.text.contains("Aguardando demanda"))
	var waiting_age: float=waiting.age
	scene._process(0.2)
	assert(waiting.demand_pending and waiting.age==waiting_age,"Pausa mantém a fila parada")
	scene._choose_zone("commercial")
	scene.zone_panel.visible=true
	root.content_scale_size=Vector2i(1280,640)
	root.size=Vector2i(1280,640)
	await process_frame
	await process_frame
	for button in scene.find_children("*","Button",true,false):
		if button.is_visible_in_tree():
			assert(button.get_global_rect().end.x<=1280 and button.get_global_rect().end.y<=640,"Zoneamento com explicação da demanda deve caber na tela")
	assert(scene.zone_label.text.contains("compradores"))
	print("ZONING_TOUCH_OK: toque, cancelamento, confirmação, telhado e recarga")
	scene.free()
	quit()
