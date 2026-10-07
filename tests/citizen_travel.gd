extends SceneTree
const Network = preload("res://scripts/streets_model.gd")
const Routes = preload("res://scripts/citizen_routes.gd")
func flat(_x: float, _z: float) -> float: return 0.5
func lot(model, point: Vector2, zone: String) -> Dictionary:
	var value: Dictionary=model.housing.candidate(point,model.roads,flat,zone,"small")
	assert(not value.is_empty())
	value["utility_exempt"]=true # Isola a regra anterior; infraestrutura tem teste próprio.
	model.housing.commit(value)
	return value
func _initialize() -> void:
	var model=Network.new()
	assert(model.commit(Vector2(-80,0),Vector2(0,0)))
	assert(model.commit(Vector2(0,0),Vector2(0,60)))
	lot(model,Vector2(-60,8),"residential")
	lot(model,Vector2(8,48),"industrial")
	model.housing.advance(24)
	model.travel.sync(model)
	var router=Routes.new()
	var path: PackedVector2Array=router.route(model,1,2)
	assert(Routes.length(path)>100,"Percurso precisa contornar o L")
	assert(not path.has(Vector2.ZERO),"Contornar esquina pelas bordas")
	model.simulate(2)
	assert(model.travel.moving_count()>0)
	assert(model.housing.economy.current.wages==0,"Não pagar antes de chegar")
	var position_before: Vector2=model.travel.position(model.travel.agents[0],model.housing)
	var restored=Network.restore(JSON.parse_string(JSON.stringify(model.serialize())))
	assert(restored!=null)
	assert(restored.travel.position(restored.travel.agents[0],restored.housing).distance_to(position_before)<0.001)
	model.simulate(8)
	restored.simulate(8)
	assert(model.travel.position(model.travel.agents[0],model.housing).distance_to(restored.travel.position(restored.travel.agents[0],restored.housing))<0.001)
	assert(model.housing.economy.current.wages==0)
	restored.simulate(Routes.length(path)/preload("res://scripts/citizen_travel.gd").SPEED+preload("res://scripts/citizen_travel.gd").WORK_STAY+5)
	assert(restored.housing.economy.current.wages>0)
	var paid: int=restored.housing.economy.current.wages
	restored=Network.restore(JSON.parse_string(JSON.stringify(restored.serialize())))
	assert(restored!=null)
	restored.simulate(10)
	assert(restored.housing.economy.current.wages==paid,"Não pagar outra vez no mesmo dia após recarga")
	assert(restored.housing.economy.account_total(restored.housing)==0)
	var corrupt: Dictionary=restored.serialize()
	corrupt.travel.agents[0].distance=-1
	assert(Network.restore(corrupt)==null)
	# Via curva: pontos internos seguem as arestas, inclusive entre amostras.
	var curve=Network.new()
	assert(curve.commit(Vector2(-80,0),Vector2(-32,24),Vector2(-64,40)))
	lot(curve,Vector2(-76,12),"residential")
	lot(curve,Vector2(-35,32),"industrial")
	var curved: PackedVector2Array=Routes.new().route(curve,1,2)
	assert(curved.size()>4)
	for i in range(1,curved.size()-1):
		var closest:=INF
		for edge in curve.edges:
			closest=minf(closest,curved[i].distance_to(Geometry2D.get_closest_point_to_segment(curved[i],curve.nodes[edge.from],curve.nodes[edge.to])))
		assert(closest>=3.45 and closest<5.0,"Caminhar fora da pista de 7 m, junto à borda")
	var legacy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/city-0.0.8.json"))
	assert(not legacy.has("travel"))
	var migrated=Network.restore(legacy)
	assert(migrated!=null and migrated.cash==int(legacy.cash))
	assert(migrated.housing.residents.size()==legacy.residential.residents.size())
	for i in range(migrated.housing.residents.size()):
		for key in ["id","home","name","age","balance","job"]:
			assert(migrated.housing.residents[i][key]==legacy.residential.residents[i][key])
	migrated.simulate(20)
	assert(migrated.housing.economy.current.wages==0 and migrated.housing.economy.current.sales==0,"Não repetir pagamentos da 0.0.8 no dia já creditado")
	assert(migrated.housing.economy.account_total(migrated.housing)==0)
	migrated.simulate(migrated.housing.economy.DAY_SECONDS)
	# Caminhada mais lenta: aguarda chegada e permanência, sem presumir tempo fixo.
	for step in range(36):
		if migrated.housing.economy.current.wages>0: break
		migrated.simulate(5)
	assert(migrated.housing.economy.current.wages>0)
	print("CITIZEN_TRAVEL_OK: ruas em L e curvas, pagamento por chegada, progresso persistente, contas e validação")
	quit()
