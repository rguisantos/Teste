extends SceneTree
const Network=preload("res://scripts/streets_model.gd")
const Routes=preload("res://scripts/citizen_routes.gd")
const Travel=preload("res://scripts/citizen_travel.gd")
func flat(_x: float,_z: float)->float: return 0.5
func lot(model, point: Vector2, zone: String)->Dictionary:
	var value: Dictionary=model.housing.candidate(point,model.roads,flat,zone,"small")
	assert(not value.is_empty())
	value["utility_exempt"]=true # Isola a regra anterior; infraestrutura tem teste próprio.
	model.housing.commit(value)
	return value
func on_crossing(router, p: Vector2)->bool:
	for pair in router.crossings:
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p,pair[0],pair[1]))<0.05: return true
	return false
func nearest_road(model, p: Vector2)->float:
	var result:=INF
	for edge in model.edges:
		result=minf(result,p.distance_to(Geometry2D.get_closest_point_to_segment(p,model.nodes[edge.from],model.nodes[edge.to])))
	return result
func check_path(model,router,path: PackedVector2Array)->void:
	assert(not path.is_empty())
	for i in range(ceili(Routes.length(path)*4)):
		var p:=Routes.position(path,i/4.0)
		if nearest_road(model,p)<3.5:
			if not on_crossing(router,p): print("BAD_POINT ",p," PATH ",path," CROSS ",router.crossings)
			assert(on_crossing(router,p),"Só entrar na pista em uma travessia da esquina")
func _initialize()->void:
	# Mesma lateral: caminho direto na borda, sem ida ao cruzamento.
	var straight=Network.new()
	assert(straight.commit(Vector2(-80,0),Vector2(60,0)))
	lot(straight,Vector2(-50,8),"residential")
	lot(straight,Vector2(20,8),"industrial")
	lot(straight,Vector2(20,-8),"commercial")
	var router=Routes.new()
	var same: PackedVector2Array=router.route(straight,1,2)
	check_path(straight,router,same)
	assert(Routes.length(same)<75)
	var opposite: PackedVector2Array=router.route(straight,1,3)
	check_path(straight,router,opposite)
	assert(Routes.length(opposite)>100,"Rua sem esquina permite contornar o final, sem atravessar no meio")
	# L, T e X: aproximação pelas bordas e travessia na boca da via.
	for arms in [1,2,3]:
		var junction=Network.new()
		assert(junction.commit(Vector2(-80,0),Vector2(0,0)))
		assert(junction.commit(Vector2(0,0),Vector2(0,60)))
		if arms>=2: assert(junction.commit(Vector2(0,0),Vector2(60,0)))
		if arms>=3: assert(junction.commit(Vector2(0,0),Vector2(0,-60)))
		lot(junction,Vector2(-50,8),"residential")
		lot(junction,Vector2(8,40),"industrial")
		lot(junction,Vector2(-50,-8),"commercial")
		var network_router=Routes.new()
		check_path(junction,network_router,network_router.route(junction,1,2))
		check_path(junction,network_router,network_router.route(junction,1,3))
	# Migração autêntica da 0.0.9: calendário proporcional e saldos inalterados.
	var legacy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/city-0.0.9.json"))
	var restored=Network.restore(legacy)
	assert(restored!=null)
	assert(restored.housing.economy.day==int(legacy.residential.economy.day))
	assert(is_equal_approx(restored.housing.economy.elapsed,float(legacy.residential.economy.elapsed)*6))
	assert(restored.cash==int(legacy.cash))
	for i in range(restored.housing.residents.size()):
		assert(restored.housing.residents[i].balance==legacy.residential.residents[i].balance)
		var agent: Dictionary=restored.travel.agents[i]
		for key in ["visited_work_day","worked_day","bought_day","shop_try_day","purpose","target","phase"]:
			assert(agent[key]==legacy.travel.agents[i][key])
		if agent.phase=="walking":
			check_path(restored,restored.travel.router,agent.points)

	var distances: Array=[]
	for agent in restored.travel.agents: distances.append(agent.distance)
	restored.travel.advance(0.1,restored)
	for i in range(restored.travel.agents.size()):
		assert(restored.travel.agents[i].distance-distances[i]<=Travel.SPEED*0.1+0.0001)
	assert(restored.housing.economy.account_total(restored.housing)==0)
	var copy=Network.restore(JSON.parse_string(JSON.stringify(restored.serialize())))
	assert(copy!=null)
	for i in range(copy.travel.agents.size()):
		assert(copy.travel.position(copy.travel.agents[i],copy.housing).distance_to(restored.travel.position(restored.travel.agents[i],restored.housing))<0.001)
		assert(is_equal_approx(copy.travel.agents[i].wait,restored.travel.agents[i].wait))
	assert(is_equal_approx(copy.housing.economy.elapsed,restored.housing.economy.elapsed))
	print("PEDESTRIAN_EDGES_OK: bordas, L/T/X, travessias, velocidade, migração 0.0.9 e recarga")
	quit()
