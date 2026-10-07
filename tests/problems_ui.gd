extends SceneTree
var scene
func _initialize()->void:call_deferred("_run")
func tap(target:Button)->void:
	await process_frame
	assert(target!=null and target.is_visible_in_tree())
	await touch(target.get_global_rect().get_center())
func touch(point:Vector2)->void:
	for pressed in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.position=point
		event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame
func visible_buttons_fit()->void:
	for child in scene.find_children("*","Button",true,false):
		if child.is_visible_in_tree():
			var rect:Rect2=child.get_global_rect()
			# Scroll contents may extend beyond the viewport; fixed controls must fit.
			if scene.problem_rows.has(child):continue
			assert(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=1280 and rect.end.y<=640,child.text)
func _run()->void:
	root.content_scale_size=Vector2i(1280,640)
	root.size=Vector2i(1280,640)
	scene=load("res://main.tscn").instantiate()
	scene.paused=true
	scene.store.base_path="user://problems_ui_test.json"
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.store.base_path+suffix))
	root.add_child(scene)
	await process_frame
	await process_frame
	assert(scene.model.commit(Vector2(-80,0),Vector2(70,0)))
	scene.road_view.rebuild(scene.model.roads)
	for x in [-25,0]:
		var lot:Dictionary=scene.model.housing.candidate(Vector2(x,9),scene.model.roads,scene.terrain.height_at,"residential","small")
		assert(not lot.is_empty() and scene.model.place_lot(lot).ok)
	scene._refresh_housing()
	scene._refresh_status()
	await process_frame
	assert(scene.problems_button.text=="Avisos 2")
	assert(scene.alert_view.entries.size()==2)
	scene.alert_view.project()
	assert(scene.alert_view.bounds.size()==2)
	var cash:int=scene.model.cash
	# Actual map badge touch opens details, focuses the camera and leaves cash intact.
	var point:Vector2=scene.alert_view.bounds[0].rect.get_center()
	await touch(point)
	assert(scene.lot_panel.visible and scene.inspected_lot_id>0)
	assert(scene.lot_problem_label.text.contains("Falta água") and scene.lot_problem_label.text.contains("Conecte"))
	assert(scene.city_camera.distance==48 and scene.model.cash==cash)
	await tap(scene.lot_problem_map)
	assert(scene.coverage_kind=="water" and not scene.alert_view.visible)
	scene._close_lot_panel()
	await tap(scene.problems_button)
	assert(scene.problems_panel.visible and scene.coverage_kind=="" and not scene.build_actions.visible)
	assert(scene.problem_rows.size()==2)
	await tap(scene.problem_filters.access)
	assert(scene.problem_rows.is_empty())
	await tap(scene.problem_filters.services)
	assert(scene.problem_rows.size()==2)
	visible_buttons_fit()
	await tap(scene.problem_rows[0])
	assert(scene.lot_panel.visible and not scene.problems_panel.visible)
	await process_frame
	visible_buttons_fit()
	# Economy tabs, last-day unknown details and small-screen fixed controls.
	scene._toggle_economy()
	await process_frame
	assert(scene.economy_panel.visible and not scene.lot_panel.visible)
	await tap(scene.budget_tabs.active)
	assert(scene.budget_mode=="active" and scene.budget_summary.text.contains("concluídas"))
	await tap(scene.budget_tabs.authorized)
	assert(scene.budget_summary.text.contains("em obra"))
	visible_buttons_fit()
	var legacy:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/city-0.0.16.json"))
	scene.model=preload("res://scripts/streets_model.gd").restore(legacy)
	assert(scene.model!=null)
	await tap(scene.budget_tabs.last)
	assert(scene.budget_summary.text.contains("não foi discriminada"))
	var found:=false
	for label in scene.budget_grid.get_children():
		if label.text.contains("Não discriminado"):found=true
	assert(found)
	visible_buttons_fit()
	# Snapshot refresh after mutation; stale targets cannot select a different address.
	scene._toggle_problems()
	await process_frame
	assert(scene.problems_panel.visible)
	scene._new_terrain()
	await process_frame
	assert(not scene.problems_panel.visible and scene.problems_button.text=="Avisos 0")
	assert(scene.alert_view.entries.is_empty())
	print("PROBLEMS_UI_OK: ícones por toque, foco, causas, filtros, mapas, orçamento, migração e tela 1280×640")
	scene.free()
	quit()
