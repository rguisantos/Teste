extends RefCounted
## Lotes ancorados por distância ao longo da rua, inclusive curvas.
const WIDTH := 10.0
const DEPTH := 12.0
const LIMIT := 128
const Resources=preload("res://scripts/water_resources.gd")
const Catalog = preload("res://scripts/city_catalog.gd")
const Utilities = preload("res://scripts/city_utilities.gd")
const Demand = preload("res://scripts/city_demand.gd")
var lots: Array[Dictionary] = []
var residents: Array[Dictionary] = []
var road_components:Dictionary={}
var economy = preload("res://scripts/economy.gd").new()

static func frame(road: Dictionary, distance_value: float) -> Dictionary:
	var points: PackedVector2Array = road.points
	var remaining := distance_value
	for i in range(points.size() - 1):
		var length_value := points[i].distance_to(points[i + 1])
		if remaining <= length_value:
			return {"point": points[i].lerp(points[i + 1], remaining / length_value), "axis": (points[i + 1] - points[i]).normalized()}
		remaining -= length_value
	return {}

static func polygon(lot: Dictionary, margin: float = 0.0) -> PackedVector2Array:
	var center := Vector2(lot.x, lot.z)
	var axis := Vector2(cos(lot.angle), sin(lot.angle))
	var normal := Vector2(-axis.y, axis.x)
	var result := PackedVector2Array()
	for corner in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]:
		result.append(center + axis * corner.x * (float(lot.get("width",WIDTH)) / 2 + margin) + normal * corner.y * (float(lot.get("depth",DEPTH)) / 2 + margin))
	return result

static func road_conflict(lot: Dictionary, roads: Array[Dictionary]) -> bool:
	var boundary := polygon(lot, 0.25)
	for road in roads:
		for strip in Geometry2D.offset_polyline(road.points, 4.1, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
			if not Geometry2D.intersect_polygons(boundary, strip).is_empty():
				return true
	return false

static func sizes(mode: String) -> Array[Vector2]:
	match mode:
		"small": return [Vector2(4,6)]
		"medium": return [Vector2(6,8)]
		"large": return [Vector2(10,12)]
	return [Vector2(10,12),Vector2(8,10),Vector2(6,8),Vector2(4,6)]

func candidate(point: Vector2, roads: Array[Dictionary], height: Callable, zone: String = "residential", mode: String = "auto", catalog_id: String = "") -> Dictionary:
	if lots.size() >= LIMIT or zone not in ["residential","commercial","industrial","water","power","sewage"]:
		return {}
	if Utilities.is_service(zone):
		var spec:=Catalog.spec(zone,catalog_id)
		if spec.is_empty(): return {}
		mode=spec.size
	var contours: Array[PackedVector2Array] = []
	for road in roads:
		contours.append_array(Geometry2D.offset_polyline(road.points,4.1,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND))
	var best: Dictionary = {}
	var best_score := INF
	for r in range(roads.size()):
		var points: PackedVector2Array = roads[r].points
		var total := 0.0
		var nearest_distance := INF
		var nearest_offset := 0.0
		for i in range(points.size()-1):
			var nearest := Geometry2D.get_closest_point_to_segment(point,points[i],points[i+1])
			var distance_value := point.distance_to(nearest)
			if distance_value < nearest_distance:
				nearest_distance = distance_value
				nearest_offset = total+points[i].distance_to(nearest)
			total += points[i].distance_to(points[i+1])
		if nearest_distance > 23:
			continue
		for size_value in sizes(mode):
			for offset in range(-5,6):
				var along := snappedf(nearest_offset,2.0)+offset*2.0
				if along < size_value.x/2+0.4 or along > total-size_value.x/2-0.4:
					continue
				var basis := frame(roads[r],along)
				var axis: Vector2 = basis.axis
				for side in [-1,1]:
					var center: Vector2 = basis.point+Vector2(-axis.y,axis.x)*side*(4.6+size_value.y/2)
					var distance_value := center.distance_to(point)
					var score := distance_value+(10.0-size_value.x)*0.22
					if distance_value > 10 or score >= best_score:
						continue
					var lot := {"x":center.x,"z":center.y,"angle":axis.angle()+(PI if side<0 else 0.0),"road":r,"distance":along,"side":side,"age":0.0,"stage":0,"id":lots.size()+1,"width":size_value.x,"depth":size_value.y,"zone":zone,"capacity":(2 if size_value.x<=4 else (3 if size_value.x<=6 else 2+(lots.size()+1)%3)),"variant":(lots.size()+1)%3}
					if zone=="water" and Resources.field_at(center)<0: continue
					var corners := polygon(lot)
					var samples := corners.duplicate()
					samples.append(center)
					var valid := true
					var low := INF
					var high := -INF
					for p in samples:
						if maxf(absf(p.x),absf(p.y))>91:
							valid = false
						var y: float = height.call(p.x,p.y)
						low = minf(low,y)
						high = maxf(high,y)
					if high-low>1.0:
						valid = false
					if valid:
						for existing in lots:
							if center.distance_to(Vector2(existing.x,existing.z))<20 and not Geometry2D.intersect_polygons(corners,polygon(existing,0.15)).is_empty():
								valid = false
								break
					if valid:
						for strip in contours:
							if not Geometry2D.intersect_polygons(polygon(lot,0.15),strip).is_empty():
								valid = false
								break
					if valid:
						if Utilities.is_service(zone): lot["catalog_id"]=zone+"_"+mode
						lot["height"] = high+0.06
						best = lot
						best_score = score
	return best

func commit(lot: Dictionary) -> void:
	var committed: Dictionary=lot.duplicate(true)
	committed["sewer_exempt"]=bool(committed.get("sewer_exempt",committed.get("utility_exempt",false)))
	if committed.zone=="water": committed["source_legacy"]=bool(committed.get("source_legacy",false))
	committed["demand_pending"]=not Utilities.is_service(committed.zone)
	committed["utility_exempt"]=bool(committed.get("utility_exempt",false))
	if Utilities.is_service(committed.zone):
		committed["catalog_id"]=committed.get("catalog_id",committed.zone+"_medium")
		committed["build_paid"]=committed.get("build_paid",0)
	lots.append(committed)

func advance(delta: float) -> bool:
	if delta<=0: return false
	var unfinished:=false
	for lot in lots:
		if lot.stage<2:
			unfinished=true
			break
	if not unfinished:
		Utilities.apply(self)
		return false
	var changed := false
	var demand_stats:=Demand.capture(self)
	var supply:=Utilities.budget(self)
	for lot in lots:
		if lot.stage >= 2:
			continue
		if lot.get("demand_pending",false):
			if Demand.remaining(demand_stats,lot.zone)<=0 or not Utilities.can_start(lot,supply): continue
			lot.demand_pending=false
			Demand.reserve(demand_stats,lot,economy)
			Utilities.reserve(lot,supply)
			changed=true
		if lot.road<0: continue
		if not Utilities.is_service(lot.zone) and (not Utilities.operational(lot,supply) or Utilities.component(lot,supply)!=0): continue
		lot.age = minf(24.0, lot.age + maxf(0.0, delta))
		var stage := 2 if lot.age >= 24.0 else (1 if lot.age >= 6.0 else 0)
		if stage != lot.stage:
			lot.stage = stage
			changed = true
			if stage == 2 and lot.zone == "residential":
				for i in range(int(lot.capacity)):
					var id: int = residents.size() + 1
					var person := {"id": id, "home": int(lot.id), "name": ["Ana", "João", "Maria", "Pedro", "Carla", "José"][id % 6] + " " + ["Silva", "Santos", "Oliveira"][int(lot.id) % 3], "age": 18 + (id * 7) % 53, "balance":0,"job":0}
					economy.fund_household(person)
					residents.append(person)
			elif stage == 2 and lot.zone in ["commercial","industrial"]:
				economy.fund_business(lot)
		if stage==2:
			demand_stats=Demand.capture(self)
			supply=Utilities.budget(self)
	Utilities.apply(self)
	if changed:
		economy.hire(self)
	return changed

func serialize() -> Dictionary:
	return {"sanitation_version":1,"lots": lots.duplicate(true), "residents": residents.duplicate(true), "economy": economy.serialize()}

static func restore(data: Dictionary):
	var model = load("res://scripts/residential.gd").new()
	var sanitation_version=data.get("sanitation_version",0)
	if not finite_number(sanitation_version) or sanitation_version!=int(sanitation_version) or int(sanitation_version) not in [0,1]: return null
	var legacy := not data.has("economy")
	if not legacy:
		if not data.economy is Dictionary:
			return null
		model.economy = preload("res://scripts/economy.gd").restore(data.economy)
		if model.economy == null:
			return null
	if not data.get("lots", []) is Array or not data.get("residents", []) is Array:
		return null
	if data.get("lots", []).size() > LIMIT:
		return null
	for item in data.get("lots", []):
		if not item is Dictionary:
			return null
		for key in ["x", "z", "angle", "height", "age", "stage", "id", "road", "distance", "side"]:
			if not (item.get(key) is float or item.get(key) is int) or not is_finite(float(item[key])):
				return null
		if item.id != model.lots.size() + 1 or int(item.stage) not in [0,1,2] or item.stage != int(item.stage) or item.age < 0 or item.age > 26 or absf(item.x) > 91 or absf(item.z) > 91 or absf(item.height) > 10:
			return null
		if item.stage != (2 if item.age >= 24 else (1 if item.age >= 6 else 0)):
			return null
		if not item.get("demand_pending",false) is bool: return null
		if item.get("demand_pending",false) and (item.stage!=0 or item.age!=0): return null
		if sanitation_version==1 and (not item.has("sewer_exempt") or (item.get("zone","")=="water" and not item.has("source_legacy"))): return null
		var lot: Dictionary = item.duplicate(true)
		lot["demand_pending"]=lot.get("demand_pending",false)
		if not lot.get("utility_exempt",false) is bool: return null
		lot["utility_exempt"]=lot.get("utility_exempt",not lot.demand_pending)
		if not lot.get("sewer_exempt",true) is bool: return null
		lot["sewer_exempt"]=lot.get("sewer_exempt",true)
		if lot.get("zone","")=="water":
			if not lot.get("source_legacy",true) is bool: return null
			lot["source_legacy"]=lot.get("source_legacy",true)
			if not lot.source_legacy and Resources.field_at(Vector2(lot.x,lot.z))<0: return null
		for key in ["width","depth","capacity","variant"]:
			if item.has(key) and not finite_number(item[key]):
				return null
		lot["width"] = float(lot.get("width",10.0))
		lot["depth"] = float(lot.get("depth",12.0))
		lot["zone"] = lot.get("zone","residential")
		lot["capacity"] = lot.get("capacity",2+int(lot.id)%3)
		lot["variant"] = lot.get("variant",int(lot.id)%3)
		if Vector2(lot.width,lot.depth) not in [Vector2(4,6),Vector2(6,8),Vector2(8,10),Vector2(10,12)] or lot.zone not in ["residential","commercial","industrial","water","power","sewage"]:
			return null
		if lot.capacity != int(lot.capacity) or lot.capacity<1 or lot.capacity>4 or lot.variant != int(lot.variant) or lot.variant<0 or lot.variant>2:
			return null
		lot.capacity = int(lot.capacity)
		lot.variant = int(lot.variant)
		if Utilities.is_service(lot.zone):
			var spec:=Catalog.for_lot(lot)
			if spec.is_empty() or lot.has("business") or lot.demand_pending or lot.width!=spec.width or lot.depth!=spec.depth: return null
			lot["catalog_id"]=lot.get("catalog_id",lot.zone+"_medium")
			var paid=lot.get("build_paid",0)
			if not finite_number(paid) or paid!=int(paid) or int(paid) not in [0,int(spec.price)]: return null
			lot["build_paid"]=int(paid)
		if lot.zone in ["commercial","industrial"] and lot.stage == 2:
			if not lot.get("business") is Dictionary:
				return null
			for key in ["cash","stock"]:
				if not finite_number(lot.business.get(key)) or lot.business[key]<0 or lot.business[key]!=int(lot.business[key]):
					return null
				lot.business[key] = int(lot.business[key])
		for key in ["id", "stage", "road", "side"]:
			if lot[key] != int(lot[key]):
				return null
			lot[key] = int(lot[key])
		model.lots.append(lot)
	var counts := {}
	for item in data.get("residents", []):
		if not item is Dictionary or item.get("id") != model.residents.size() + 1 or not (item.get("home") is float or item.get("home") is int):
			return null
		var home := int(item.home)
		if home < 1 or home > model.lots.size() or (model.lots[home - 1].stage != 2 or model.lots[home - 1].zone != "residential") or not item.get("name") is String or not (item.get("age") is int or item.get("age") is float):
			return null
		var citizen: Dictionary = item.duplicate(true)
		citizen.erase("employment")
		if legacy:
			model.economy.fund_household(citizen)
		for key in ["balance","job"]:
			if not finite_number(citizen.get(key)) or citizen[key]<0 or citizen[key]!=int(citizen[key]):
				return null
			citizen[key] = int(citizen[key])
		if citizen.job > model.lots.size() or (citizen.job>0 and (model.lots[citizen.job-1].zone not in ["commercial","industrial"] or model.lots[citizen.job-1].stage!=2)):
			return null
		for key in ["id", "home", "age"]:
			if citizen[key] != int(citizen[key]):
				return null
			citizen[key] = int(citizen[key])
		model.residents.append(citizen)
		counts[home] = counts.get(home, 0) + 1
	for lot in model.lots:
		if counts.get(int(lot.id), 0) != (lot.capacity if lot.stage == 2 and lot.zone == "residential" else 0):
			return null
	if model.economy.account_total(model) != 0:
		return null
	return model

static func finite_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))
