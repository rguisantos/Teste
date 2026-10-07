extends SceneTree
const Network = preload("res://scripts/streets_model.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var terrain = preload("res://scripts/landscape.gd").new()
	root.add_child(terrain)
	terrain.generate(42)
	var model = Network.new()
	assert(model.commit(Vector2(-80,0),Vector2(80,0)))
	assert(model.commit(Vector2(60,0),Vector2(60,72)))
	assert(model.commit(Vector2(60,72),Vector2(-24,60),Vector2(0,88)))
	var original: float = terrain.natural_height_at(70,3)
	terrain.clear_roads(model.roads)
	assert(absf(terrain.height_at(70,3)-original) > 0.001, "Terraplenagem deve alterar o relevo sob a pista")
	for x in [-70.0,-40.0,0.0,30.0,75.0]:
		assert(absf(terrain.road_height_at(x,-3)-terrain.road_height_at(x,3)) < 0.0001, "Pista sem inclinação transversal")
		assert(absf(terrain.height_at(x,3)-terrain.road_height_at(x,3)) < 0.0001)
	assert(absf(terrain.height_at(30,11)-terrain.natural_height_at(30,11)) < 0.0001, "Fora do talude preserva relevo natural")
	var h: float = terrain.road_height_at(60,0)
	for p in [Vector2(57,0),Vector2(63,0),Vector2(60,3),Vector2(60,-3)]:
		assert(absf(terrain.road_height_at(p.x,p.y)-h) < 0.0001, "Cruzamento compartilha patamar")
	for segment in terrain.grade.segments:
		assert(absf(segment.ha-segment.hb) <= segment.a.distance_to(segment.b)*0.0801, "Perfil longitudinal suaviza rampas")
	var curve: PackedVector2Array = model.roads[2].points
	for i in range(3,curve.size()-3,3):
		var point := curve[i]
		var direction := (curve[i+1]-curve[i-1]).normalized()
		var side := Vector2(-direction.y,direction.x)*2
		assert(absf(terrain.road_height_at((point+side).x,(point+side).y)-terrain.road_height_at((point-side).x,(point-side).y)) < 0.025, "Curvas mantêm perfil transversal")
	var before: float = terrain.height_at(70,3)
	var cash: int = model.cash
	terrain.generate(42)
	terrain.clear_roads(Network.restore(model.serialize()).roads)
	assert(absf(before-terrain.height_at(70,3)) < 0.00001 and model.cash == cash, "Recarga reproduz nivelamento sem cobrar novamente")
	var view = preload("res://scripts/road_view.gd").new()
	view.terrain=terrain
	root.add_child(view)
	var mesh: ArrayMesh = view._mesh(model.roads)
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in range(0,vertices.size(),7):
		var point := vertices[i]
		assert(point.y >= _rendered_height(terrain, Vector2(point.x,point.z))-0.001, "Terreno renderizado não deve atravessar a pista")
	view.show_preview(Vector2(80,0),Vector2(84,40),true)
	assert(absf(before-terrain.height_at(70,3)) < 0.00001, "Prévia não modifica terreno")
	view.free()
	terrain.free()
	print("GRADING_OK: pista, taludes, curvas, junções, rampa, recarga e prévia sem alteração")
	quit()

func _rendered_height(terrain: Node3D, point: Vector2) -> float:
	var cell := (point + Vector2.ONE*96.0)/2.4
	var x := clampi(floori(cell.x),0,79)
	var z := clampi(floori(cell.y),0,79)
	var u := cell.x-x
	var v := cell.y-z
	var a: Vector3 = terrain._point(x,z)
	var b: Vector3 = terrain._point(x+1,z)
	var c: Vector3 = terrain._point(x,z+1)
	var d: Vector3 = terrain._point(x+1,z+1)
	return a.y+(b.y-a.y)*u+(c.y-a.y)*v if u+v <= 1.0 else d.y+(c.y-d.y)*(1.0-u)+(b.y-d.y)*(1.0-v)
