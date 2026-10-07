extends SceneTree
const Network=preload("res://scripts/streets_model.gd")
const Utilities=preload("res://scripts/city_utilities.gd")
func flat(_x:float,_z:float)->float:return 0.5
func lot(model,point:Vector2,zone:String)->Dictionary:
	var candidate:Dictionary=model.housing.candidate(point,model.roads,flat,zone,"medium")
	assert(not candidate.is_empty())
	candidate["sewer_exempt"]=true # Isola o subsistema anterior; esgoto tem teste integrado próprio.
	model.housing.commit(candidate)
	return model.housing.lots[-1]
func reload(model):
	var result=Network.restore(JSON.parse_string(JSON.stringify(model.serialize())))
	assert(result!=null,"Save após editar topologia e demolir")
	assert(result.cash==model.cash and result.construction_spent==model.construction_spent)
	assert(result.housing.economy.account_total(result.housing)==0)
	return result
func _initialize()->void:
	var model=Network.new()
	assert(model.commit(Vector2(-80,0),Vector2(60,0)))
	assert(model.commit(Vector2(0,0),Vector2(0,60)))
	var water:=lot(model,Vector2(-60,9),"water")
	var power:=lot(model,Vector2(-40,9),"power")
	model.simulate(24.1)
	var home:=lot(model,Vector2(30,9),"residential")
	var factory:=lot(model,Vector2(30,-9),"industrial")
	model.simulate(26)
	assert(home.stage==2 and factory.stage==2)
	assert(Utilities.state(home,Utilities.budget(model.housing)).operational)
	var original_cash:int=model.cash
	var original_ledger:int=model.construction_spent
	var target:Dictionary=model.pick_demolition_road(Vector2(-25,0))
	assert(target.points[0]==Vector2(-80,0) and target.points[-1]==Vector2(0,0),"Divisão na junção, não apagar toda a rua")
	assert(model.demolish_road(target).ok)
	assert(model.roads.size()==2 and model.road_length()==120)
	assert(model.cash==original_cash and model.construction_spent==original_ledger,"Demolição não recupera gasto histórico")
	assert(water.road==-1 and power.road==-1 and home.road>=0)
	assert(not Utilities.state(home,Utilities.budget(model.housing)).operational)
	assert(not home.external_access)
	var blocked=reload(model)
	assert(blocked.housing.lots[0].road==-1)
	var person:Dictionary=model.housing.residents[0]
	var before:int=person.balance
	model.housing.economy.work_visit(person,factory)
	assert(person.balance==before,"Empresa sem serviços não paga nem produz")
	assert(model.commit(Vector2(-80,0),Vector2(0,0)))
	assert(water.road>=0 and home.external_access)
	assert(Utilities.state(home,Utilities.budget(model.housing)).operational)
	model=reload(model)
	# Duas redes com fontes locais não compartilham capacidade através do vazio.
	var isolated=Network.new()
	assert(isolated.commit(Vector2(-80,0),Vector2(-20,0)))
	assert(isolated.commit(Vector2(-20,0),Vector2(20,0)))
	assert(isolated.commit(Vector2(20,0),Vector2(70,0)))
	lot(isolated,Vector2(-60,9),"water")
	lot(isolated,Vector2(40,9),"power")
	isolated.simulate(24.1)
	var waiting:=lot(isolated,Vector2(60,-9),"residential")
	assert(isolated.demolish_road(isolated.pick_demolition_road(Vector2(0,0))).ok)
	var state:=Utilities.state(waiting,Utilities.budget(isolated.housing))
	assert(state.power and not state.water,"Energia local não fornece água remota")
	isolated.simulate(30)
	assert(waiting.demand_pending)
	reload(isolated)
	# Demolir fonte pronta causa falta imediatamente e mantém os moradores.
	var population:int=model.housing.residents.size()
	assert(model.demolish_lot(2).ok)
	assert(model.housing.residents.size()==population and Utilities.budget(model.housing).power==0)
	assert(not model.housing.lots[-1].operational)
	model=reload(model)
	# Demolir empresa encerra empregos e leva seu caixa para fora, sem criar dinheiro.
	var remaining_home:int=model.housing.residents[0].home
	assert(model.demolish_lot(model.housing.lots.size()).ok)
	for resident in model.housing.residents: assert(resident.job==0)
	assert(model.housing.economy.account_total(model.housing)==0)
	model=reload(model)
	# Demolir moradia permite manter o zoneamento; residentes saem com seus saldos.
	assert(model.demolish_lot(remaining_home,true).ok)
	assert(model.housing.residents.is_empty() and model.travel.agents.is_empty())
	assert(model.housing.lots[remaining_home-1].demand_pending)
	assert(not model.housing.lots[remaining_home-1].utility_exempt)
	model=reload(model)
	assert(model.demolish_lot(remaining_home).ok)
	assert(model.housing.lots.size()==1)
	reload(model)
	# Curvas preservam a geometria dos trechos restantes, inclusive após recarga.
	var curved=Network.new()
	assert(curved.commit(Vector2(-80,0),Vector2(40,40),Vector2(-10,-30)))
	var midpoint:Vector2=curved.roads[0].points[int(curved.roads[0].points.size()/2)]
	assert(curved.commit(midpoint,midpoint+Vector2(0,40)))
	var chunk:Dictionary=curved.pick_demolition_road(curved.roads[0].points[10])
	assert(curved.demolish_road(chunk).ok)
	var restored=reload(curved)
	assert(is_equal_approx(curved.road_length(),restored.road_length()))
	# Migrar arquivo real da 0.0.13 sem alterar o patrimônio ou as pessoas.
	var legacy:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/city-0.0.13.json"))
	var migrated=Network.restore(legacy)
	assert(migrated!=null and migrated.cash==legacy.cash)
	assert(Utilities.budget(migrated.housing).water==60 and Utilities.budget(migrated.housing).power==80)
	assert(not migrated.housing.lots[-1].utility_exempt)
	assert(migrated.housing.lots[-1].age==legacy.residential.lots[-1].age)
	reload(migrated)
	print("DEMOLITION_NETWORK_OK: trechos e curvas, desconexão/reconexão, serviços locais, empresas, moradores, contas e recarga")
	quit()
