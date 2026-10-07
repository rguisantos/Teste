extends SceneTree
const Network=preload("res://scripts/streets_model.gd")
const Routes=preload("res://scripts/vehicle_routes.gd")
const Catalog=preload("res://scripts/vehicle_catalog.gd")
const Road=preload("res://scripts/citizen_routes.gd")
func flat(_x:float,_z:float)->float:return 0.5
func lot(model,p:Vector2,zone:String="residential")->Dictionary:
	var candidate:Dictionary=model.housing.candidate(p,model.roads,flat,zone,"small")
	assert(not candidate.is_empty())
	candidate.utility_exempt=true
	candidate.sewer_exempt=true
	model.housing.commit(candidate)
	model.housing.advance(24.1)
	model.refresh_access()
	return model.housing.lots[-1]
func clone(model):
	var value=Network.restore(JSON.parse_string(JSON.stringify(model.serialize())))
	assert(value!=null,"Trânsito precisa recarregar a cidade")
	return value
func no_collisions(model)->void:
	for i in range(model.traffic.vehicles.size()):
		var a:Dictionary=model.traffic.vehicles[i]
		for j in range(i+1,model.traffic.vehicles.size()):
			var b:Dictionary=model.traffic.vehicles[j]
			assert(not model.traffic._overlaps(Routes.footprint(a.route,a.distance,a.kind),Routes.footprint(b.route,b.distance,b.kind)),"Veículos sobrepostos")
func _initialize()->void:
	var model=Network.new()
	assert(model.commit(Vector2(-80,0),Vector2(70,0),null,"asphalt"))
	var home:=lot(model,Vector2(55,9))
	var factory:=lot(model,Vector2(30,-9),"industrial")
	var entry:={"entry":true}
	var address:=Routes.address(home)
	for kind in Catalog.TYPES:
		var path:=Routes.route(model,entry,address,kind)
		assert(not path.is_empty(),kind+" precisa caber na reta")
		assert(is_equal_approx(path.points[0].y,Routes.LANE))
		var back:=Routes.route(model,address,entry,kind)
		assert(not back.is_empty() and is_equal_approx(back.points[-1].y,-Routes.LANE),"Mão direita nos dois sentidos")
	assert(model.traffic.enqueue(model,"heavy_truck",entry,Routes.address(factory)))
	assert(not model.traffic.enqueue(model,"hatch",entry,address),"Entrada ocupada bloqueia novo veículo")
	assert(model.traffic.enqueue(model,"sedan",address,entry),"Faixa oposta permanece livre")
	var cash:int=model.cash
	for i in range(120):model.traffic.advance(0.1,model);no_collisions(model)
	assert(model.cash==cash,"Tráfego não duplica a contabilidade")
	var restored=clone(model)
	assert(restored.traffic.vehicles.size()==model.traffic.vehicles.size())
	for i in range(model.traffic.vehicles.size()):
		assert(is_equal_approx(model.traffic.vehicles[i].distance,restored.traffic.vehicles[i].distance))
		assert(is_equal_approx(model.traffic.vehicles[i].speed,restored.traffic.vehicles[i].speed))
	for i in range(50):model.traffic.advance(0.1,model);restored.traffic.advance(0.1,restored)
	assert(JSON.stringify(model.traffic.serialize())==JSON.stringify(restored.traffic.serialize()),"Recarga determinística, sem reiniciar viagens")
	var bad:Dictionary=model.serialize()
	bad.traffic.vehicles[0].distance=-1
	assert(Network.restore(bad)==null)
	bad=model.serialize();bad.traffic.vehicles[0].kind="helicopter"
	assert(Network.restore(bad)==null)
	# Cruzamento X: várias aproximações, rotas nas faixas, sem colisões e sem travar.
	var junction=Network.new()
	assert(junction.commit(Vector2(-80,0),Vector2(70,0),null,"asphalt"))
	assert(junction.commit(Vector2(0,0),Vector2(0,65),null,"asphalt"))
	assert(junction.commit(Vector2(0,0),Vector2(0,-65),null,"asphalt"))
	var west:=lot(junction,Vector2(-55,9))
	var east:=lot(junction,Vector2(55,9))
	var north:=lot(junction,Vector2(9,-48))
	var south:=lot(junction,Vector2(9,48))
	var inserted:=0
	for pair in [[west,east],[east,west],[north,south],[south,north],[west,north],[east,south]]:
		if junction.traffic.enqueue(junction,"hatch",Routes.address(pair[0]),Routes.address(pair[1])):inserted+=1
	assert(inserted>=4)
	var saw_wait:=false
	for i in range(1500):
		# Disable autonomous spawning only in this controlled intersection test.
		junction.traffic.clock=0.0
		junction.traffic.advance(0.1,junction)
		no_collisions(junction)
		if i%50==0 or junction.traffic.vehicles.is_empty():clone(junction)
		for vehicle in junction.traffic.vehicles:
			if vehicle.reason=="Cruzamento":saw_wait=true
		if junction.traffic.vehicles.is_empty():break
	assert(junction.traffic.completed==inserted and junction.traffic.vehicles.is_empty(),"Cruzamento precisa escoar")
	assert(saw_wait,"Aproximações conflitantes devem aguardar")
	# Curvas de terra respeitam o espaço do veículo e os limites por piso.
	var curve=Network.new()
	assert(curve.commit(Vector2(-80,0),Vector2(45,35),Vector2(-25,45)))
	var corner:=lot(curve,Vector2(42,44))
	var curved:=Routes.route(curve,entry,Routes.address(corner),"hatch")
	assert(not curved.is_empty() and curved.points.size()>8)
	assert(Routes.speed_limit(curved,20)==4.0)
	# Pedestre não entra na carroceria; veículo cede à travessia adiante.
	var walker:={"points":PackedVector2Array([Vector2(-40,-4.05),Vector2(-40,4.05)]),"distance":4.8,"length":8.1,"phase":"walking"}
	var vehicle:Dictionary=model.traffic.vehicles[0]
	vehicle.route=Routes.route(model,entry,address,"heavy_truck")
	vehicle.kind="heavy_truck"
	vehicle.distance=Road.nearest_progress(vehicle.route.points,Vector2(-40,1.65))
	assert(not model.traffic.pedestrian_can_advance(walker,0.1,model))
	model.travel.router.crossings.assign([PackedVector2Array([Vector2(-20,-4.05),Vector2(-20,4.05)])])
	walker.distance=1.5
	walker.points=PackedVector2Array([Vector2(-20,-4.05),Vector2(-20,4.05)])
	model.travel.agents.assign([walker])
	vehicle.distance=Road.nearest_progress(vehicle.route.points,Vector2(-29,1.65))
	assert(model.traffic._pedestrian_ahead(model,vehicle))
	# Migração autêntica preserva contas e começa com trânsito vazio.
	var legacy:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/city-0.0.18.json"))
	assert(not legacy.has("traffic"))
	var migrated=Network.restore(legacy)
	assert(migrated!=null and migrated.cash==int(legacy.cash) and migrated.traffic.vehicles.is_empty())
	migrated.simulate(60)
	assert(migrated.traffic.next_id>3)
	clone(migrated)
	var before_spent:int=migrated.construction_spent
	assert(migrated.demolish_road(migrated.pick_demolition_road(Vector2(-30,0))).ok)
	migrated.traffic.sync(migrated)
	assert(migrated.construction_spent==before_spent)
	clone(migrated)
	for active in migrated.traffic.vehicles:assert(Routes.fits(migrated,active.route,active.kind))
	assert(migrated.traffic.vehicles.size()<=24)
	print("VEHICLE_TRAFFIC_OK: cinco tipos, faixas, filas, X, espaço, limites, pedestres, recarga determinística e migração")
	quit()
