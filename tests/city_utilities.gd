extends SceneTree
const Network=preload("res://scripts/streets_model.gd")
const Utilities=preload("res://scripts/city_utilities.gd")
func flat(_x:float,_z:float)->float: return 0.5
func add_lot(model,x:float,zone:String)->Dictionary:
	var candidate: Dictionary=model.housing.candidate(Vector2(x,9),model.roads,flat,zone,"medium")
	assert(not candidate.is_empty())
	candidate["sewer_exempt"]=true # Isola o subsistema anterior; esgoto tem teste integrado próprio.
	model.housing.commit(candidate)
	return model.housing.lots[-1]
func _initialize()->void:
	var model=Network.new()
	assert(model.commit(Vector2(-80,0),Vector2(70,0)))
	var home:=add_lot(model,-65,"residential")
	model.simulate(25)
	assert(home.demand_pending and home.age==0,"Sem serviços, não iniciar nem cobrar")
	var water:=add_lot(model,-45,"water")
	assert(not water.demand_pending)
	model.simulate(6.1)
	assert(water.stage==1 and Utilities.budget(model.housing).water==0)
	model.simulate(18.1)
	assert(water.stage==2 and Utilities.budget(model.housing).water==60)
	assert(home.demand_pending,"Água sozinha não libera obra")
	var power:=add_lot(model,-25,"power")
	var cash_before:int=model.cash
	model.simulate(24.2)
	assert(power.stage==2 and not home.demand_pending and home.age>0)
	assert(model.cash==cash_before and not power.has("business") and not water.has("business"))
	var budget:=Utilities.budget(model.housing)
	assert(budget.water_used==home.capacity and budget.power_used==home.capacity)
	assert(budget.water==60 and budget.power==80)
	# A reserva é feita ao iniciar, antes de liberar o próximo lote; não exceder capacidade.
	var factory:Dictionary={"sewer_exempt":true,"id":99,"road":0,"zone":"industrial","width":10.0,"depth":12.0,"capacity":4}
	var reservations:=0
	while Utilities.can_start(factory,budget):
		Utilities.reserve(factory,budget)
		reservations+=1
	assert(reservations==5 and budget.water_used==53 and budget.power_used==78)
	assert(not Utilities.can_start(factory,budget))
	assert(model.cancel_unfinished_lot(int(home.id)).ok)
	assert(Utilities.budget(model.housing).water_used==0,"Bulldozer libera reserva")
	assert(not model.cancel_unfinished_lot(1).ok,"Instalação concluída preservada")
	var new_home:=add_lot(model,0,"residential")
	model.simulate(24.1)
	assert(new_home.stage==2 and model.housing.residents.size()==3)
	assert(model.housing.economy.employment_count(model.housing)==0,"Serviços não recebem empregados de empresas")
	assert(model.housing.economy.account_total(model.housing)==0)
	var restored=Network.restore(JSON.parse_string(JSON.stringify(model.serialize())))
	assert(restored!=null)
	assert(Utilities.budget(restored.housing).water_used==3)
	assert(not restored.housing.lots[-1].utility_exempt,"Nova cidade não vira legado ao recarregar")
	var corrupt:Dictionary=model.serialize()
	corrupt.residential.lots[0].business={"cash":0,"stock":0}
	assert(Network.restore(corrupt)==null)
	corrupt=model.serialize()
	corrupt.residential.lots[0].demand_pending=true
	assert(Network.restore(corrupt)==null)
	corrupt=model.serialize()
	corrupt.residential.lots[-1].utility_exempt="true"
	assert(Network.restore(corrupt)==null)
	# Fixture produzida pelo código 0.0.12: preservar concluídos e obras, não lotes vazios.
	var legacy:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/city-0.0.12.json"))
	var migrated=Network.restore(legacy)
	assert(migrated!=null and migrated.cash==legacy.cash)
	var waiting:=0
	var active:=0
	for i in range(migrated.housing.lots.size()):
		var value:Dictionary=migrated.housing.lots[i]
		assert(value.utility_exempt==not value.demand_pending)
		assert(value.age==legacy.residential.lots[i].age)
		if value.demand_pending: waiting+=1
		elif value.stage<2: active+=1
	assert(waiting>0 and active>0)
	assert(Utilities.budget(migrated.housing).water_used==0)
	migrated.simulate(16)
	assert(migrated.housing.lots[-1].demand_pending)
	assert(migrated.housing.economy.account_total(migrated.housing)==0)
	assert(Network.restore(JSON.parse_string(JSON.stringify(migrated.serialize())))!=null)
	print("CITY_UTILITIES_OK: fontes, carência, reserva finita, cancelamento, contas e migração 0.0.12")
	quit()
