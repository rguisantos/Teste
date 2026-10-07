extends RefCounted
## Parâmetros iniciais fictícios, sujeitos a balanceamento.
const ITEMS := {
 "water_small":{"name":"Poço compacto","size":"small","width":4,"depth":6,"capacity":30,"price":3000,"maintenance":20},
 "water_medium":{"name":"Poço com reservatório","size":"medium","width":6,"depth":8,"capacity":60,"price":6000,"maintenance":35},
 "water_large":{"name":"Central de captação","size":"large","width":10,"depth":12,"capacity":180,"price":15000,"maintenance":80},
 "power_small":{"name":"Unidade compacta","size":"small","width":4,"depth":6,"capacity":40,"price":4000,"maintenance":30},
 "power_medium":{"name":"Unidade de energia","size":"medium","width":6,"depth":8,"capacity":80,"price":8000,"maintenance":50},
 "sewage_small":{"name":"ETE compacta","size":"small","width":4,"depth":6,"capacity":30,"price":3500,"maintenance":25},
 "sewage_medium":{"name":"Estação de tratamento","size":"medium","width":6,"depth":8,"capacity":60,"price":7000,"maintenance":45},
 "sewage_large":{"name":"Central de tratamento","size":"large","width":10,"depth":12,"capacity":180,"price":17500,"maintenance":100},
 "power_large":{"name":"Central de energia","size":"large","width":10,"depth":12,"capacity":240,"price":20000,"maintenance":120}
}
static func spec(zone:String,id:String="")->Dictionary:
 if zone not in ["water","power","sewage"]: return {}
 if id=="": id=zone+"_medium"
 if not id.begins_with(zone+"_"): return {}
 return ITEMS.get(id,{})
static func for_lot(lot:Dictionary)->Dictionary:
 return spec(lot.zone,str(lot.get("catalog_id","")))
static func upkeep(housing,include_pending:bool=false)->int:
 var total:=0
 for lot in housing.lots:
  var item:=for_lot(lot)
  if not item.is_empty() and (include_pending or lot.stage==2): total+=int(item.maintenance)
 return total
