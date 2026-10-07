extends RefCounted
## União exata em faixas: uma superfície, sem sobreposições ou preenchimento de quadras.
const WIDTH := 7.0

static func polygons(roads: Array[Dictionary], width: float = WIDTH) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for road in roads:
		var points: PackedVector2Array = road.points
		result.append_array(Geometry2D.offset_polyline(points, width / 2.0, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND))
	return result

static func _x(edge: Dictionary, y: float) -> float:
	return lerpf(edge.a.x, edge.b.x, (y - edge.a.y) / (edge.b.y - edge.a.y))

static func triangles(contours: Array[PackedVector2Array]) -> PackedVector2Array:
	var edges: Array[Dictionary] = []
	var levels: Array[float] = []
	for polygon in contours:
		for i in range(polygon.size()):
			var a := polygon[i]
			var b := polygon[(i + 1) % polygon.size()]
			levels.append(a.y)
			if absf(a.y - b.y) > 0.00001:
				edges.append({"a": a, "b": b, "polygon": contours.find(polygon), "low": minf(a.y, b.y), "high": maxf(a.y, b.y)})
	# Divide as faixas também onde as bordas das ruas se cruzam.
	for i in range(edges.size()):
		for j in range(i + 1, edges.size()):
			if edges[i].polygon == edges[j].polygon or edges[i].low > edges[j].high or edges[j].low > edges[i].high:
				continue
			var hit = Geometry2D.segment_intersects_segment(edges[i].a, edges[i].b, edges[j].a, edges[j].b)
			if hit != null:
				levels.append(hit.y)
	levels.sort()
	var rows: Array[float] = []
	for y in levels:
		if rows.is_empty():
			rows.append(y)
		elif y - rows.back() > 0.00001:
			var previous: float = rows.back()
			var count := maxi(1, int(ceil((y - previous) / 2.0)))
			for i in range(1, count + 1):
				rows.append(lerpf(previous, y, float(i) / count))
	var output := PackedVector2Array()
	for row in range(rows.size() - 1):
		var low := rows[row]
		var high := rows[row + 1]
		var middle := (low + high) / 2.0
		var crossings: Dictionary = {}
		for edge in edges:
			if edge.low < middle and edge.high > middle:
				if not crossings.has(edge.polygon):
					crossings[edge.polygon] = []
				crossings[edge.polygon].append({"x": _x(edge, middle), "edge": edge})
		var intervals: Array[Dictionary] = []
		for values in crossings.values():
			values.sort_custom(func(a, b): return a.x < b.x)
			for i in range(0, values.size() - 1, 2):
				intervals.append({"left": values[i], "right": values[i + 1]})
		intervals.sort_custom(func(a, b): return a.left.x < b.left.x)
		var merged: Array[Dictionary] = []
		for interval in intervals:
			if merged.is_empty() or interval.left.x > merged.back().right.x + 0.00001:
				merged.append(interval)
			elif interval.right.x > merged.back().right.x:
				merged.back().right = interval.right
		for interval in merged:
			var a := Vector2(_x(interval.left.edge, low), low)
			var b := Vector2(_x(interval.right.edge, low), low)
			var c := Vector2(_x(interval.left.edge, high), high)
			var d := Vector2(_x(interval.right.edge, high), high)
			var count := maxi(1, int(ceil(maxf(a.distance_to(b), c.distance_to(d)) / 2.0)))
			for i in range(count):
				var t := float(i) / count
				var u := float(i + 1) / count
				for triangle in [[a.lerp(b, t), c.lerp(d, t), a.lerp(b, u)], [a.lerp(b, u), c.lerp(d, t), c.lerp(d, u)]]:
					if absf((triangle[1] - triangle[0]).cross(triangle[2] - triangle[0])) > 0.000001:
						output.append_array(PackedVector2Array([triangle[0], triangle[2], triangle[1]]))
	return output
