extends RefCounted
## Traçados persistentes; grafo derivado com divisão em cada cruzamento.
const INITIAL_CASH := 100000
const PRICE_PER_METER := 40
const ASPHALT_PRICE := 80
const UPGRADE_PRICE := 40
const GRID := 4.0
const ENTRY := Vector2(-80, 0)
var roads: Array[Dictionary] = []
var cash := INITIAL_CASH
var construction_spent := 0
var graph_revision := 0
var restoring := false
var housing = preload("res://scripts/residential.gd").new()
var traffic = preload("res://scripts/vehicle_traffic.gd").new()
var travel = preload("res://scripts/citizen_travel.gd").new()
var nodes: Array[Vector2] = []
var edges: Array[Dictionary] = []

func snap_point(point: Vector2) -> Vector2:
	return Vector2(snappedf(point.x, GRID), snappedf(point.y, GRID))

func aligned_end(_a: Vector2, point: Vector2) -> Vector2:
	return pick_start(point)

static func path(a: Vector2, b: Vector2, control = null) -> PackedVector2Array:
	if control == null:
		return PackedVector2Array([a, b])
	var c: Vector2 = control
	if not c.is_finite() or maxf(absf(c.x), absf(c.y)) > 192:
		return PackedVector2Array([a, b])
	var steps := maxi(8, int(ceil((a.distance_to(c) + c.distance_to(b)) / 1.5)))
	var points := PackedVector2Array()
	for i in range(steps + 1):
		var t := float(i) / steps
		points.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return points

func pick_start(point: Vector2) -> Vector2:
	var selected := snap_point(point)
	var closest := 6.0
	if point.distance_to(ENTRY) < 9.0:
		selected = ENTRY
		closest = point.distance_to(ENTRY)
	for road in roads:
		var points: PackedVector2Array = road.points
		for i in range(points.size() - 1):
			var nearest := Geometry2D.get_closest_point_to_segment(point, points[i], points[i + 1])
			var difference := point.distance_to(nearest)
			if difference < closest:
				selected = nearest
				closest = difference
	return selected

func connected(point: Vector2) -> bool:
	if point.distance_to(ENTRY) < 0.05:
		return true
	for road in roads:
		var points: PackedVector2Array = road.points
		for i in range(points.size() - 1):
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, points[i], points[i + 1])) < 0.05:
				return true
	return false

static func _overlap(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var direction := b - a
	if direction.length() < 0.001:
		return false
	if absf(direction.normalized().cross(c - a)) > 0.03 or absf(direction.normalized().cross(d - a)) > 0.03:
		return false
	var u := direction.normalized()
	return minf(direction.length(), maxf((c - a).dot(u), (d - a).dot(u))) - maxf(0, minf((c - a).dot(u), (d - a).dot(u))) > 0.05

func evaluate(a: Vector2, b: Vector2, control = null, surface: String = "dirt") -> Dictionary:
	for point in [a, b] + ([control] if control != null else []):
		if not point.is_finite() or maxf(absf(point.x), absf(point.y)) > 92:
			return {"valid": false, "reason": "Trecho fora do terreno ou ponto inválido.", "cost": 0, "length": 0.0, "points": PackedVector2Array([a, b])}
	var points := path(a, b, control)
	var length := 0.0
	var reason := ""
	for i in range(points.size() - 1):
		length += points[i].distance_to(points[i + 1])
	var cost := int(round(length * (ASPHALT_PRICE if surface=="asphalt" else PRICE_PER_METER)))
	if surface not in ["dirt","asphalt"]: reason="Tipo de rua inválido."
	for p in points:
		if not p.is_finite() or maxf(absf(p.x), absf(p.y)) > 92:
			reason = "Trecho fora do terreno ou ponto inválido."
	if reason.is_empty() and a.distance_to(b) < GRID:
		reason = "Separe início e fim por pelo menos 4 m."
	if reason.is_empty() and control != null:
		var c: Vector2 = control
		if not c.is_finite() or maxf(absf(c.x), absf(c.y)) > 92 or a.distance_to(c) < 4 or b.distance_to(c) < 4 or (c - a).normalized().dot((b - c).normalized()) < -0.8:
			reason = "Curva muito fechada. Afaste o ponto de ajuste."
	if reason.is_empty() and not restoring and not connected(a) and not connected(b):
		reason = "Conecte o início ou o fim à entrada ou a uma rua existente."
	if reason.is_empty() and cost > cash:
		reason = "Caixa insuficiente."
	if reason.is_empty():
		for road in roads:
			var old: PackedVector2Array = road.points
			for i in range(points.size() - 1):
				for j in range(old.size() - 1):
					if _overlap(points[i], points[i + 1], old[j], old[j + 1]):
						reason = "Este espaço já tem uma rua."
	if reason.is_empty():
		for lot in housing.lots:
			if housing.road_conflict(lot, [{"points": points}]):
				reason = "A rua atingiria um lote residencial. Escolha outro traçado."
	return {"valid": reason.is_empty(), "reason": reason, "cost": cost, "length": length, "points": points}

func commit(a: Vector2, b: Vector2, control = null, surface: String = "dirt") -> bool:
	var result := evaluate(a, b, control, surface)
	if not result.valid:
		return false
	roads.append({"a": a, "b": b, "control": control, "points": result.points, "surface": surface})
	cash -= result.cost
	construction_spent+=int(result.cost)
	rebuild_graph()
	refresh_access()
	return true

func _node(point: Vector2) -> int:
	for i in range(nodes.size()):
		if nodes[i].distance_to(point) < 0.05:
			return i
	nodes.append(point)
	return nodes.size() - 1

func rebuild_graph() -> void:
	graph_revision+=1
	nodes.clear()
	edges.clear()
	_node(ENTRY)
	var segments: Array[Dictionary] = []
	for r in range(roads.size()):
		var points: PackedVector2Array = roads[r].points
		for i in range(points.size() - 1):
			segments.append({"a": points[i], "b": points[i + 1], "road": r, "cuts": [points[i], points[i + 1]]})
	for i in range(segments.size()):
		for j in range(i + 1, segments.size()):
			if segments[i].road == segments[j].road:
				continue
			var hit = Geometry2D.segment_intersects_segment(segments[i].a, segments[i].b, segments[j].a, segments[j].b)
			if hit != null:
				segments[i].cuts.append(hit)
				segments[j].cuts.append(hit)
	for segment in segments:
		var origin: Vector2 = segment.a
		segment.cuts.sort_custom(func(p: Vector2, q: Vector2): return origin.distance_squared_to(p) < origin.distance_squared_to(q))
		for i in range(segment.cuts.size() - 1):
			if segment.cuts[i].distance_to(segment.cuts[i + 1]) > 0.05:
				edges.append({"from": _node(segment.cuts[i]), "to": _node(segment.cuts[i + 1]), "road": segment.road})

func degree(point: Vector2) -> int:
	var total := 0
	for edge in edges:
		if nodes[edge.from].distance_to(point) < 0.05 or nodes[edge.to].distance_to(point) < 0.05:
			total += 1
	return total

func serialize() -> Dictionary:
	travel.sync(self)
	traffic.sync(self)
	var segments: Array = []
	for road in roads:
		var item := {"a": [road.a.x, road.a.y], "b": [road.b.x, road.b.y], "surface": road.get("surface","dirt")}
		if road.control != null:
			item["control"] = [road.control.x, road.control.y]
		if road.get("custom_path",false):
			item["points"]=[]
			for p in road.points: item.points.append([p.x,p.y])
		segments.append(item)
	return {"network_version":3,"construction_spent":construction_spent,"roads": segments, "cash": cash, "residential": housing.serialize(), "travel":travel.serialize(),"traffic":traffic.serialize()}

static func restore(data: Dictionary):
	if not data.get("roads") is Array or not (data.get("cash") is float or data.get("cash") is int):
		return null
	if data.roads.size() > 1000:
		return null
	var model = load("res://scripts/streets_model.gd").new()
	model.cash = 1000000000
	if not model.housing.finite_number(data.get("network_version",1)) or int(data.get("network_version",1)) not in [1,2,3] or data.get("network_version",1)!=int(data.get("network_version",1)): return null
	model.restoring=data.get("network_version",1)>=2
	if not is_finite(float(data.cash)) or data.cash!=int(data.cash) or absf(data.cash)>1000000000:
		return null
	for item in data.roads:
		if not item is Dictionary:
			return null
		for key in ["a", "b"] + (["control"] if item.has("control") else []):
			if not item.get(key) is Array or item[key].size() != 2:
				return null
			for value in item[key]:
				if not (value is int or value is float) or not is_finite(float(value)):
					return null
		var surface = item.get("surface","dirt")
		if not surface is String or surface not in ["dirt","asphalt"]: return null
		var c = Vector2(item.control[0], item.control[1]) if item.has("control") else null
		if item.has("points"):
			if not model.restoring or not item.points is Array or item.points.size()<2 or item.points.size()>512: return null
			var points:=PackedVector2Array()
			for point in item.points:
				if not point is Array or point.size()!=2: return null
				for value in point:
					if not model.housing.finite_number(value) or absf(value)>92: return null
				points.append(Vector2(point[0],point[1]))
			if points[0]!=Vector2(item.a[0],item.a[1]) or points[-1]!=Vector2(item.b[0],item.b[1]): return null
			for i in range(points.size()-1):
				if points[i].distance_to(points[i+1])<0.01: return null
				for road in model.roads:
					for j in range(road.points.size()-1):
						if _overlap(points[i],points[i+1],road.points[j],road.points[j+1]): return null
			model.roads.append({"a":points[0],"b":points[-1],"control":null,"points":points,"custom_path":true,"surface":surface})
			model.cash-=roundi(preload("res://scripts/citizen_routes.gd").length(points)*(ASPHALT_PRICE if surface=="asphalt" else PRICE_PER_METER))
		else:
			if not model.commit(Vector2(item.a[0], item.a[1]), Vector2(item.b[0], item.b[1]), c, surface): return null
	var spent := 1000000000-int(model.cash)
	if model.restoring:
		var ledger=data.get("construction_spent")
		if not model.housing.finite_number(ledger) or ledger!=int(ledger) or ledger<spent-model.roads.size() or ledger>1000000000: return null
		spent=int(ledger)
	model.construction_spent=spent
	model.restoring=false
	model.rebuild_graph()
	if not data.get("residential",{}) is Dictionary:
		return null
	model.housing = preload("res://scripts/residential.gd").restore(data.get("residential",{}))
	if model.housing==null or INITIAL_CASH-spent+model.housing.economy.municipal_delta != data.cash:
		return null
	model.cash = int(data.cash)
	for lot in model.housing.lots:
		if lot.road < (-1 if data.get("network_version",1)>=2 else 0) or lot.road>=model.roads.size() or model.housing.road_conflict(lot,model.roads):
			return null
		for other in model.housing.lots:
			if other.id<lot.id and not Geometry2D.intersect_polygons(model.housing.polygon(lot),model.housing.polygon(other)).is_empty():
				return null
	model.refresh_access()
	if not data.get("travel",{}) is Dictionary: return null
	model.travel=preload("res://scripts/citizen_travel.gd").restore(data.get("travel",{}),model)
	if model.travel==null: return null
	if not data.get("traffic",{}) is Dictionary:return null
	model.traffic=preload("res://scripts/vehicle_traffic.gd").restore(data.get("traffic",{}),model)
	if model.traffic==null:return null
	return model

func road_length() -> float:
	var total := 0.0
	for road in roads:
		for i in range(road.points.size()-1):
			total += road.points[i].distance_to(road.points[i+1])
	return total

func simulate(delta: float) -> Dictionary:
	var remaining:=maxf(0.0,delta)
	var visual:=false
	var previous_day: int=housing.economy.day
	var previous_cash: int=housing.economy.municipal_delta
	while remaining>0.00000001:
		var step:=minf(remaining,minf(0.1,housing.economy.DAY_SECONDS-housing.economy.elapsed))
		if step<0.00000001:
			housing.economy.advance(0.00000001,housing,maintenance_length())
			continue
		visual=housing.advance(step) or visual
		travel.advance(step,self)
		traffic.advance(step,self)
		housing.economy.advance(step,housing,maintenance_length())
		remaining-=step
	cash+=housing.economy.municipal_delta-previous_cash
	return {"visual":visual,"day_changed":housing.economy.day!=previous_day}

func change_waiting_zone(lot_id: int, zone: String) -> Dictionary:
	if lot_id<1 or lot_id>housing.lots.size() or zone not in ["residential","commercial","industrial"]:
		return {"ok":false,"message":"Lote ou uso inválido."}
	var lot: Dictionary=housing.lots[lot_id-1]
	if housing.Utilities.is_service(lot.zone) or not lot.get("demand_pending",false) or lot.stage!=0 or lot.age!=0 or lot.has("business"):
		return {"ok":false,"message":"Troque o uso apenas de lotes aguardando demanda, antes da obra começar."}
	lot.zone=zone
	travel.router.revision=-1
	travel.router.cache.clear()
	return {"ok":true,"message":"Uso alterado. O lote continua sujeito à demanda."}

func cancel_unfinished_lot(lot_id: int) -> Dictionary:
	if lot_id<1 or lot_id>housing.lots.size():
		return {"ok":false,"message":"Lote não encontrado."}
	var lot: Dictionary=housing.lots[lot_id-1]
	if lot.stage>=2 or lot.has("business"):
		return {"ok":false,"message":"Imóveis concluídos ainda não podem ser removidos nesta etapa."}
	for person in housing.residents:
		if person.home==lot_id or person.job==lot_id:
			return {"ok":false,"message":"O lote já está vinculado a um morador."}
	for agent in travel.agents:
		for key in ["at","origin","target"]:
			if agent[key]==lot_id:
				return {"ok":false,"message":"O lote já está vinculado a uma viagem."}
	housing.lots.remove_at(lot_id-1)
	for i in range(lot_id-1,housing.lots.size()): housing.lots[i].id=i+1
	for person in housing.residents:
		for key in ["home","job"]:
			if person[key]>lot_id: person[key]-=1
	for agent in travel.agents:
		for key in ["at","origin","target"]:
			if agent[key]>lot_id: agent[key]-=1
	travel.router.revision=-1
	travel.router.cache.clear()
	return {"ok":true,"message":"Lote liberado. Sem reembolso; o caixa foi mantido."}


func refresh_access() -> void:
	traffic.revision=-1
	# Derivar componentes e recalcular ancoragem sem depender da ordem de criação das ruas.
	var components: Array[int]=[]
	for _point in nodes: components.append(-1)
	var adjacency: Array=[]
	for _point in nodes: adjacency.append([])
	for edge in edges:
		adjacency[edge.from].append(edge.to)
		adjacency[edge.to].append(edge.from)
	var group:=0
	for start in range(nodes.size()):
		if components[start]>=0: continue
		var queue: Array[int]=[start]
		components[start]=group
		while not queue.is_empty():
			var current:int=queue.pop_back()
			for neighbor in adjacency[current]:
				if components[neighbor]<0:
					components[neighbor]=group
					queue.append(neighbor)
		group+=1
	housing.road_components.clear()
	for edge in edges: housing.road_components[edge.road]=components[edge.from]
	for lot in housing.lots:
		var front:Vector2=Vector2(lot.x,lot.z)-Vector2(-sin(lot.angle),cos(lot.angle))*(float(lot.depth)/2.0+4.6)
		var best:=0.3
		lot.road=-1
		for r in range(roads.size()):
			var length_so_far:=0.0
			var points:PackedVector2Array=roads[r].points
			for i in range(points.size()-1):
				var nearest:=Geometry2D.get_closest_point_to_segment(front,points[i],points[i+1])
				if front.distance_to(nearest)<best:
					best=front.distance_to(nearest)
					lot.road=r
					lot.distance=length_so_far+points[i].distance_to(nearest)
				length_so_far+=points[i].distance_to(points[i+1])
	housing.Utilities.apply(housing)
	travel.router.revision=-1
	travel.router.cache.clear()

func road_chunks() -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	var degrees:Dictionary={}
	for edge in edges:
		degrees[edge.from]=degrees.get(edge.from,0)+1
		degrees[edge.to]=degrees.get(edge.to,0)+1
	for r in range(roads.size()):
		var current:=PackedVector2Array()
		for edge in edges:
			if edge.road!=r: continue
			if current.is_empty(): current.append(nodes[edge.from])
			current.append(nodes[edge.to])
			if degrees.get(edge.to,0)!=2:
				result.append({"road":r,"points":current})
				current=PackedVector2Array()
		if current.size()>1: result.append({"road":r,"points":current})
	return result

func pick_demolition_road(point:Vector2) -> Dictionary:
	var best:=4.5
	var found:Dictionary={}
	for chunk in road_chunks():
		for i in range(chunk.points.size()-1):
			var distance_value:float=point.distance_to(Geometry2D.get_closest_point_to_segment(point,chunk.points[i],chunk.points[i+1]))
			if distance_value<best:
				best=distance_value
				found=chunk
	return found

func demolish_road(target:Dictionary) -> Dictionary:
	if target.is_empty(): return {"ok":false,"message":"Trecho inválido."}
	var chunks:=road_chunks()
	var found:=false
	var replacement:Array[Dictionary]=[]
	for chunk in chunks:
		if chunk.road!=target.road: continue
		if chunk.points==target.points:
			found=true
		else:
			var points:PackedVector2Array=chunk.points
			replacement.append({"a":points[0],"b":points[-1],"control":null,"points":points,"custom_path":true,"surface":roads[int(chunk.road)].get("surface","dirt")})
	if not found: return {"ok":false,"message":"O trecho mudou. Selecione novamente."}
	roads.remove_at(int(target.road))
	roads.append_array(replacement)
	rebuild_graph()
	refresh_access()
	travel.replan(self)
	return {"ok":true,"message":"Trecho demolido. Acesso, serviços e viagens recalculados. Sem reembolso."}

func demolish_lot(lot_id:int, keep_zone:bool=false) -> Dictionary:
	if lot_id<1 or lot_id>housing.lots.size(): return {"ok":false,"message":"Lote não encontrado."}
	travel.sync(self)
	var lot:Dictionary=housing.lots[lot_id-1]
	var survivors:Array[Dictionary]=[]
	var agents:Array[Dictionary]=[]
	var departing:=0
	for person in housing.residents:
		if person.home==lot_id:
			housing.economy.exterior_balance+=int(person.balance)
			departing+=1
			continue
		var agent:Dictionary=travel.agents[int(person.id)-1]
		person.id=survivors.size()+1
		agent.id=person.id
		if person.job==lot_id: person.job=0
		if agent.at==lot_id or agent.origin==lot_id or agent.target==lot_id:
			travel.return_home(agent,person.home)
		survivors.append(person)
		agents.append(agent)
	housing.residents=survivors
	travel.agents=agents
	if lot.has("business"): housing.economy.exterior_balance+=int(lot.business.cash)
	if keep_zone and not housing.Utilities.is_service(lot.zone):
		lot.erase("business")
		lot.age=0.0
		lot.stage=0
		lot.demand_pending=true
		lot.utility_exempt=false
		lot.sewer_exempt=false
	else:
		housing.lots.remove_at(lot_id-1)
		for i in range(housing.lots.size()): housing.lots[i].id=i+1
		for person in housing.residents:
			for key in ["home","job"]:
				if person[key]>lot_id: person[key]-=1
		for agent in travel.agents:
			for key in ["at","origin","target"]:
				if agent[key]>lot_id: agent[key]-=1
	housing.economy.hire(housing)
	refresh_access()
	return {"ok":true,"message":"Demolição concluída. %d moradores deixaram a cidade. %s" % [departing,"Zoneamento mantido; poderá reconstruir." if keep_zone else "Espaço liberado."]}

const Catalog=preload("res://scripts/city_catalog.gd")
func place_lot(lot:Dictionary)->Dictionary:
	if lot.is_empty() or lot.get("id",0)!=housing.lots.size()+1 or housing.lots.size()>=housing.LIMIT: return {"ok":false,"message":"Lote inválido ou já autorizado."}
	if int(lot.get("road",-1))<0 or int(lot.road)>=roads.size(): return {"ok":false,"message":"Sem acesso à rua."}
	var cost:=0
	if lot.zone in ["water","power","sewage"]:
		var spec:=Catalog.for_lot(lot)
		if spec.is_empty() or lot.width!=spec.width or lot.depth!=spec.depth: return {"ok":false,"message":"Instalação inválida."}
		cost=int(spec.price)
	elif lot.zone not in ["residential","commercial","industrial"]: return {"ok":false,"message":"Zona inválida."}
	if cost>0 and cash<cost: return {"ok":false,"message":"Caixa insuficiente: precisa de R$ %d." % cost}
	if housing.road_conflict(lot,roads): return {"ok":false,"message":"Lote sobre a rua."}
	for existing in housing.lots:
		if not Geometry2D.intersect_polygons(housing.polygon(lot),housing.polygon(existing,0.15)).is_empty(): return {"ok":false,"message":"Espaço já ocupado."}
	if lot.zone=="water" and preload("res://scripts/water_resources.gd").field_at(Vector2(lot.x,lot.z))<0: return {"ok":false,"message":"Captação exige aquífero. Consulte o mapa de fontes."}
	var committed:=lot.duplicate(true)
	committed["sewer_exempt"]=false
	if lot.zone=="water": committed["source_legacy"]=false
	if cost>0: committed["build_paid"]=cost
	housing.commit(committed)
	cash-=cost
	housing.economy.municipal_delta-=cost
	housing.economy.exterior_balance+=cost
	housing.economy.public_works_spent+=cost
	refresh_access()
	return {"ok":true,"cost":cost,"message":"Obra autorizada."}

func budget_forecast(candidate:Dictionary={})->Dictionary:
	var length_value:=0.0
	for road in roads:
		var points:PackedVector2Array=road.points
		for i in range(points.size()-1): length_value+=points[i].distance_to(points[i+1])*(2.4 if road.get("surface","dirt")=="asphalt" else 1.0)
	var item:Dictionary={} if candidate.is_empty() else Catalog.for_lot(candidate)
	var price:=int(item.get("price",0))
	var upkeep:=int(item.get("maintenance",0))
	var road_cost:=int(ceil(length_value*0.05))
	var committed:=Catalog.upkeep(housing,true)
	var taxes:=int(housing.economy.last.taxes)
	return {"price":price,"cash_after":cash-price,"roads":road_cost,"active":Catalog.upkeep(housing),"committed":committed,"candidate":upkeep,"taxes":taxes,"net":taxes-road_cost-committed-upkeep}

func budget_details()->Dictionary:
	var economy=housing.economy
	var active:Dictionary=economy.maintenance_breakdown(housing,maintenance_length())
	var authorized:Dictionary=economy.maintenance_breakdown(housing,maintenance_length(),true)
	var counts:={"water":{"ready":0,"works":0},"power":{"ready":0,"works":0},"sewage":{"ready":0,"works":0}}
	for lot in housing.lots:
		if lot.zone in counts: counts[lot.zone]["ready" if lot.stage==2 else "works"]+=1
	return {"last":economy.last.duplicate(true),"last_breakdown":economy.last_maintenance.duplicate(true),"known":economy.last_breakdown_known,"active":active,"authorized":authorized,"counts":counts,"active_net":int(economy.last.taxes)-economy.breakdown_total(active),"authorized_net":int(economy.last.taxes)-economy.breakdown_total(authorized),"taxes_today":int(economy.current.taxes),"seconds_left":economy.DAY_SECONDS-economy.elapsed,"roads_spent":construction_spent,"facilities_spent":economy.public_works_spent}


func maintenance_length()->float:
	var total:=0.0
	for road in roads:
		total+=preload("res://scripts/citizen_routes.gd").length(road.points)*(2.4 if road.get("surface","dirt")=="asphalt" else 1.0)
	return total

func upgrade_quote(target:Dictionary)->Dictionary:
	var result:={"valid":false,"reason":"Selecione um trecho de terra.","cost":0,"length":0.0,"maintenance_after":int(ceil(maintenance_length()*0.05)),"cash_after":cash}
	for chunk in road_chunks():
		if chunk.road!=target.get("road",-1) or chunk.points!=target.get("points",PackedVector2Array()): continue
		result.length=preload("res://scripts/citizen_routes.gd").length(chunk.points)
		if roads[int(chunk.road)].get("surface","dirt")=="asphalt":
			result.reason="Este trecho já está asfaltado."
			return result
		result.cost=roundi(result.length*UPGRADE_PRICE)
		result.cash_after=cash-result.cost
		result.maintenance_after=int(ceil((maintenance_length()+result.length*1.4)*0.05))
		result.valid=result.cash_after>=0
		result.reason="" if result.valid else "Caixa insuficiente."
		return result
	return result

func upgrade_road(target:Dictionary)->Dictionary:
	var quote:=upgrade_quote(target)
	if not quote.valid: return {"ok":false,"message":quote.reason}
	var replacement:Array[Dictionary]=[]
	for chunk in road_chunks():
		if chunk.road!=target.road: continue
		var points:PackedVector2Array=chunk.points
		replacement.append({"a":points[0],"b":points[-1],"control":null,"points":points,"custom_path":true,"surface":"asphalt" if points==target.points else roads[int(chunk.road)].get("surface","dirt")})
	roads.remove_at(int(target.road))
	roads.append_array(replacement)
	cash-=int(quote.cost)
	construction_spent+=int(quote.cost)
	rebuild_graph()
	refresh_access()
	travel.replan(self)
	return {"ok":true,"message":"Trecho asfaltado com calçadas. Imóveis e conexões preservados."}

func demolition_impact(target:Dictionary)->Dictionary:
	var copy=load("res://scripts/streets_model.gd").restore(serialize())
	var result:={"valid":false,"no_road":[],"isolated":[]}
	if copy==null or not copy.demolish_road(target).ok: return result
	result.valid=true
	for i in range(housing.lots.size()):
		var before:Dictionary=housing.lots[i]
		var after:Dictionary=copy.housing.lots[i]
		if before.road>=0 and after.road<0: result.no_road.append(int(before.id))
		elif before.road>=0 and housing.road_components.get(before.road,-1)==0 and after.road>=0 and copy.housing.road_components.get(after.road,-1)!=0: result.isolated.append(int(before.id))
	return result
