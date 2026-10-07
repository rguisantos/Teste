extends SceneTree

const Network = preload("res://scripts/streets_model.gd")
const Surface = preload("res://scripts/road_surface.gd")
const Store = preload("res://scripts/city_store.gd")

func _initialize() -> void:
	var model = Network.new()
	assert(not model.commit(Vector2.ZERO, Vector2(40, 0)), "Trecho isolado deve ser recusado")
	assert(model.cash == 100000)
	assert(model.commit(Vector2(-80, 0), Vector2(-40, 0)))
	assert(model.cash == 98400)
	assert(not model.commit(Vector2(-80, 0), Vector2(-40, 0)), "Sobreposição não cobra de novo")
	assert(model.cash == 98400)
	assert(model.commit(Vector2(-60, 0), Vector2(-60, 40)), "Ramificação em T deve conectar")
	assert(model.commit(Vector2(-60, 40), Vector2(0, 40)))
	var data: Dictionary = model.serialize()
	assert(Network.restore(data).cash == model.cash)
	var corrupt := data.duplicate(true)
	corrupt.cash += 1
	assert(Network.restore(corrupt) == null, "Conta inconsistente deve ser recusada")
	var store = Store.new()
	store.base_path = "user://roads_regression.json"
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store.base_path + suffix))
	assert(store.save_city(42, model))
	assert(store.save_city(42, model))
	var file := FileAccess.open(store.base_path, FileAccess.WRITE)
	file.store_string("arquivo interrompido")
	file.close()
	assert(store.load_city().roads.size() == 3, "Cópia anterior deve recuperar gravação inválida")
	assert(store.save_city(42, model), "Salvar após recuperação deve preservar cópia válida")
	for cycle in range(3):
		var restored: Dictionary = store.load_city()
		model = Network.restore(restored)
		assert(model.roads.size() == 3 and model.cash == 94400)
		assert(store.save_city(int(restored.seed), model))
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store.base_path + suffix))
	var legacy := {"roads": [{"a": [-80, 0], "b": [-40, 0]}, {"a": [-60, 0], "b": [-60, 40]}], "cash": 96800}
	assert(Network.restore(legacy).cash == 96800, "Cidade 0.0.3 mantém ruas e caixa")
	var diagonal = Network.new()
	assert(diagonal.commit(Vector2(-80, 0), Vector2(0, 0)))
	assert(diagonal.commit(Vector2(0, 0), Vector2(0, 40)))
	assert(diagonal.commit(Vector2(0, 40), Vector2(-40, -40)))
	assert(diagonal.degree(Vector2(-20, 0)) == 4, "X deve dividir as duas ruas no cruzamento")
	var snapped: Vector2 = diagonal.pick_start(Vector2(-29, 2))
	assert(snapped.distance_to(Vector2(-29, 0)) < 0.01, "Encaixe não pode afastar ponto para a grade")
	assert(diagonal.commit(snapped, Vector2(-12, -32)))
	assert(diagonal.degree(snapped) == 3, "T em ponto fora da grade deve conectar")
	var curve = Network.new()
	var a := Vector2(-80, 0)
	var b := Vector2(-32, 24)
	var c := Vector2(-64, 40)
	var quote: Dictionary = curve.evaluate(a, b, c)
	assert(quote.valid and quote.length > a.distance_to(b))
	assert(curve.commit(a, b, c))
	assert(curve.cash == 100000 - quote.cost)
	assert(not curve.commit(a, b, c), "Curva repetida não cobra duas vezes")
	var midpoint: Vector2 = curve.roads[0].points[curve.roads[0].points.size() / 2]
	assert(curve.commit(midpoint, midpoint + Vector2(0, 24)))
	assert(curve.degree(midpoint) == 3)
	var resumed = Network.restore(curve.serialize())
	assert(resumed != null and resumed.cash == curve.cash)
	assert(resumed.roads[0].points == curve.roads[0].points, "Curva e preço permanecem iguais ao retomar")
	assert(not curve.evaluate(a, b, Vector2(INF, 0)).valid)
	var loop: Array[Dictionary] = []
	for pair in [[Vector2(-40, 0), Vector2(0, 0)], [Vector2(0, 0), Vector2(0, 40)], [Vector2(0, 40), Vector2(-40, 40)], [Vector2(-40, 40), Vector2(-40, 0)]]:
		loop.append({"points": PackedVector2Array(pair)})
	var triangles := Surface.triangles(Surface.polygons(loop))
	assert(not triangles.is_empty())
	assert(not _covered(Vector2(-20, 20), triangles), "União não deve pavimentar o interior da quadra")
	for point in [Vector2(-40, 0), Vector2(0, 0), Vector2(0, 40), Vector2(-40, 40), Vector2(-20, 2), Vector2(2, 20)]:
		assert(_covered(point, triangles), "Esquinas e faixas devem ficar completas")
	assert(not _covered(Vector2(3.4, -3.4), triangles), "Esquina arredondada não tem ponta quadrada saliente")
	var area := 0.0
	for i in range(0, triangles.size(), 3):
		area += absf((triangles[i + 1] - triangles[i]).cross(triangles[i + 2] - triangles[i])) * 0.5
	assert(area > 1050 and area < 1120, "União elimina área duplicada nas junções")
	var curved_surface := Surface.triangles(Surface.polygons(curve.roads))
	assert(_covered(midpoint, curved_surface), "Superfície acompanha a curva")
	var debug := FileAccess.open("user://road_surface_qa.json", FileAccess.WRITE)
	var vertices: Array = []
	for point in triangles:
		vertices.append([point.x, point.y])
	debug.store_string(JSON.stringify(vertices))
	debug.close()
	print("ROADS_OK: diagonais, curvas, nós L/T/X, união, quadras, custo e recuperação")
	quit(0)

func _covered(point: Vector2, triangles: PackedVector2Array) -> bool:
	for i in range(0, triangles.size(), 3):
		if Geometry2D.point_is_inside_triangle(point, triangles[i], triangles[i + 2], triangles[i + 1]):
			return true
	return false
