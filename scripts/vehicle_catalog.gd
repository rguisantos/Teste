extends RefCounted
const TYPES := ["hatch","sedan","motorcycle","light_truck","heavy_truck"]
const SPECS := {
	"hatch":{"name":"Carro compacto","length":3.6,"width":1.65,"speed":8.0,"accel":2.1,"zones":["residential","commercial","industrial"]},
	"sedan":{"name":"Sedã","length":4.4,"width":1.75,"speed":8.0,"accel":1.9,"zones":["residential","commercial","industrial"]},
	"motorcycle":{"name":"Moto","length":2.0,"width":0.75,"speed":8.5,"accel":2.5,"zones":["residential","commercial","industrial"]},
	"light_truck":{"name":"Caminhão leve","length":5.2,"width":1.95,"speed":6.8,"accel":1.4,"zones":["commercial","industrial"]},
	"heavy_truck":{"name":"Caminhão grande","length":7.8,"width":2.25,"speed":5.8,"accel":1.0,"zones":["industrial"]}
}
static func spec(kind:String)->Dictionary:return SPECS.get(kind,{})
