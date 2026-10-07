extends SceneTree
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var terrain = preload("res://scripts/landscape.gd").new()
	root.add_child(terrain)
	terrain.generate(42)
	var view = preload("res://scripts/road_view.gd").new()
	view.terrain = terrain
	root.add_child(view)
	var roads: Array[Dictionary] = [{"points": preload("res://scripts/streets_model.gd").path(Vector2(-80,0), Vector2(0,24), Vector2(-40,40))}]
	_check(view._mesh(roads))
	_check(terrain.generated_root.get_child(0).mesh)
	assert(view._material(Color(0.5,0.32,0.18)).cull_mode == BaseMaterial3D.CULL_BACK)
	view.free()
	terrain.free()
	print("NORMALS_OK: faces e normais das ruas e do terreno voltadas para cima")
	quit()
func _check(mesh: ArrayMesh) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for normal in normals:
		assert(normal.y > 0.8, "Normal deve apontar para cima")
	for i in range(0, indices.size(), 3):
		var a := vertices[indices[i]]
		var b := vertices[indices[i+1]]
		var c := vertices[indices[i+2]]
		assert((b-a).cross(c-a).y <= 0, "Godot usa faces frontais em sentido horário")
