extends SceneTree
const Network = preload("res://scripts/streets_model.gd")
const Housing = preload("res://scripts/residential.gd")
const Store = preload("res://scripts/city_store.gd")

func _initialize() -> void:
	call_deferred("_run")

func flat(_x: float, _z: float) -> float:
	return 0.5

func _run() -> void:
	var network = Network.new()
	assert(network.commit(Vector2(-80,0), Vector2(60,0)))
	var lot: Dictionary = network.housing.candidate(Vector2(-25,11), network.roads, flat)
	assert(not lot.is_empty())
	var original_cash: int = network.cash
	assert(network.housing.lots.is_empty(), "Prévia não modifica cidade")
	lot["utility_exempt"]=true # Isola a regra anterior; infraestrutura tem teste próprio.
	network.housing.commit(lot)
	assert(network.cash == original_cash, "Zoneamento gratuito")
	var next: Dictionary = network.housing.candidate(Vector2(-25,11), network.roads, flat)
	if not next.is_empty():
		assert(Geometry2D.intersect_polygons(Housing.polygon(lot), Housing.polygon(next)).is_empty())
	assert(not network.evaluate(Vector2(lot.x, 0), Vector2(lot.x, 30)).valid, "Rua nova deve proteger casas")
	assert(network.housing.advance(6))
	assert(network.housing.lots[0].stage == 1)
	var restored = Network.restore(network.serialize())
	assert(restored != null and restored.housing.lots[0].stage == 1)
	assert(restored.housing.advance(18))
	assert(restored.housing.residents.size() == 3)
	assert(not restored.housing.advance(40))
	assert(restored.housing.residents.size() == 3, "Moradores não duplicam")
	var store = Store.new()
	store.base_path = "user://residential_test.json"
	assert(store.save_city(42, restored))
	var loaded = Network.restore(store.load_city())
	assert(loaded.housing.residents == restored.housing.residents, "Persistência dos moradores")
	assert(loaded.housing.lots.size() == restored.housing.lots.size())
	for i in range(loaded.housing.lots.size()):
		for key in ["x","z","height","angle","age","width","depth"]:
			assert(is_equal_approx(loaded.housing.lots[i][key],restored.housing.lots[i][key]),"Preservar geometria do imóvel após JSON")
		assert(loaded.housing.lots[i].stage == restored.housing.lots[i].stage)
	var legacy: Dictionary = network.serialize()
	legacy.erase("residential")
	assert(Network.restore(legacy).housing.lots.is_empty(), "Compatibilidade 0.0.6")
	var invalid: Dictionary = restored.serialize()
	invalid.residential.residents.append(invalid.residential.residents[0])
	assert(Network.restore(invalid) == null, "Registro duplicado rejeitado")
	var curve = Network.new()
	assert(curve.commit(Vector2(-80,0), Vector2(40,40), Vector2(-10,-30)))
	var found := 0
	for x in range(-60,40,12):
		for z in range(-30,60,12):
			var candidate: Dictionary = curve.housing.candidate(Vector2(x,z), curve.roads, flat)
			if not candidate.is_empty():
				assert(not Housing.road_conflict(candidate, curve.roads))
				candidate["utility_exempt"]=true # Isola a regra anterior; infraestrutura tem teste próprio.
				curve.housing.commit(candidate)
				found += 1
	assert(found > 4, "Curvas precisam gerar lotes úteis")
	assert(Network.restore(curve.serialize()) != null)
	print("RESIDENTIAL_OK: curvas, colisão, construção, moradores, persistência e migração")
	quit()
