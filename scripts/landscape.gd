extends Node3D
## Terreno vazio reproduzível. Os modelos são provisórios para medição técnica.

const SIZE := 192.0
const SEGMENTS := 80
const TREE_COUNT := 180

var seed_value: int = 1042026
var terrain_noise := FastNoiseLite.new()
var color_noise := FastNoiseLite.new()
var generated_root: Node3D
var road_clearings: Array[Dictionary] = []
var residential_lots: Array[Dictionary] = []
var lot_signature := ""
var tree_root: Node3D
var ground_node: MeshInstance3D
var grade = preload("res://scripts/road_grade.gd").new()


func generate(value: int) -> void:
	seed_value = value
	road_clearings.clear()
	residential_lots.clear()
	lot_signature = ""
	terrain_noise.seed = value
	terrain_noise.frequency = 0.017
	color_noise.seed = value + 137
	color_noise.frequency = 0.05
	if is_instance_valid(generated_root):
		remove_child(generated_root)
		generated_root.queue_free()
	generated_root = Node3D.new()
	add_child(generated_root)
	grade.build([], natural_height_at)
	_create_ground()
	_create_trees()
	_create_entrance()


func height_at(x: float, z: float) -> float:
	var point := Vector2(x,z)
	var ground: float = grade.ground_height(point,natural_height_at(x,z))
	var strongest := 0.0
	var target := ground
	for lot in residential_lots:
		var dx: float = x-lot.x
		var dz: float = z-lot.z
		var local := Vector2(dx*cos(lot.angle)+dz*sin(lot.angle),-dx*sin(lot.angle)+dz*cos(lot.angle))
		var outside: float = maxf(absf(local.x)-lot.width/2,absf(local.y)-lot.depth/2)
		if outside >= 1.5:
			continue
		var weight := 1.0-smoothstep(0.0,1.5,maxf(0.0,outside))
		if weight>strongest:
			strongest = weight
			target = float(lot.height)-0.06
	if strongest>0:
		var road_sample: Dictionary = grade.sample(point)
		strongest *= smoothstep(4.25,4.6,float(road_sample.distance))
	return lerpf(ground,target,strongest)


func road_height_at(x: float, z: float) -> float:
	return grade.road_height(Vector2(x, z), natural_height_at(x, z))


func natural_height_at(x: float, z: float) -> float:
	# Fundação inicial quase plana; relevo suave cresce em direção às bordas.
	var blend := smoothstep(24.0, 70.0, Vector2(x, z).length())
	return 0.5 + terrain_noise.get_noise_2d(x, z) * 3.5 * blend


func _point(x: int, z: int) -> Vector3:
	var px := float(x) / SEGMENTS * SIZE - SIZE * 0.5
	var pz := float(z) / SEGMENTS * SIZE - SIZE * 0.5
	return Vector3(px, height_at(px, pz), pz)


func _create_ground() -> void:
	if is_instance_valid(ground_node):
		ground_node.get_parent().remove_child(ground_node)
		ground_node.queue_free()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array[Vector3] = []
	for z in range(SEGMENTS + 1):
		for x in range(SEGMENTS + 1):
			grid.append(_point(x, z))
	for z in range(SEGMENTS):
		for x in range(SEGMENTS):
			var i := z * (SEGMENTS + 1) + x
			var a := grid[i]
			var b := grid[i + 1]
			var c := grid[i + SEGMENTS + 1]
			var d := grid[i + SEGMENTS + 2]
			for point in [a, b, c, b, d, c]:
				var tone := clampf(color_noise.get_noise_2d(point.x, point.z) + 0.5, 0, 1)
				surface.set_color(Color(0.20, 0.30, 0.13).lerp(Color(0.43, 0.48, 0.25), tone))
				surface.add_vertex(point)
	surface.generate_normals()
	surface.index()
	var ground := MeshInstance3D.new()
	ground.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	ground.material_override = material
	generated_root.add_child(ground)
	generated_root.move_child(ground, 0)
	ground_node = ground


func _create_trees() -> void:
	if is_instance_valid(tree_root):
		if tree_root.get_parent() == generated_root:
			generated_root.remove_child(tree_root)
			tree_root.queue_free()
	tree_root = Node3D.new()
	generated_root.add_child(tree_root)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var positions: Array[Vector3] = []
	while positions.size() < TREE_COUNT:
		var x := rng.randf_range(-92, 92)
		var z := rng.randf_range(-92, 92)
		if absf(x) < 31 and absf(z) < 31:
			continue
		if x < -78 and absf(z) < 8:
			continue
		positions.append(Vector3(x, height_at(x, z), z))
	var remaining: Array[Vector3] = []
	for point in positions:
		var clear := false
		for road in road_clearings:
			var path_points: PackedVector2Array = road.points
			for i in range(path_points.size() - 1):
				var nearest := Geometry2D.get_closest_point_to_segment(Vector2(point.x, point.z), path_points[i], path_points[i + 1])
				if nearest.distance_to(Vector2(point.x, point.z)) < 5.5:
					clear = true
		for lot in residential_lots:
			if Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), preload("res://scripts/residential.gd").polygon(lot, 2.0)):
				clear = true
		if not clear:
			remaining.append(point)
	positions = remaining
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.13
	trunk.bottom_radius = 0.22
	trunk.height = 3.8
	trunk.radial_segments = 6
	var crown := CylinderMesh.new()
	crown.top_radius = 0.25
	crown.bottom_radius = 1.9
	crown.height = 4.6
	crown.radial_segments = 8
	_instances(trunk, positions, 1.9, Color(0.24, 0.17, 0.10))
	_instances(crown, positions, 4.6, Color(0.16, 0.29, 0.12))


func _instances(mesh: Mesh, positions: Array[Vector3], elevation: float, color: Color) -> void:
	var batches := MultiMesh.new()
	batches.transform_format = MultiMesh.TRANSFORM_3D
	batches.mesh = mesh
	batches.instance_count = positions.size()
	for index in range(positions.size()):
		var transform_value := Transform3D.IDENTITY
		transform_value.origin = positions[index] + Vector3.UP * elevation
		batches.set_instance_transform(index, transform_value)
	var node := MultiMeshInstance3D.new()
	node.multimesh = batches
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	node.material_override = material
	tree_root.add_child(node)


func clear_roads(roads: Array[Dictionary]) -> void:
	road_clearings = roads.duplicate()
	grade.build(roads, natural_height_at)
	_create_ground()
	_create_trees()


func _create_entrance() -> void:
	# Uma conexão externa curta; a cidade propriamente dita começa vazia.
	var mesh := BoxMesh.new()
	mesh.size = Vector3(16, 0.12, 7)
	var road := MeshInstance3D.new()
	road.mesh = mesh
	road.position = Vector3(-88, road_height_at(-88, 0) + 0.09, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.46, 0.30, 0.18)
	material.roughness = 1.0
	road.material_override = material
	generated_root.add_child(road)

func set_lots(lots: Array[Dictionary]) -> void:
	var signature: Array = []
	for lot in lots:
		signature.append([lot.x,lot.z,lot.height,lot.width,lot.depth,lot.angle])
	var current := JSON.stringify(signature)
	if current==lot_signature:
		return
	lot_signature = current
	residential_lots = lots.duplicate(true)
	_create_ground()
	_create_trees()
