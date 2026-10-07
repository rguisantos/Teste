extends RefCounted
## Perfil longitudinal compartilhado pelas ruas e pela terraplenagem.
const CELL := 12.0
const MAX_SLOPE := 0.08
const HALF_DECK := 4.25
const SHOULDER_END := 10.0
var segments: Array[Dictionary] = []
var junctions: Array[Dictionary] = []
var buckets: Dictionary = {}
var junction_buckets: Dictionary = {}
var heights: Array[float] = []
var positions: Array[Vector2] = []

func _cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.y / CELL))

func build(roads: Array[Dictionary], natural: Callable) -> void:
	segments.clear()
	junctions.clear()
	buckets.clear()
	junction_buckets.clear()
	positions.clear()
	heights.clear()
	var graph = preload("res://scripts/streets_model.gd").new()
	graph.roads = roads.duplicate()
	graph.rebuild_graph()
	positions.assign(graph.nodes)
	var links: Array[Dictionary] = []
	var neighbors: Array[Array] = []
	for p in positions:
		heights.append(natural.call(p.x, p.y))
		neighbors.append([])
	for edge in graph.edges:
		var from_index: int = edge.from
		var to_index: int = edge.to
		var a := positions[from_index]
		var b := positions[to_index]
		var count := maxi(1, ceili(a.distance_to(b) / 4.0))
		var previous := from_index
		for step in range(1, count + 1):
			var current := to_index
			if step != count:
				current = positions.size()
				var point := a.lerp(b, float(step) / count)
				positions.append(point)
				heights.append(natural.call(point.x, point.y))
				neighbors.append([])
			var length := positions[previous].distance_to(positions[current])
			links.append({"from": previous, "to": current, "length": length})
			neighbors[previous].append({"node": current, "weight": 1.0 / maxf(length, 0.1)})
			neighbors[current].append({"node": previous, "weight": 1.0 / maxf(length, 0.1)})
			previous = current
	var entry_height: float = natural.call(-80.0, 0.0)
	# Suavização em toda a rede; todas as junções usam o mesmo vértice.
	for iteration in range(40):
		var next: Array[float] = heights.duplicate()
		for i in range(1, positions.size()):
			var total := 0.0
			var weight := 0.0
			for neighbor in neighbors[i]:
				total += heights[neighbor.node] * neighbor.weight
				weight += neighbor.weight
			if weight > 0:
				next[i] = lerpf(heights[i], total / weight, 0.5)
		heights = next
		heights[0] = entry_height
	for iteration in range(80):
		for link in links:
			var a: int = link.from
			var b: int = link.to
			var excess: float = absf(heights[b] - heights[a]) - link.length * MAX_SLOPE
			if excess > 0:
				var direction := signf(heights[b] - heights[a])
				if a == 0:
					heights[b] -= direction * excess
				elif b == 0:
					heights[a] += direction * excess
				else:
					heights[a] += direction * excess * 0.5
					heights[b] -= direction * excess * 0.5
	for link in links:
		_add_segment(positions[link.from], positions[link.to], heights[link.from], heights[link.to])
	# Entrada externa fixa e ligada ao mesmo perfil.
	_add_segment(Vector2(-96, 0), Vector2(-80, 0), entry_height, entry_height)
	for i in range(graph.nodes.size()):
		var arms: Array[Vector2] = []
		for edge in graph.edges:
			if edge.from == i:
				arms.append((graph.nodes[edge.to] - graph.nodes[i]).normalized())
			elif edge.to == i:
				arms.append((graph.nodes[edge.from] - graph.nodes[i]).normalized())
		if arms.size() >= 3 or (arms.size() == 2 and arms[0].dot(arms[1]) > -0.85) or i == 0:
			var index := junctions.size()
			junctions.append({"point": positions[i], "height": heights[i]})
			_insert(junction_buckets, index, positions[i] - Vector2.ONE * 8, positions[i] + Vector2.ONE * 8)

func _insert(index: Dictionary, value: int, low: Vector2, high: Vector2) -> void:
	var a := _cell(low)
	var b := _cell(high)
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			var key := Vector2i(x, y)
			if not index.has(key):
				index[key] = []
			index[key].append(value)

func _add_segment(a: Vector2, b: Vector2, ha: float, hb: float) -> void:
	var index := segments.size()
	segments.append({"a": a, "b": b, "ha": ha, "hb": hb})
	_insert(buckets, index, a.min(b) - Vector2.ONE * SHOULDER_END, a.max(b) + Vector2.ONE * SHOULDER_END)

func sample(point: Vector2) -> Dictionary:
	var closest := INF
	var elevation := 0.0
	for i in buckets.get(_cell(point), []):
		var segment: Dictionary = segments[i]
		var nearest := Geometry2D.get_closest_point_to_segment(point, segment.a, segment.b)
		var distance := point.distance_to(nearest)
		if distance < closest:
			closest = distance
			var length: float = segment.a.distance_to(segment.b)
			elevation = lerpf(segment.ha, segment.hb, segment.a.distance_to(nearest) / length)
	var pad_distance := INF
	var pad: Dictionary = {}
	for i in junction_buckets.get(_cell(point), []):
		var candidate: Dictionary = junctions[i]
		var distance := point.distance_to(candidate.point)
		if distance < pad_distance:
			pad_distance = distance
			pad = candidate
	if pad_distance < 8.0:
		elevation = lerpf(pad.height, elevation, smoothstep(4.0, 8.0, pad_distance))
	return {"distance": closest, "height": elevation}

func road_height(point: Vector2, fallback: float) -> float:
	var value := sample(point)
	return fallback if is_inf(value.distance) else value.height

func ground_height(point: Vector2, natural: float) -> float:
	var value := sample(point)
	if value.distance >= SHOULDER_END:
		return natural
	return lerpf(value.height, natural, smoothstep(HALF_DECK, SHOULDER_END, value.distance))
