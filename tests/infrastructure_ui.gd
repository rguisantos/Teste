extends SceneTree
var scene
func _initialize()->void: call_deferred("_run")
func button(text:String)->Button:
	for child in scene.find_children("*","Button",true,false):
		if child.text==text: return child
	return null
func tap(target:Button)->void:
	await process_frame
	assert(target!=null and target.is_visible_in_tree(),"Alvo oculto: "+(target.text if target!=null else "null"))
	for pressed in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.position=target.get_global_rect().get_center()
		event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame
func fits()->void:
	for child in scene.find_children("*","Button",true,false):
		if child.is_visible_in_tree():
			var rect:Rect2=child.get_global_rect()
			assert(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=1280 and rect.end.y<=640,"HUD cabe na tela")
func _run()->void:
	root.content_scale_size=Vector2i(1280,640)
	root.size=Vector2i(1280,640)
	scene=load("res://main.tscn").instantiate()
	scene.paused=true
	scene.store.base_path="user://infrastructure_ui_test.json"
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.store.base_path+suffix))
	root.add_child(scene)
	await process_frame
	await process_frame
	assert(not scene.build_actions.visible)
	fits()
	assert(scene.model.commit(Vector2(-80,0),Vector2(70,0)))
	scene.road_view.rebuild(scene.model.roads)
	await tap(button("Infraestrutura"))
	await process_frame
	await process_frame
	assert(scene.infrastructure_panel.visible)
	fits()
	await tap(button("Construir água"))
	assert(scene.residential_mode and scene.selected_zone=="water" and scene.build_actions.visible)
	assert(not scene.shape_button.visible)
	var point:=Vector3(-25,scene.terrain.height_at(-25,9),9)
	scene._map_tapped(scene.city_camera.camera.unproject_position(point))
	assert(not scene.selected_lot.is_empty() and scene.selected_lot.width==6)
	await tap(scene.confirm_button)
	assert(scene.model.housing.lots.size()==1 and scene.model.housing.lots[0].zone=="water")
	scene.model.simulate(24.1)
	scene._refresh_housing()
	scene._refresh_status()
	scene._inspect_lot(scene.model.housing.lots[0])
	assert(scene.lot_label.text.contains("Capacidade: 60") and scene.lot_cancel_button.disabled)
	scene._close_lot_panel()
	await tap(button("Infraestrutura"))
	await tap(button("Mapa: água"))
	assert(scene.coverage_kind=="water" and scene.overlay.mesh!=null)
	assert(not scene.housing_view.visible and not scene.citizen_view.visible and not scene.terrain.tree_root.visible)
	assert(scene.service_view.visible and scene.service_view.get_child_count()>0)
	await process_frame
	fits()
	await tap(button("Zonear"))
	assert(scene.selected_zone=="residential","Painel de zoneamento não mantém categoria de serviço")
	scene.zone_panel.visible=false
	var lot:Dictionary=scene.model.housing.candidate(Vector2(10,9),scene.model.roads,scene.terrain.height_at,"residential","small")
	assert(not lot.is_empty())
	scene.model.housing.commit(lot)
	scene._refresh_housing()
	await tap(button("Bulldozer"))
	assert(scene.bulldozer_mode and not scene.build_actions.visible)
	point=Vector3(lot.x,scene.terrain.height_at(lot.x,lot.z),lot.z)
	scene._map_tapped(scene.city_camera.camera.unproject_position(point))
	assert(scene.demolition_dialog.visible and scene.overlay_target==2)
	assert(scene.model.housing.lots.size()==2)
	scene.demolition_dialog.get_cancel_button().pressed.emit()
	await process_frame
	assert(scene.model.housing.lots.size()==2)
	scene._close_lot_panel()
	scene._map_tapped(scene.city_camera.camera.unproject_position(point))
	scene.demolition_dialog.get_ok_button().pressed.emit()
	await process_frame
	assert(scene.model.housing.lots.size()==1)
	assert(scene.store.load_city().residential.lots.size()==1)
	await tap(button("Navegar"))
	assert(not scene.bulldozer_mode and not scene.city_camera.build_mode)
	fits()
	scene._set_coverage("")
	assert(scene.housing_view.visible and scene.citizen_view.visible and scene.terrain.tree_root.visible)
	scene._bulldozer()
	var selected:Dictionary=scene.model.pick_demolition_road(Vector2(30,0))
	scene._request_demolition({"kind":"road","road":selected})
	assert(scene.demolition_dialog.visible and not scene.keep_zone_check.visible)
	var elapsed:float=scene.model.housing.economy.elapsed
	scene.paused=false
	scene._process(0.2)
	assert(scene.model.housing.economy.elapsed==elapsed,"Confirmação pausa consequências da simulação")
	scene.demolition_dialog.get_ok_button().pressed.emit()
	await process_frame
	assert(scene.model.roads.is_empty() and scene.model.housing.lots[0].road==-1)
	assert(scene.store.load_city().roads.is_empty())
	scene.demolition_dialog.hide()
	scene.lot_cancel_dialog.hide()
	scene.paused=true
	scene._navigate()
	await process_frame
	await tap(button("Infraestrutura"))
	await process_frame
	assert(scene.infrastructure_panel.visible,"Catálogo abriu")
	await tap(scene.catalog_buttons.small)
	assert(scene.catalog_tier=="small" and scene.infrastructure_label.text.contains("R$ 3000"))
	fits()
	assert(scene.model.commit(Vector2(-80,0),Vector2(70,0)))
	scene.road_view.rebuild(scene.model.roads)
	await tap(button("Construir água"))
	point=Vector3(20,scene.terrain.height_at(20,8),8)
	scene._map_tapped(scene.city_camera.camera.unproject_position(point))
	assert(not scene.selected_lot.is_empty() and scene.selected_lot.width==4)
	var before:int=scene.model.cash
	assert(scene.message_label.text.contains("R$ 3000") and scene.model.cash==before)
	await tap(scene.confirm_button)
	assert(scene.model.cash==before-3000)
	assert(scene.store.load_city().cash==scene.model.cash)
	await tap(button("Infraestrutura"))
	await tap(scene.catalog_buttons.large)
	await tap(scene.catalog_categories.power)
	await tap(button("Construir energia"))
	scene.model.cash=0
	point=Vector3(45,scene.terrain.height_at(45,12),12)
	scene._map_tapped(scene.city_camera.camera.unproject_position(point))
	assert(not scene.selected_lot.is_empty() and scene.confirm_button.disabled)
	assert(scene.message_label.text.contains("Caixa insuficiente"))
	var count:int=scene.model.housing.lots.size()
	scene._confirm_road()
	assert(scene.model.cash==0 and scene.model.housing.lots.size()==count)
	print("INFRASTRUCTURE_UI_OK: HUD 1280×640, instalações por toque, cobertura, consulta e bulldozer com confirmação")
	scene.free()
	quit()
