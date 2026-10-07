extends RefCounted
const Road=preload("res://scripts/citizen_routes.gd")
const Catalog=preload("res://scripts/vehicle_catalog.gd")
const LANE:=1.65
const OUTSIDE:=Vector2(-91,0)

static func address(lot:Dictionary)->Dictionary:
	return {"x":float(lot.x),"z":float(lot.z),"zone":str(lot.zone)}
static func find_lot(network,ref:Dictionary)->Dictionary:
	for lot in network.housing.lots:
		if lot.zone==ref.get("zone","") and is_equal_approx(float(lot.x),float(ref.get("x",10000))) and is_equal_approx(float(lot.z),float(ref.get("z",10000))):return lot
	return {}
static func key(point:Vector2)->String:return "%.3f:%.3f" % [point.x,point.y]
static func _anchor(network,ref:Dictionary)->Dictionary:
	if ref.get("entry",false)==true:return {"point":network.ENTRY,"node":0}
	var lot:=find_lot(network,ref)
	if lot.is_empty() or lot.stage!=2 or lot.road<0 or network.housing.road_components.get(lot.road,-1)!=0:return {}
	var frame:Dictionary=network.housing.frame(network.roads[lot.road],lot.distance)
	if frame.is_empty():return {}
	for i in range(network.edges.size()):
		var edge:Dictionary=network.edges[i]
		if edge.road!=lot.road:continue
		var p:=Geometry2D.get_closest_point_to_segment(frame.point,network.nodes[edge.from],network.nodes[edge.to])
		if p.distance_to(frame.point)<0.05:return {"point":p,"edge":i}
	return {}
static func _connect(adjacency:Array,a:int,b:int,cost:float)->void:
	adjacency[a].append({"to":b,"cost":cost})
	adjacency[b].append({"to":a,"cost":cost})
static func route(network,origin:Dictionary,destination:Dictionary,kind:String)->Dictionary:
	var start:=_anchor(network,origin)
	var finish:=_anchor(network,destination)
	if start.is_empty() or finish.is_empty() or start.point.distance_to(finish.point)<10:return {}
	var nodes:Array[Vector2]=network.nodes.duplicate()
	var adjacency:Array=[]
	for p in nodes:adjacency.append([])
	for edge in network.edges:_connect(adjacency,edge.from,edge.to,nodes[edge.from].distance_to(nodes[edge.to]))
	var ends:Array[int]=[]
	for anchor in [start,finish]:
		if anchor.has("node"):ends.append(anchor.node)
		else:
			var index:=nodes.size()
			nodes.append(anchor.point)
			adjacency.append([])
			ends.append(index)
			var edge:Dictionary=network.edges[anchor.edge]
			for end in [edge.from,edge.to]:_connect(adjacency,index,end,anchor.point.distance_to(nodes[end]))
	if start.has("edge") and finish.has("edge") and start.edge==finish.edge:_connect(adjacency,ends[0],ends[1],start.point.distance_to(finish.point))
	var distance:Array[float]=[]
	var previous:Array[int]=[]
	var visited:Array[bool]=[]
	for p in nodes:distance.append(INF);previous.append(-1);visited.append(false)
	distance[ends[0]]=0.0
	for iteration in range(nodes.size()):
		var current:=-1
		for i in range(nodes.size()):
			if not visited[i] and (current<0 or distance[i]<distance[current]):current=i
		if current<0 or is_inf(distance[current]):break
		if current==ends[1]:break
		visited[current]=true
		for edge in adjacency[current]:
			var next:float=distance[current]+edge.cost
			if next<distance[edge.to]:distance[edge.to]=next;previous[edge.to]=current
	if is_inf(distance[ends[1]]):return {}
	var chain:Array[int]=[]
	var node:int=ends[1]
	while node>=0:
		chain.push_front(node)
		node=previous[node]
	var center:=PackedVector2Array()
	if origin.get("entry",false):center.append(OUTSIDE)
	for i in chain:
		if center.is_empty() or center[-1].distance_to(nodes[i])>0.01:center.append(nodes[i])
	if destination.get("entry",false):center.append(OUTSIDE)
	var points:=PackedVector2Array()
	var gates:Array[Dictionary]=[]
	for i in range(center.size()):
		var p:=center[i]
		var incoming:Vector2=(center[i]-center[i-1]).normalized() if i>0 else (center[1]-center[0]).normalized()
		var outgoing:Vector2=(center[i+1]-center[i]).normalized() if i<center.size()-1 else incoming
		var n1:=Vector2(-incoming.y,incoming.x)*LANE
		var n2:=Vector2(-outgoing.y,outgoing.x)*LANE
		var corner:Vector2=p+(n1+n2)*0.5
		if absf(incoming.cross(outgoing))>0.0001:corner=p+n1+incoming*(n2-n1).cross(outgoing)/incoming.cross(outgoing)
		if corner.distance_to(p)>LANE*2:corner=p+(n1+n2)*0.5
		var junction:=false
		for index in range(network.nodes.size()):
			if network.nodes[index].distance_to(p)<0.05:
				junction=network.degree(p)>=3 or incoming.dot(outgoing)<0.985
				break
		if i>0 and i<center.size()-1 and junction:
			var setback:=minf(5.5,minf(p.distance_to(center[i-1]),p.distance_to(center[i+1]))*0.4)
			var a:=p-incoming*setback+n1
			var b:=p+outgoing*setback+n2
			points.append(a)
			for j in range(1,9):
				var t:=float(j)/8.0
				points.append(a.lerp(corner,t).lerp(corner.lerp(b,t),t))
			gates.append({"key":key(p),"center":p})
		else:points.append(corner)
	var clean:=PackedVector2Array()
	for p in points:
		if clean.is_empty() or p.distance_to(clean[-1])>0.001:clean.append(p)
	if clean.size()<2:return {}
	var length:=Road.length(clean)
	for gate in gates:
		var progress:=Road.nearest_progress(clean,gate.center)
		gate["enter"]=maxf(0,progress-6.0)
		gate["exit"]=minf(length,progress+6.0)
		gate.erase("center")
	var limits:Array[float]=[]
	for i in range(clean.size()-1):
		var mid:Vector2=(clean[i]+clean[i+1])*0.5
		var best:=INF
		var limit:=4.0
		for road in network.roads:
			for j in range(road.points.size()-1):
				var gap:float=mid.distance_to(Geometry2D.get_closest_point_to_segment(mid,road.points[j],road.points[j+1]))
				if gap<best:best=gap;limit=8.5 if road.get("surface","dirt")=="asphalt" else 4.0
		limits.append(limit)
	var result:={"points":clean,"length":length,"gates":gates,"limits":limits}
	if not fits(network,result,kind):return {}
	return result
static func pose(route_data:Dictionary,progress:float)->Dictionary:
	var points:PackedVector2Array=route_data.points
	var p:=Road.position(points,progress)
	var a:=Road.position(points,maxf(0,progress-0.4))
	var b:=Road.position(points,minf(route_data.length,progress+0.4))
	var direction:Vector2=(b-a).normalized()
	if direction.length_squared()<0.5:direction=(points[-1]-points[-2]).normalized()
	return {"point":p,"direction":direction}
static func footprint(route_data:Dictionary,progress:float,kind:String,margin:float=0.0)->PackedVector2Array:
	var frame:=pose(route_data,progress)
	var spec:=Catalog.spec(kind)
	var forward:Vector2=frame.direction*(spec.length/2.0+margin)
	var normal:Vector2=Vector2(-frame.direction.y,frame.direction.x)*(spec.width/2.0+margin)
	return PackedVector2Array([frame.point+forward+normal,frame.point+forward-normal,frame.point-forward-normal,frame.point-forward+normal])
static func on_road(network,p:Vector2)->bool:
	if p.distance_to(Geometry2D.get_closest_point_to_segment(p,Vector2(-96,0),network.ENTRY))<=3.58:return true
	for road in network.roads:
		for i in range(road.points.size()-1):
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,road.points[i],road.points[i+1]))<=3.58:return true
	return false
static func fits(network,path:Dictionary,kind:String)->bool:
	if Catalog.spec(kind).is_empty():return false
	for i in range(ceili(path.length)+1):
		for p in footprint(path,minf(float(i),path.length),kind):
			if not on_road(network,p):return false
	return true
static func speed_limit(path:Dictionary,progress:float)->float:
	var left:=progress
	for i in range(path.points.size()-1):
		var length:float=path.points[i].distance_to(path.points[i+1])
		if left<=length:return path.limits[i]
		left-=length
	return path.limits[-1]
