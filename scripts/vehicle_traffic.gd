extends RefCounted
## Trânsito local introdutório; não movimenta dinheiro, estoques nem cidadãos.
const Routes=preload("res://scripts/vehicle_routes.gd")
const Road=preload("res://scripts/citizen_routes.gd")
const Catalog=preload("res://scripts/vehicle_catalog.gd")
const LIMIT:=24
const TICK:=0.1
var vehicles:Array[Dictionary]=[]
var locks:Dictionary={}
var next_id:=1
var completed:=0
var cancelled:=0
var spawn_cursor:=0
var clock:=0.0
var accumulator:=0.0
var revision:=-1
var routes_cache:Dictionary={}
var blocked_routes:=0
var occupancy_dirty:=true
var occupancy:Array[PackedVector2Array]=[]

func cached_route(network,origin:Dictionary,destination:Dictionary,kind:String)->Dictionary:
	var key:=JSON.stringify([origin,destination,kind])
	if not routes_cache.has(key):routes_cache[key]=Routes.route(network,origin,destination,kind)
	return routes_cache[key]
func sync(network)->void:
	if revision==network.graph_revision:return
	revision=network.graph_revision
	occupancy_dirty=true
	routes_cache.clear()
	locks.clear()
	var survivors:Array[Dictionary]=[]
	for vehicle in vehicles:
		var previous:Vector2=Road.position(vehicle.route.points,vehicle.distance)
		var path:=cached_route(network,vehicle.origin,vehicle.destination,vehicle.kind)
		if path.is_empty():cancelled+=1;continue
		var progress:=Road.nearest_progress(path.points,previous)
		if Road.position(path.points,progress).distance_to(previous)>0.5:cancelled+=1;continue
		var same_path:bool=path.points==vehicle.route.points
		vehicle.route=path
		if not same_path:
			vehicle.distance=progress
			vehicle.previous_distance=progress
			vehicle.speed=0.0
		survivors.append(vehicle)
	vehicles=survivors
	_rebuild_locks()
func _rebuild_locks()->void:
	locks.clear()
	var conflicts:Array[Dictionary]=[]
	for vehicle in vehicles:
		var half:float=Catalog.spec(vehicle.kind).length/2.0
		var keys:Array[String]=[]
		var conflict:=false
		for gate in vehicle.route.gates:
			if vehicle.distance+half>=gate.enter-0.01 and vehicle.distance-half<=gate.exit:
				keys.append(gate.key)
				if locks.has(gate.key):conflict=true
		if conflict:conflicts.append(vehicle)
		else:
			for key in keys:locks[key]=int(vehicle.id)
	for vehicle in conflicts:vehicles.erase(vehicle);cancelled+=1
func _overlaps(a:PackedVector2Array,b:PackedVector2Array)->bool:
	# SAT: retângulos orientados; faixas opostas não se bloqueiam por um raio grande.
	for polygon in [a,b]:
		for i in range(2):
			var edge:Vector2=polygon[i+1]-polygon[i]
			var axis:=Vector2(-edge.y,edge.x).normalized()
			var amin:=INF
			var amax:=-INF
			var bmin:=INF
			var bmax:=-INF
			for p in a:amin=minf(amin,p.dot(axis));amax=maxf(amax,p.dot(axis))
			for p in b:bmin=minf(bmin,p.dot(axis));bmax=maxf(bmax,p.dot(axis))
			if amax<=bmin or bmax<=amin:return false
	return true
func clear_space(path:Dictionary,distance_value:float,kind:String,ignore_id:int=0)->bool:
	var box:=Routes.footprint(path,distance_value,kind,0.25)
	for other in vehicles:
		if int(other.id)==ignore_id:continue
		if _overlaps(box,Routes.footprint(other.route,other.distance,other.kind,0.25)):return false
	return true
func enqueue(network,kind:String,origin:Dictionary,destination:Dictionary)->bool:
	sync(network)
	if vehicles.size()>=LIMIT or Catalog.spec(kind).is_empty():return false
	var path:=cached_route(network,origin,destination,kind)
	if path.is_empty() or not clear_space(path,0,kind):return false
	for gate in path.gates:
		if Catalog.spec(kind).length/2.0>=gate.enter and locks.has(gate.key):return false
	for gate in path.gates:
		if Catalog.spec(kind).length/2.0>=gate.enter:locks[gate.key]=next_id
	vehicles.append({"id":next_id,"kind":kind,"origin":origin.duplicate(),"destination":destination.duplicate(),"route":path,"distance":0.0,"previous_distance":0.0,"speed":0.0,"wait":0.0,"reason":"","color":next_id%6})
	next_id+=1
	occupancy_dirty=true
	return true
func _spawn(network)->void:
	var kind:String=Catalog.TYPES[spawn_cursor%Catalog.TYPES.size()]
	var eligible:Array[Dictionary]=[]
	for lot in network.housing.lots:
		if lot.stage==2 and lot.road>=0 and network.housing.road_components.get(lot.road,-1)==0 and lot.zone in Catalog.spec(kind).zones:
			if lot.zone!="residential" and not lot.get("operational",false):continue
			eligible.append(lot)
	var ticket:=spawn_cursor
	spawn_cursor+=1
	if eligible.is_empty() or vehicles.size()>=mini(LIMIT,maxi(4,network.housing.lots.size()*2)):return
	for offset in range(mini(eligible.size(),4)):
		var lot:Dictionary=eligible[(ticket/Catalog.TYPES.size()+offset)%eligible.size()]
		var inbound:=ticket%2==0
		var entry:={"entry":true}
		var address:=Routes.address(lot)
		if enqueue(network,kind,entry if inbound else address,address if inbound else entry):return
	blocked_routes+=1
func _crossing_pedestrians(network)->Array[Vector2]:
	var result:Array[Vector2]=[]
	for person in network.travel.agents:
		if person.phase!="walking":continue
		var p:Vector2=network.travel.position(person,network.housing)
		for crossing in network.travel.router.crossings:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,crossing[0],crossing[1]))<0.55:
				result.append(p)
				break
	return result
func _pedestrian_ahead(network,vehicle:Dictionary,crossers=null)->bool:
	var half:float=Catalog.spec(vehicle.kind).length/2.0
	var pedestrians:Array[Vector2]=_crossing_pedestrians(network) if crossers==null else crossers
	for p in pedestrians:
		var progress:=Road.nearest_progress(vehicle.route.points,p)
		if progress<=vehicle.distance+half+0.25 or progress>vehicle.distance+half+9.0:continue
		if Road.position(vehicle.route.points,progress).distance_to(p)<=4.5:return true
	return false
func pedestrian_can_advance(agent:Dictionary,delta:float,network)->bool:
	if vehicles.is_empty():return true
	var p:Vector2=Road.position(agent.points,agent.distance)
	var next:Vector2=Road.position(agent.points,minf(agent.length,agent.distance+network.travel.SPEED*delta))
	if occupancy_dirty:
		occupancy.clear()
		for vehicle in vehicles:occupancy.append(Routes.footprint(vehicle.route,vehicle.distance,vehicle.kind,0.35))
		occupancy_dirty=false
	for box in occupancy:
		if Geometry2D.is_point_in_polygon(next,box):return false
		for i in range(4):
			if Geometry2D.segment_intersects_segment(p,next,box[i],box[(i+1)%4])!=null:return false
	return true
func advance(delta:float,network)->void:
	sync(network)
	accumulator+=maxf(0,delta)
	while accumulator+0.0000001>=TICK:
		accumulator=maxf(0,accumulator-TICK)
		_step(network)
func _step(network)->void:
	clock+=TICK
	if clock>=4.0:
		clock-=4.0
		_spawn(network)
	_release_locks()
	var finished:Array[Dictionary]=[]
	var boxes:Dictionary={}
	for vehicle in vehicles:boxes[vehicle.id]=Routes.footprint(vehicle.route,vehicle.distance,vehicle.kind,0.25)
	var crossers:=_crossing_pedestrians(network)
	for vehicle in vehicles:
		var spec:=Catalog.spec(vehicle.kind)
		var half:float=spec.length/2.0
		var desired:=minf(spec.speed,Routes.speed_limit(vehicle.route,vehicle.distance+6.0))
		var stop:=float(vehicle.route.length)
		vehicle.reason=""
		for gate in vehicle.route.gates:
			if vehicle.distance-half>gate.exit:continue
			var line:=maxf(0,gate.enter-half-0.5)
			if vehicle.distance<gate.exit+half and vehicle.distance>line-9:desired=minf(desired,2.6 if vehicle.kind=="heavy_truck" else 3.4)
			if vehicle.distance+maxf(vehicle.speed,1.0)*TICK+1.0>=line:
				if not locks.has(gate.key):locks[gate.key]=int(vehicle.id)
				if locks[gate.key]!=vehicle.id:stop=maxf(vehicle.distance,minf(stop,line));vehicle.reason="Cruzamento"
			else:break
		if _pedestrian_ahead(network,vehicle,crossers):
			desired=0.0
			vehicle.reason="Travessia"
		var available:=maxf(0,stop-vehicle.distance)
		desired=minf(desired,sqrt(2.0*4.0*available))
		var speed:=move_toward(float(vehicle.speed),desired,(spec.accel if desired>vehicle.speed else 5.0)*TICK)
		var next:=minf(stop,vehicle.distance+speed*TICK)
		var proposed:=Routes.footprint(vehicle.route,next,vehicle.kind,0.25)
		var free_space:=true
		for other_id in boxes:
			if other_id!=vehicle.id and _overlaps(proposed,boxes[other_id]):free_space=false;break
		if not free_space:
			next=vehicle.distance
			speed=0.0
			vehicle.reason="Fila"
		boxes[vehicle.id]=Routes.footprint(vehicle.route,next,vehicle.kind,0.25)
		vehicle.previous_distance=float(vehicle.distance)
		vehicle.distance=next
		vehicle.speed=speed
		vehicle.wait=float(vehicle.wait)+TICK if speed<0.05 else 0.0
		if vehicle.distance>=vehicle.route.length-0.001:finished.append(vehicle)
	for vehicle in finished:vehicles.erase(vehicle);completed+=1
	_release_locks()
	occupancy_dirty=true
func _release_locks()->void:
	# Libera a junção somente depois que a traseira saiu.
	for key in locks.keys():
		var keep:=false
		for vehicle in vehicles:
			if vehicle.id!=locks[key]:continue
			for gate in vehicle.route.gates:
				if gate.key==key and vehicle.distance-Catalog.spec(vehicle.kind).length/2.0<=gate.exit:keep=true
		if not keep:locks.erase(key)
func stats()->Dictionary:
	var counts:={"hatch":0,"sedan":0,"motorcycle":0,"light_truck":0,"heavy_truck":0}
	var waiting:=0
	for vehicle in vehicles:
		counts[vehicle.kind]+=1
		if vehicle.speed<0.05:waiting+=1
	return {"counts":counts,"active":vehicles.size(),"waiting":waiting,"completed":completed,"cancelled":cancelled,"limit":LIMIT,"blocked_routes":blocked_routes}
func serialize()->Dictionary:
	var items:Array=[]
	for vehicle in vehicles:
		var item:=vehicle.duplicate()
		item.erase("route")
		items.append(item)
	return {"version":1,"vehicles":items,"locks":locks.duplicate(),"next_id":next_id,"completed":completed,"cancelled":cancelled,"spawn_cursor":spawn_cursor,"clock":clock,"accumulator":accumulator,"blocked_routes":blocked_routes}
static func number(value)->bool:return (value is float or value is int) and is_finite(float(value))
static func integer(value)->bool:return number(value) and value==int(value) and value>=0 and value<=1000000000
static func valid_address(ref)->bool:
	if not ref is Dictionary:return false
	if ref.get("entry",false)==true:return ref.size()==1
	return ref.size()==3 and ref.get("zone") in ["residential","commercial","industrial"] and number(ref.get("x")) and number(ref.get("z")) and absf(ref.x)<96 and absf(ref.z)<96
static func restore(data:Dictionary,network):
	var traffic=load("res://scripts/vehicle_traffic.gd").new()
	traffic.revision=network.graph_revision
	if data.is_empty():return traffic
	if data.get("version")!=1 or not data.get("vehicles") is Array or data.vehicles.size()>LIMIT or not data.get("locks") is Dictionary:return null
	for key in ["next_id","completed","cancelled","spawn_cursor","blocked_routes"]:
		if not integer(data.get(key)):return null
		traffic.set(key,int(data[key]))
	if traffic.next_id<1:return null
	for key in ["clock","accumulator"]:
		if not number(data.get(key)) or data[key]<0 or data[key]>=(4.000001 if key=="clock" else TICK+0.000001):return null
		traffic.set(key,float(data[key]))
	var previous_id:=0
	for item in data.vehicles:
		if not item is Dictionary or not integer(item.get("id")) or item.id<=previous_id or item.id>=traffic.next_id or not item.get("kind") in Catalog.TYPES:return null
		previous_id=int(item.id)
		if not valid_address(item.get("origin")) or not valid_address(item.get("destination")):return null
		if not integer(item.get("color")) or item.color>5 or item.get("reason") not in ["","Cruzamento","Travessia","Fila"]:return null
		for key in ["distance","previous_distance","speed","wait"]:
			if not number(item.get(key)) or item[key]<0:return null
		var path:Dictionary=traffic.cached_route(network,item.origin,item.destination,item.kind)
		if path.is_empty() or item.distance>path.length+0.001 or item.speed>Catalog.spec(item.kind).speed+0.01 or item.wait>1000000000:return null
		if item.previous_distance>item.distance+0.001 or item.distance-item.previous_distance>Catalog.spec(item.kind).speed*TICK+0.01:return null
		if not traffic.clear_space(path,item.distance,item.kind):return null
		var vehicle:Dictionary=item.duplicate(true)
		vehicle.id=int(vehicle.id)
		vehicle.color=int(vehicle.color)
		vehicle.route=path
		traffic.vehicles.append(vehicle)
	for key in data.locks:
		if not key is String or not integer(data.locks[key]):return null
		var valid:=false
		for vehicle in traffic.vehicles:
			if vehicle.id!=int(data.locks[key]):continue
			for gate in vehicle.route.gates:
				if key==gate.key and vehicle.distance-Catalog.spec(vehicle.kind).length/2.0<=gate.exit:valid=true
		if not valid:return null
		traffic.locks[key]=int(data.locks[key])
	return traffic
