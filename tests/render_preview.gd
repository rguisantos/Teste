extends SceneTree
var scene
const Routes=preload("res://scripts/vehicle_routes.gd")
func _initialize()->void:call_deferred("_run")
func shot(name:String)->void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OS.get_environment("CITY_PREVIEW_DIR")+"/"+name+".png")
func _run()->void:
	root.content_scale_size=Vector2i(1280,640);root.size=Vector2i(1280,640)
	scene=load("res://main.tscn").instantiate()
	scene.paused=true
	scene.store.base_path="user://render019-unused.json"
	root.add_child(scene)
	await process_frame
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/city-0.0.18.json"))
	scene.model=preload("res://scripts/streets_model.gd").restore(data)
	scene.terrain.generate(1042026)
	assert(scene.model.upgrade_road(scene.model.pick_demolition_road(Vector2(30,0))).ok)
	for pair in [["hatch",3],["sedan",4],["motorcycle",5],["light_truck",13],["heavy_truck",8]]:
		assert(scene.model.traffic.enqueue(scene.model,pair[0],Routes.address(scene.model.housing.lots[pair[1]-1]),{"entry":true}))
	for i in range(15):scene.model.traffic.advance(0.1,scene.model)
	scene.road_view.rebuild(scene.model.roads)
	scene._refresh_housing();scene._refresh_status();scene._navigate()
	scene.city_camera.distance=67
	scene.city_camera.focus=Vector3(-12,0.5,0)
	scene.city_camera.yaw=0.15;scene.city_camera._apply()
	await shot("vehicles019")
	scene._toggle_traffic()
	await shot("traffic019")
	for kind in ["hatch","sedan","motorcycle","light_truck","heavy_truck"]:
		scene._locate_vehicle(kind)
		scene.city_camera.distance=27
		scene.city_camera._apply()
		await shot(kind+"019")
	print("RENDER_OK")
	scene.free();quit()
