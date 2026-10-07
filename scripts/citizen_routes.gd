extends RefCounted
## Grafo das duas bordas: continuidade em curvas e travessias nas bocas das esquinas.
const SIDE_OFFSET := 4.05
const JUNCTION_SETBACK := 5.0
var vertices: Array[Vector2] = []
var adjacency: Array = []
var edge_sides: Array[Dictionary] = []
var crossings: Array[PackedVector2Array] = []
var revision := -1
var cache := {}

func _vertex(point: Vector2) -> int:
	vertices.append(point)
	adjacency.append([])
	return vertices.size()-1

func _link(a: int, b: int, middle: PackedVector2Array = PackedVector2Array()) -> void:
	var points:=PackedVector2Array([vertices[a]])
	points.append_array(middle)
	points.append(vertices[b])
	var cost:=length(points)
	adjacency[a].append({"node":b,"cost":cost,"points":points.duplicate()})
	points.reverse()
	adjacency[b].append({"node":a,"cost":cost,"points":points.duplicate()})

func rebuild(network) -> void:
	vertices.clear()
	adjacency.clear()
	edge_sides.clear()
	crossings.clear()
	cache.clear()
	revision=network.graph_revision
	var ports: Array=[]
	var degree: Array[int]=[]
	var directions: Array=[]
	var junction: Array[bool]=[]
	for point in network.nodes:
		ports.append([])
		degree.append(0)
		directions.append([])
	for edge in network.edges:
		degree[edge.from]+=1
		degree[edge.to]+=1
		var direction: Vector2=(network.nodes[edge.to]-network.nodes[edge.from]).normalized()
		directions[edge.from].append(direction)
		directions[edge.to].append(-direction)
	for i in range(degree.size()):
		junction.append(degree[i]>=3 or (degree[i]==2 and directions[i][0].dot(directions[i][1])>-0.985))
	for edge in network.edges:
		var a: Vector2=network.nodes[edge.from]
		var b: Vector2=network.nodes[edge.to]
		var direction: Vector2=(b-a).normalized()
		var normal:=Vector2(-direction.y,direction.x)
		var setback_a: float=minf(JUNCTION_SETBACK,a.distance_to(b)*0.4) if junction[edge.from] else 0.0
		var setback_b: float=minf(JUNCTION_SETBACK,a.distance_to(b)*0.4) if junction[edge.to] else 0.0
		var fl:=_vertex(a+direction*setback_a+normal*SIDE_OFFSET)
		var fr:=_vertex(a+direction*setback_a-normal*SIDE_OFFSET)
		var tl:=_vertex(b-direction*setback_b+normal*SIDE_OFFSET)
		var tr:=_vertex(b-direction*setback_b-normal*SIDE_OFFSET)
		_link(fl,tl)
		_link(fr,tr)
		edge_sides.append({"left":[fl,tl],"right":[fr,tr],"normal":normal})
		ports[edge.from].append({"left":fl,"right":fr,"direction":direction})
		ports[edge.to].append({"left":tr,"right":tl,"direction":-direction})
	for i in range(ports.size()):
		var center: Vector2=network.nodes[i]
		var entries: Array=ports[i]
		if entries.is_empty(): continue
		entries.sort_custom(func(a,b): return a.direction.angle()<b.direction.angle())
		if entries.size()==1:
			# Contorna o final da rua sem cortar a pista.
			var port: Dictionary=entries[0]
			var arc:=PackedVector2Array()
			var outward: Vector2=-port.direction
			var start_angle: float=(vertices[port.left]-center).angle()
			var sign_value:=1.0 if Vector2.from_angle(start_angle+PI/2).dot(outward)>0 else -1.0
			for step in range(1,9): arc.append(center+Vector2.from_angle(start_angle+sign_value*PI*step/9.0)*SIDE_OFFSET)
			_link(port.left,port.right,arc)
		else:
			for j in range(entries.size()):
				var first: Dictionary=entries[j]
				var second: Dictionary=entries[(j+1)%entries.size()]
				var d1: Vector2=first.direction
				var d2: Vector2=second.direction
				var p1:=center+Vector2(-d1.y,d1.x)*SIDE_OFFSET
				var p2:=center-Vector2(-d2.y,d2.x)*SIDE_OFFSET
				var corner: Vector2=(p1+p2)*0.5
				if absf(d1.cross(d2))>0.0001:
					corner=p1+d1*((p2-p1).cross(d2)/d1.cross(d2))
				# Junta de ângulo extremo usa bisel limitado para evitar espigões.
				if corner.distance_to(center)>SIDE_OFFSET*3:
					_link(first.left,second.right,PackedVector2Array([p1,p2]))
				else: _link(first.left,second.right,PackedVector2Array([corner]))
			# Cruzar só nas esquinas/junções; amostras suaves de curvas não criam travessias.
			var is_corner: bool=entries.size()>=3 or entries[0].direction.dot(entries[1].direction)>-0.985
			if is_corner:
				for port in entries:
					_link(port.left,port.right)
					crossings.append(PackedVector2Array([vertices[port.left],vertices[port.right]]))

func _anchor(network, lot: Dictionary) -> Dictionary:
	if lot.road<0 or lot.road>=network.roads.size(): return {}
	var frame: Dictionary=network.housing.frame(network.roads[lot.road],lot.distance)
	if frame.is_empty(): return {}
	var point: Vector2=frame.point
	var closest:=INF
	var selected:=-1
	var center:=Vector2.ZERO
	for i in range(network.edges.size()):
		var edge: Dictionary=network.edges[i]
		if edge.road!=lot.road: continue
		var p:=Geometry2D.get_closest_point_to_segment(point,network.nodes[edge.from],network.nodes[edge.to])
		if point.distance_to(p)<closest:
			closest=point.distance_to(p)
			selected=i
			center=p
	if selected<0: return {}
	var side: Dictionary=edge_sides[selected]
	var normal: Vector2=side.normal
	var left: bool=(gate(lot)-center).dot(normal)>=0
	var endpoints: Array=side.left if left else side.right
	var p:=Geometry2D.get_closest_point_to_segment(center+normal*SIDE_OFFSET*(1 if left else -1),vertices[endpoints[0]],vertices[endpoints[1]])
	return {"point":p,"a":endpoints[0],"b":endpoints[1],"edge":selected,"left":left}

static func gate(lot: Dictionary) -> Vector2:
	return Vector2(lot.x,lot.z)-Vector2(-sin(lot.angle),cos(lot.angle))*float(lot.depth)/2

static func length(points: PackedVector2Array) -> float:
	var total:=0.0
	for i in range(points.size()-1): total+=points[i].distance_to(points[i+1])
	return total

static func position(points: PackedVector2Array, distance_value: float) -> Vector2:
	if points.is_empty(): return Vector2.ZERO
	var remaining:=maxf(0,distance_value)
	for i in range(points.size()-1):
		var segment:=points[i].distance_to(points[i+1])
		if remaining<=segment and segment>0.00001: return points[i].lerp(points[i+1],remaining/segment)
		remaining-=segment
	return points[-1]

static func nearest_progress(points: PackedVector2Array, point: Vector2) -> float:
	var best:=INF
	var progress:=0.0
	var distance_so_far:=0.0
	for i in range(points.size()-1):
		var nearest:=Geometry2D.get_closest_point_to_segment(point,points[i],points[i+1])
		var distance_value:=point.distance_to(nearest)
		if distance_value<best:
			best=distance_value
			progress=distance_so_far+points[i].distance_to(nearest)
		distance_so_far+=points[i].distance_to(points[i+1])
	return progress

func route(network, origin: int, destination: int) -> PackedVector2Array:
	if revision!=network.graph_revision: rebuild(network)
	var key:="%d:%d" % [origin,destination]
	if cache.has(key): return cache[key]
	var empty:=PackedVector2Array()
	if origin<1 or destination<1 or origin>network.housing.lots.size() or destination>network.housing.lots.size(): return empty
	var home: Dictionary=network.housing.lots[origin-1]
	var target: Dictionary=network.housing.lots[destination-1]
	if origin==destination: return PackedVector2Array([gate(home)])
	var start:=_anchor(network,home)
	var finish:=_anchor(network,target)
	if start.is_empty() or finish.is_empty(): return empty
	var distances: Array[float]=[]
	var previous: Array[int]=[]
	var paths: Array[PackedVector2Array]=[]
	var visited: Array[bool]=[]
	for point in vertices:
		distances.append(INF)
		previous.append(-1)
		paths.append(PackedVector2Array())
		visited.append(false)
	for node in [start.a,start.b]: distances[node]=start.point.distance_to(vertices[node])
	for iteration in range(vertices.size()):
		var current:=-1
		var minimum:=INF
		for i in range(distances.size()):
			if not visited[i] and distances[i]<minimum:
				minimum=distances[i]
				current=i
		if current<0: break
		visited[current]=true
		for edge in adjacency[current]:
			var cost: float=minimum+edge.cost
			if cost<distances[edge.node]:
				distances[edge.node]=cost
				previous[edge.node]=current
				paths[edge.node]=edge.points
	var end_node: int=finish.a
	if distances[finish.b]+vertices[finish.b].distance_to(finish.point)<distances[end_node]+vertices[end_node].distance_to(finish.point): end_node=finish.b
	var middle:=PackedVector2Array([start.point])
	if start.edge==finish.edge and start.left==finish.left:
		middle.append(finish.point)
	else:
		if is_inf(distances[end_node]): return empty
		var chain: Array[int]=[]
		var current:=end_node
		while current>=0:
			chain.append(current)
			current=previous[current]
		chain.reverse()
		middle.append(vertices[chain[0]])
		for i in range(1,chain.size()): middle.append_array(paths[chain[i]])
		middle.append(finish.point)
	var raw:=PackedVector2Array([gate(home)])
	raw.append_array(middle)
	raw.append(gate(target))
	var cleaned:=PackedVector2Array()
	for point in raw:
		if not cleaned.is_empty() and point.distance_to(cleaned[-1])<0.001: continue
		if cleaned.size()>=2:
			var a:=cleaned[-1]-cleaned[-2]
			var b:=point-cleaned[-1]
			if a.normalized().dot(b.normalized())>0.999999: cleaned.remove_at(cleaned.size()-1)
		cleaned.append(point)
	cache[key]=cleaned
	return cleaned
