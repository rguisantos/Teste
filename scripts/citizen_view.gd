extends Node3D
## Todos os pedestres usam três lotes de desenho, sem um Node por cidadão.
var bodies: MultiMesh
var heads: MultiMesh
var legs: MultiMesh
var count := -1
var phase := 0.0

func _batch(mesh: Mesh, colors: bool) -> MultiMesh:
	var multi:=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_colors=colors
	multi.mesh=mesh
	var node:=MultiMeshInstance3D.new()
	node.multimesh=multi
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=colors
	material.albedo_color=Color.WHITE
	material.roughness=0.9
	node.material_override=material
	add_child(node)
	return multi

func _ready() -> void:
	var torso:=BoxMesh.new()
	torso.size=Vector3(0.48,0.65,0.28)
	bodies=_batch(torso,true)
	var head:=SphereMesh.new()
	head.radius=0.20
	head.height=0.4
	head.radial_segments=8
	head.rings=4
	heads=_batch(head,true)
	var leg:=BoxMesh.new()
	leg.size=Vector3(0.18,0.62,0.20)
	legs=_batch(leg,true)

func refresh(network, terrain, delta: float) -> void:
	phase+=delta*5.7
	var agents: Array=network.travel.agents
	if count!=agents.size():
		count=agents.size()
		bodies.instance_count=count
		heads.instance_count=count
		legs.instance_count=count*2
	for i in range(count):
		var agent: Dictionary=agents[i]
		if agent.phase!="walking":
			var hidden:=Transform3D(Basis.from_scale(Vector3.ZERO),Vector3(0,-100,0))
			bodies.set_instance_transform(i,hidden)
			heads.set_instance_transform(i,hidden)
			legs.set_instance_transform(i*2,hidden)
			legs.set_instance_transform(i*2+1,hidden)
			continue
		var p: Vector2=network.travel.position(agent,network.housing)
		var next: Vector2=network.travel.Routes.position(agent.points,minf(agent.length,agent.distance+0.15))
		var direction:=next-p
		var yaw: float=-direction.angle()+PI/2
		var basis:=Basis(Vector3.UP,yaw)
		var ground: float=terrain.height_at(p.x,p.y)+0.17
		var origin:=Vector3(p.x,ground,p.y)
		var bounce:=absf(sin(phase+i))*0.035
		bodies.set_instance_transform(i,Transform3D(basis,origin+Vector3.UP*(0.95+bounce)))
		heads.set_instance_transform(i,Transform3D(basis,origin+Vector3.UP*(1.50+bounce)))
		bodies.set_instance_color(i,[Color(0.85,0.2,0.12),Color(0.15,0.42,0.85),Color(0.95,0.76,0.17),Color(0.80,0.4,0.68)][i%4])
		heads.set_instance_color(i,[Color(0.68,0.43,0.28),Color(0.92,0.7,0.5),Color(0.38,0.23,0.15)][i%3])
		for side in [-1,1]:
			var leg_index:=i*2+(1 if side>0 else 0)
			var swing: float=sin(phase+i)*0.4*side
			legs.set_instance_transform(leg_index,Transform3D(basis*Basis(Vector3.RIGHT,swing),origin+basis*Vector3(side*0.13,0.32,0)))
			legs.set_instance_color(leg_index,Color(0.16,0.2,0.27))
