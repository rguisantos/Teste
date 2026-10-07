extends SceneTree
var scene
const Catalog=preload("res://scripts/vehicle_catalog.gd")
const Routes=preload("res://scripts/vehicle_routes.gd")
func _initialize()->void:call_deferred("_run")
func touch(point:Vector2)->void:
	for pressed in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.position=point;event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame
func tap(button:Button)->void:
	await process_frame
	assert(button!=null and button.is_visible_in_tree())
	await touch(button.get_global_rect().get_center())
func button(text:String)->Button:
	for node in scene.find_children("*","Button",true,false):
		if node.text==text:return node
	return null
func fit()->void:
	for control in scene.find_children("*","Button",true,false):
		if control.is_visible_in_tree() and control.get_viewport()==root:
			var rect:Rect2=control.get_global_rect()
			assert(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=1280 and rect.end.y<=640,control.text+str(rect))
func _run()->void:
	root.content_scale_size=Vector2i(1280,640);root.size=Vector2i(1280,640)
	scene=load("res://main.tscn").instantiate()
	scene.paused=true
	scene.store.base_path="user://vehicle-ui019.json"
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.store.base_path+suffix))
	root.add_child(scene)
	await process_frame
	await process_frame
	assert(scene.model.commit(Vector2(-80,0),Vector2(80,0),null,"asphalt"))
	for i in range(5):
		var lot:Dictionary=scene.model.housing.candidate(Vector2(-58+i*25,9),scene.model.roads,scene.terrain.height_at,"industrial" if i>2 else "residential","small")
		assert(not lot.is_empty())
		lot.utility_exempt=true;lot.sewer_exempt=true
		scene.model.housing.commit(lot)
	scene.model.housing.advance(24.1)
	scene.model.refresh_access()
	for i in range(5):assert(scene.model.traffic.enqueue(scene.model,Catalog.TYPES[i],Routes.address(scene.model.housing.lots[i]),{"entry":true}))
	scene.road_view.rebuild(scene.model.roads)
	scene._refresh_housing()
	scene._refresh_status()
	await process_frame
	assert(scene.vehicle_view.batches.size()==5)
	for kind in Catalog.TYPES:
		assert(scene.vehicle_view.batches[kind].instance_count==1 and scene.vehicle_view.models[kind].get_surface_count()==1)
	var before:=JSON.stringify(scene.model.traffic.serialize())
	await process_frame
	await process_frame
	assert(before==JSON.stringify(scene.model.traffic.serialize()),"Pausa para todos os veículos")
	await tap(scene.toolbar_buttons["Opções"])
	await tap(button("Trânsito"))
	assert(scene.traffic_panel.visible and scene.traffic_label.text.contains("5 circulando"))
	for kind in Catalog.TYPES:
		await tap(scene.traffic_buttons[kind])
		assert(scene.selected_vehicle>0 and scene.traffic_label.text.contains(Catalog.spec(kind).name))
		assert(scene.city_camera.distance==40)
		fit()
	await tap(button("Fechar trânsito"))
	assert(not scene.traffic_panel.visible)
	# Touch the actual projected truck opens the same details.
	var vehicle:Dictionary=scene.model.traffic.vehicles[-1]
	var point:Vector2=preload("res://scripts/citizen_routes.gd").position(vehicle.route.points,vehicle.distance)
	var screen:Vector2=scene.city_camera.camera.unproject_position(Vector3(point.x,scene.terrain.road_height_at(point.x,point.y)+1,point.y))
	await touch(screen)
	assert(scene.selected_vehicle==vehicle.id and scene.traffic_panel.visible)
	scene._set_coverage("water")
	assert(not scene.vehicle_view.visible)
	scene._set_coverage("")
	assert(scene.vehicle_view.visible)
	assert(scene.store.save_city(scene.current_seed,scene.model))
	var saved:Dictionary=scene.store.load_city()
	assert(saved.traffic.vehicles.size()==5)
	assert(scene._snapshot().traffic.active==5)
	scene._new_terrain()
	assert(scene.model.traffic.vehicles.is_empty())
	scene.free()
	print("VEHICLE_UI_OK: cinco modelos, pausa, toque, localização, mapas, salvamento e layout 1280x640")
	quit()
