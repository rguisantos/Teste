extends SceneTree
const Network=preload("res://scripts/streets_model.gd")
const Routes=preload("res://scripts/citizen_routes.gd")
func flat(_x:float,_z:float)->float:return 0.5
func add(model,p:Vector2)->Dictionary:
	var lot:Dictionary=model.housing.candidate(p,model.roads,flat,"residential","small")
	assert(not lot.is_empty() and model.place_lot(lot).ok)
	return model.housing.lots[-1]
func reload(model):
	var copy=Network.restore(JSON.parse_string(JSON.stringify(model.serialize())))
	assert(copy!=null and copy.cash==model.cash and copy.construction_spent==model.construction_spent)
	return copy
func _initialize()->void:
	var model=Network.new()
	assert(model.commit(Vector2(-80,0),Vector2(60,0)))
	assert(model.commit(Vector2(0,0),Vector2(0,60)))
	var a:=add(model,Vector2(-40,9))
	var b:=add(model,Vector2(30,9))
	var c:=add(model,Vector2(9,30))
	var target:Dictionary=model.pick_demolition_road(Vector2(-30,0))
	var before:=JSON.stringify(model.serialize())
	var impact:Dictionary=model.demolition_impact(target)
	assert(impact.valid and impact.no_road==[1] and impact.isolated==[2,3])
	assert(JSON.stringify(model.serialize())==before,"Prévia de impacto não altera cidade")
	var route:PackedVector2Array=Routes.new().route(model,1,2)
	var cost:int=model.cash
	var length:float=model.road_length()
	var quote:Dictionary=model.upgrade_quote(target)
	assert(quote.valid and quote.cost==3200 and quote.maintenance_after==16)
	assert(model.upgrade_road(target).ok)
	assert(model.cash==cost-3200 and model.road_length()==length and model.housing.lots.size()==3)
	assert(a.road>=0 and b.road>=0 and c.road>=0)
	assert(Routes.new().route(model,1,2)==route,"Asfaltar não muda caminho nem portas")
	assert(model.budget_details().active.roads==quote.maintenance_after)
	assert(model.budget_forecast().roads==quote.maintenance_after)
	var paved:Dictionary=model.pick_demolition_road(Vector2(-30,0))
	assert(not model.upgrade_quote(paved).valid)
	var paid:int=model.cash
	assert(not model.upgrade_road(paved).ok and model.cash==paid,"Não cobrar asfalto repetido")
	model=reload(model)
	model.simulate(180)
	assert(model.housing.economy.last_maintenance.roads==quote.maintenance_after)
	reload(model)
	# Demolir parte de rua asfaltada mantém piso dos trechos remanescentes.
	assert(model.commit(Vector2(-40,0),Vector2(-40,-40)))
	assert(model.demolish_road(model.pick_demolition_road(Vector2(-60,0))).ok)
	model=reload(model)
	assert(model.roads[int(model.pick_demolition_road(Vector2(-20,0)).road)].surface=="asphalt")
	# Nova rua, curva, migração e dados inválidos.
	var curved=Network.new()
	assert(curved.commit(Vector2(-80,0),Vector2(-20,40),Vector2(-65,45),"asphalt"))
	assert(curved.roads[0].surface=="asphalt")
	curved=reload(curved)
	var bad:Dictionary=curved.serialize()
	bad.roads[0].surface="lava"
	assert(Network.restore(bad)==null)
	var cash_before:int=curved.cash
	curved.cash=0
	assert(not curved.commit(Vector2(-20,40),Vector2(20,40),null,"asphalt"))
	curved.cash=cash_before
	var legacy:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/city-0.0.17.json"))
	assert(legacy.network_version==2 and not legacy.roads[0].has("surface"))
	var migrated=Network.restore(legacy)
	assert(migrated!=null and migrated.cash==int(legacy.cash))
	for road in migrated.roads: assert(road.surface=="dirt")
	for key in migrated.housing.economy.last: assert(migrated.housing.economy.last[key]==int(legacy.residential.economy.last[key]))
	var positions:Array=[]
	for agent in migrated.travel.agents: positions.append(migrated.travel.position(agent,migrated.housing))
	assert(migrated.upgrade_road(migrated.pick_demolition_road(Vector2(-20,0))).ok)
	var restored=reload(migrated)
	for i in range(restored.travel.agents.size()):
		assert(restored.travel.position(restored.travel.agents[i],restored.housing).distance_to(positions[i])<0.01)
	assert(restored.housing.economy.account_total(restored.housing)==0)
	# Sem saldo: cotação e confirmação recusam e não modificam o piso.
	var poor=Network.new()
	assert(poor.commit(Vector2(-80,0),Vector2(0,0)))
	poor.cash=10
	var choice:Dictionary=poor.pick_demolition_road(Vector2(-40,0))
	assert(not poor.upgrade_quote(choice).valid and not poor.upgrade_road(choice).ok and poor.cash==10 and poor.roads[0].surface=="dirt")
	print("ROAD_UPGRADES_OK: trechos, custos, manutenção real/prevista, acesso, curvas, demolição, migração 0.0.17 e viagens")
	quit()
