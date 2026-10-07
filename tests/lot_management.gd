extends SceneTree
const Network=preload("res://scripts/streets_model.gd")
const Store=preload("res://scripts/city_store.gd")
func flat(_x: float,_z: float)->float: return 0.5
func lot(model,point: Vector2,zone: String,size_mode: String="small")->Dictionary:
	var value: Dictionary=model.housing.candidate(point,model.roads,flat,zone,size_mode)
	assert(not value.is_empty())
	value["utility_exempt"]=true # Isola a regra anterior; infraestrutura tem teste próprio.
	model.housing.commit(value)
	return model.housing.lots[-1]
func _initialize()->void:
	var model=Network.new()
	assert(model.commit(Vector2(-80,0),Vector2(70,0)))
	lot(model,Vector2(-62,-8),"commercial")
	var waiting:=lot(model,Vector2(-44,-8),"commercial")
	lot(model,Vector2(-25,8),"residential")
	lot(model,Vector2(30,11),"industrial","large")
	model.simulate(25)
	assert(waiting.demand_pending)
	assert(model.travel.moving_count()>0)
	assert(not model.evaluate(Vector2(-44,0),Vector2(-44,-24)).valid,"Lote reservado impede rua")
	var cash_before: int=model.cash
	var names: Array=[]
	var balances: Array=[]
	var positions: Array=[]
	var paths: Array=[]
	for person in model.housing.residents:
		names.append(person.name)
		balances.append(person.balance)
	for agent in model.travel.agents:
		positions.append(model.travel.position(agent,model.housing))
		paths.append(agent.points.duplicate())
	var employer_cash: int=model.housing.lots[3].business.cash
	assert(not model.change_waiting_zone(3,"commercial").ok,"Não alterar imóvel concluído")
	assert(not model.change_waiting_zone(2,"unknown").ok)
	assert(model.cancel_unfinished_lot(2).ok)
	assert(model.cash==cash_before)
	assert(model.evaluate(Vector2(-44,0),Vector2(-44,-24)).valid,"Cancelar libera espaço para rua")
	assert(model.housing.lots.size()==3)
	for i in range(model.housing.residents.size()):
		var person: Dictionary=model.housing.residents[i]
		assert(person.home==2 and person.job==3)
		assert(person.name==names[i] and person.balance==balances[i])
		assert(model.travel.position(model.travel.agents[i],model.housing).distance_to(positions[i])<0.001)
		assert(model.travel.agents[i].points==paths[i])
	assert(model.housing.lots[2].business.cash==employer_cash)
	# Cancelar também uma obra em andamento, preservando novamente referências.
	assert(model.housing.lots[0].age>0 and model.housing.lots[0].stage<2)
	assert(model.cancel_unfinished_lot(1).ok)
	assert(model.housing.residents[0].home==1 and model.housing.residents[0].job==2)
	assert(not model.cancel_unfinished_lot(1).ok,"Não remover moradia com pessoas")
	assert(not model.cancel_unfinished_lot(2).ok,"Não remover empresa concluída")
	assert(not model.cancel_unfinished_lot(0).ok)
	assert(model.housing.economy.account_total(model.housing)==0)
	var store=Store.new()
	store.base_path="user://lot_management_test.json"
	assert(store.save_city(42,model))
	var copy=Network.restore(store.load_city())
	assert(copy!=null and copy.cash==cash_before)
	for i in range(copy.travel.agents.size()):
		assert(copy.travel.position(copy.travel.agents[i],copy.housing).distance_to(positions[i])<0.001)
	copy.simulate(180)
	assert(copy.housing.economy.last.wages+copy.housing.economy.current.wages>0,"Pagar no mesmo emprego após renumerar lotes")
	assert(copy.housing.economy.account_total(copy.housing)==0)
	assert(store.save_city(42,copy))
	assert(Network.restore(store.load_city())!=null)
	# Trocar uso preserva área; só vale enquanto a obra ainda aguarda.
	var fresh=Network.new()
	assert(fresh.commit(Vector2(-80,0),Vector2(70,0)))
	var target:=lot(fresh,Vector2(-30,8),"commercial")
	var geometry: PackedVector2Array=fresh.housing.polygon(target)
	assert(fresh.change_waiting_zone(1,"residential").ok)
	assert(target.demand_pending and target.zone=="residential")
	assert(fresh.housing.polygon(target)==geometry)
	assert(Network.restore(JSON.parse_string(JSON.stringify(fresh.serialize())))!=null)
	fresh.simulate(1)
	assert(not target.demand_pending)
	assert(not fresh.change_waiting_zone(1,"industrial").ok)
	assert(fresh.cancel_unfinished_lot(1).ok)
	assert(fresh.housing.lots.is_empty() and fresh.housing.residents.is_empty())
	assert(Network.restore(JSON.parse_string(JSON.stringify(fresh.serialize())))!=null)
	print("LOT_MANAGEMENT_OK: troca de uso, cancelamento, espaço livre, referências, rotas, pagamentos e recarga")
	quit()
