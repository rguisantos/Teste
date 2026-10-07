extends RefCounted
const Routes = preload("res://scripts/citizen_routes.gd")
const SPEED := 1.35 # Metros por segundo ativo, sem aceleração pelo calendário.
const WORK_STAY := 12.0
const SHOP_STAY := 4.0
const HOME_STAY := 3.0
const ROUTE_VERSION := 2
var router = Routes.new()
var agents: Array[Dictionary] = []
var completed_trips := 0

func sync(network) -> void:
	while agents.size()<network.housing.residents.size():
		var person: Dictionary = network.housing.residents[agents.size()]
		agents.append({"id":person.id,"at":person.home,"origin":person.home,"target":person.home,"purpose":"home","phase":"idle","points":PackedVector2Array(),"distance":0.0,"length":0.0,"wait":float(person.id%9)*0.35,"visited_work_day":-1,"worked_day":-1,"bought_day":-1,"shop_try_day":-1})

func _depart(network, agent: Dictionary, target: int, purpose: String) -> bool:
	var points: PackedVector2Array = router.route(network,agent.at,target)
	if points.is_empty():
		agent.phase="blocked"
		agent.wait=3.0
		return false
	agent.origin=agent.at
	agent.target=target
	agent.purpose=purpose
	agent.points=points
	agent.distance=0.0
	agent.length=Routes.length(points)
	agent.phase="walking"
	return true

func _shop(network, agent: Dictionary) -> int:
	var best := 0
	var shortest := INF
	for lot in network.housing.lots:
		if lot.zone!="commercial" or lot.stage!=2 or lot.business.stock<1 or network.housing.economy.workers(network.housing,lot.id)==0: continue
		var path: PackedVector2Array = router.route(network,agent.at,lot.id)
		if path.is_empty(): continue
		var distance_value:=Routes.length(path)
		if distance_value<shortest:
			shortest=distance_value
			best=lot.id
	return best

func advance(delta: float, network) -> void:
	sync(network)
	var eco = network.housing.economy
	for agent in agents:
		var person: Dictionary = network.housing.residents[agent.id-1]
		if agent.phase=="walking":
			if not network.traffic.pedestrian_can_advance(agent,delta,network):continue
			agent.distance=minf(agent.length,agent.distance+SPEED*delta)
			if agent.distance+0.00001>=agent.length:
				agent.at=agent.target
				agent.points=PackedVector2Array()
				agent.distance=0.0
				agent.length=0.0
				agent.phase="working" if agent.purpose=="work" else ("shopping" if agent.purpose=="shop" else "idle")
				agent.wait=WORK_STAY if agent.phase=="working" else (SHOP_STAY if agent.phase=="shopping" else HOME_STAY)
				completed_trips+=1
			continue
		agent.wait=maxf(0.0,agent.wait-delta)
		if agent.wait>0: continue
		if agent.phase=="working":
			if person.job==agent.at and agent.worked_day!=eco.day:
				eco.work_visit(person,network.housing.lots[agent.at-1])
				agent.worked_day=eco.day
			agent.visited_work_day=eco.day
			agent.phase="idle"
		elif agent.phase=="shopping":
			if agent.bought_day!=eco.day and eco.purchase(person,network.housing.lots[agent.at-1]): agent.bought_day=eco.day
			agent.shop_try_day=eco.day
			agent.phase="idle"
		elif agent.phase=="blocked":
			agent.phase="idle"
		if person.job>0 and agent.visited_work_day!=eco.day:
			_depart(network,agent,person.job,"work")
		elif agent.shop_try_day!=eco.day and agent.bought_day!=eco.day and person.balance>=20:
			var shop:=_shop(network,agent)
			if shop>0:
				_depart(network,agent,shop,"shop")
			elif agent.at!=person.home:
				_depart(network,agent,person.home,"home")
			else: agent.wait=1.0
		elif agent.at!=person.home:
			_depart(network,agent,person.home,"home")
		else: agent.wait=1.0

func moving_count() -> int:
	var result:=0
	for agent in agents:
		if agent.phase=="walking": result+=1
	return result

func position(agent: Dictionary, housing) -> Vector2:
	if agent.phase=="walking": return Routes.position(agent.points,agent.distance)
	return Routes.gate(housing.lots[agent.at-1])

func serialize() -> Dictionary:
	var output: Array = []
	for agent in agents:
		var item: Dictionary=agent.duplicate(true)
		var points: Array=[]
		for p in agent.points: points.append([p.x,p.y])
		item.points=points
		output.append(item)
	return {"route_version":ROUTE_VERSION,"agents":output,"completed_trips":completed_trips}

static func restore(data: Dictionary, network):
	var result=load("res://scripts/citizen_travel.gd").new()
	if data.is_empty():
		result.sync(network)
		if network.housing.economy.day>0:
			for agent in result.agents:
				agent.worked_day=network.housing.economy.day
				agent.bought_day=network.housing.economy.day
				agent.shop_try_day=network.housing.economy.day
		return result
	if not data.get("agents") is Array or data.agents.size()!=network.housing.residents.size(): return null
	if not _integer(data.get("completed_trips")) or data.completed_trips<0: return null
	if not _integer(data.get("route_version",1)) or int(data.get("route_version",1)) not in [1,ROUTE_VERSION]: return null
	result.completed_trips=int(data.completed_trips)
	for item in data.agents:
		if not item is Dictionary: return null
		for key in ["id","at","origin","target","visited_work_day","worked_day","bought_day","shop_try_day"]:
			if not _integer(item.get(key)): return null
		if item.id!=result.agents.size()+1: return null
		for key in ["at","origin","target"]:
			if item[key]<1 or item[key]>network.housing.lots.size(): return null
		for key in ["visited_work_day","worked_day","bought_day","shop_try_day"]:
			if item[key]<-1 or item[key]>network.housing.economy.day: return null
		if item.get("phase") not in ["idle","walking","working","shopping","blocked"] or item.get("purpose") not in ["home","work","shop"]: return null
		for key in ["distance","length","wait"]:
			if not _number(item.get(key)) or item[key]<0: return null
		if int(data.get("route_version",1))==1 and item.wait>4: return null
		if item.wait>WORK_STAY or not item.get("points") is Array or item.points.size()>8192: return null
		var points:=PackedVector2Array()
		for p in item.points:
			if not p is Array or p.size()!=2 or not _number(p[0]) or not _number(p[1]) or maxf(absf(p[0]),absf(p[1]))>96: return null
			points.append(Vector2(p[0],p[1]))
		if item.phase=="walking":
			if points.is_empty() or absf(Routes.length(points)-float(item.length))>0.05 or item.distance>item.length+0.001: return null
			if points[0].distance_to(Routes.gate(network.housing.lots[int(item.origin)-1]))>0.1 or points[-1].distance_to(Routes.gate(network.housing.lots[int(item.target)-1]))>0.1: return null
		elif not points.is_empty() or item.distance!=0 or item.length!=0: return null
		var agent: Dictionary=item.duplicate(true)
		for key in ["id","at","origin","target","visited_work_day","worked_day","bought_day","shop_try_day"]: agent[key]=int(agent[key])
		for key in ["distance","length","wait"]: agent[key]=float(agent[key])
		agent.points=points
		if data.get("route_version",1)==1:
			if agent.phase=="walking":
				var old_position:=Routes.position(points,agent.distance)
				var updated: PackedVector2Array=result.router.route(network,agent.origin,agent.target)
				if updated.is_empty(): return null
				agent.points=updated
				agent.length=Routes.length(updated)
				agent.distance=Routes.nearest_progress(updated,old_position)
			elif agent.phase=="working": agent.wait=agent.wait/2.0*WORK_STAY
			elif agent.phase=="shopping": agent.wait=agent.wait/0.5*SHOP_STAY
		result.agents.append(agent)
	return result

static func _number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))
static func _integer(value) -> bool:
	return _number(value) and value==int(value)


func return_home(agent:Dictionary, home:int) -> void:
	for key in ["at","origin","target"]: agent[key]=home
	agent.phase="idle"
	agent.purpose="home"
	agent.points=PackedVector2Array()
	agent.distance=0.0
	agent.length=0.0
	agent.wait=1.0

func replan(network) -> void:
	router.revision=-1
	router.cache.clear()
	for agent in agents:
		if agent.phase!="walking": continue
		var previous_position:=Routes.position(agent.points,agent.distance)
		var points:PackedVector2Array=router.route(network,agent.origin,agent.target)
		if points.is_empty():
			return_home(agent,network.housing.residents[agent.id-1].home)
			agent.phase="blocked"
		else:
			agent.points=points
			agent.length=Routes.length(points)
			agent.distance=Routes.nearest_progress(points,previous_position)
