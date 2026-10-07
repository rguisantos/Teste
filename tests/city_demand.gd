extends SceneTree
const Network=preload("res://scripts/streets_model.gd")
const Demand=preload("res://scripts/city_demand.gd")
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
	for x in [-66,-54,-42,-30,-18,-6,6,18]: lot(model,Vector2(x,8),"residential")
	var startup:=Demand.snapshot(model.housing)
	assert(startup.residential.remaining==8 and startup.waiting==8)
	model.simulate(0)
	assert(model.housing.lots[0].demand_pending,"Tempo zero não inicia obras")
	model.simulate(1)
	assert(Demand.snapshot(model.housing).waiting==4)
	assert(Demand.snapshot(model.housing).residential.remaining==0,"Reservar casas em obra para não repetir demanda")
	for i in range(8):
		assert(model.housing.lots[i].demand_pending==(i>=4))
		assert(is_equal_approx(model.housing.lots[i].age,0 if i>=4 else 1))
	var store=Store.new()
	store.base_path="user://city_demand_test.json"
	assert(store.save_city(42,model))
	var restored=Network.restore(store.load_city())
	assert(restored!=null and Demand.snapshot(restored.housing).waiting==4)
	restored.simulate(23)
	assert(restored.housing.residents.size()==8)
	assert(Demand.snapshot(restored.housing).waiting==4)
	assert(restored.housing.economy.account_total(restored.housing)==0)
	# Um comércio para oito moradores; novas lojas aguardam.
	for x in [-60,-44,-28,-12]: lot(restored,Vector2(x,-8),"commercial")
	var factory:=lot(restored,Vector2(54,11),"industrial","large")
	restored.simulate(1)
	assert(not restored.housing.lots[8].demand_pending)
	for i in [9,10,11]: assert(restored.housing.lots[i].demand_pending)
	assert(not factory.demand_pending)
	assert(Demand.snapshot(restored.housing).industrial.remaining==0)
	# Empregos concluídos liberam as moradias que aguardavam, sem novo toque.
	restored.simulate(24)
	assert(restored.housing.economy.employment_count(restored.housing)>0)
	assert(not restored.housing.lots[4].demand_pending)
	assert(restored.housing.lots[4].age>0 and restored.housing.lots[4].age<24)
	restored.simulate(24)
	assert(restored.housing.residents.size()>8)
	assert(not restored.housing.lots[9].demand_pending,"Mais moradores liberam outra loja")
	assert(restored.housing.lots[11].demand_pending,"Não liberar todas as lojas por uma só demanda")
	assert(restored.housing.economy.account_total(restored.housing)==0)
	for day in range(3): restored.simulate(restored.housing.economy.DAY_SECONDS)
	assert(restored.housing.economy.account_total(restored.housing)==0)
	assert(store.save_city(42,restored))
	assert(Network.restore(store.load_city())!=null)
	var corrupt: Dictionary=restored.serialize()
	corrupt.residential.lots[0].demand_pending=true
	assert(Network.restore(corrupt)==null,"Imóvel pronto não pode estar na fila")
	var poor=Network.restore(JSON.parse_string(JSON.stringify(restored.serialize())))
	assert(poor!=null)
	for person in poor.housing.residents:
		poor.housing.economy.exterior_balance+=person.balance
		person.balance=0
	assert(Demand.snapshot(poor.housing).customers==0)
	assert(Demand.snapshot(poor.housing).commercial.remaining==0,"Moradores sem saldo não sustentam novas lojas")
	assert(poor.housing.economy.account_total(poor.housing)==0)
	# Migração da 0.0.10: obras antigas continuam mesmo com demanda residencial zero.
	var legacy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/city-0.0.10.json"))
	var migrated=Network.restore(legacy)
	assert(migrated!=null)
	assert(Demand.snapshot(migrated.housing).residential.remaining==0)
	assert(not migrated.housing.lots[-1].demand_pending)
	assert(migrated.housing.lots[-1].age==legacy.residential.lots[-1].age)
	assert(migrated.cash==int(legacy.cash))
	for i in range(migrated.housing.residents.size()):
		for key in ["home","job","name","balance"]: assert(migrated.housing.residents[i][key]==legacy.residential.residents[i][key])
	migrated.simulate(16)
	assert(migrated.housing.lots[-1].stage==2)
	assert(migrated.housing.residents.size()==legacy.residential.residents.size()+2)
	assert(migrated.housing.economy.account_total(migrated.housing)==0)
	assert(Network.restore(JSON.parse_string(JSON.stringify(migrated.serialize())))!=null)
	print("CITY_DEMAND_OK: reservas, fila persistente, empregos/moradores liberam crescimento, caixa conservado e migração 0.0.10")
	quit()
