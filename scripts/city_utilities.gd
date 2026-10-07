extends RefCounted
## Serviços por rede; recursos hídricos são compartilhados fisicamente entre redes.
const Catalog=preload("res://scripts/city_catalog.gd")
const Resources=preload("res://scripts/water_resources.gd")
const KINDS:=["water","power","sewage"]
const CAPACITY := {"water":60,"power":80,"sewage":60}
static func is_service(zone:String)->bool: return zone in KINDS
static func load_for(lot:Dictionary,kind:String)->int:
	if is_service(lot.zone): return 0
	if lot.zone=="residential": return int(lot.capacity)
	var jobs:=maxi(1,int(lot.width*lot.depth/(22.0 if lot.zone=="industrial" else 30.0)))
	if lot.zone=="commercial": return jobs*2 if kind=="power" else jobs+1
	return jobs*3 if kind=="power" else jobs*2
static func empty_budget()->Dictionary:
	return {"water":0,"power":0,"sewage":0,"water_used":0,"power_used":0,"sewage_used":0,"legacy":0,"sewage_legacy":0}
static func component(lot:Dictionary,supply:Dictionary)->int:
	if lot.road<0: return -1
	return int(supply.get("road_components",{}).get(lot.road,0))
static func local_budget(lot:Dictionary,supply:Dictionary)->Dictionary:
	return supply.get("networks",{}).get(component(lot,supply),empty_budget()) if supply.has("networks") else supply
static func legacy(lot:Dictionary,supply:Dictionary)->bool:
	return lot.get("utility_exempt",false) and component(lot,supply)==0
static func sewer_legacy(lot:Dictionary,supply:Dictionary)->bool:
	return lot.get("sewer_exempt",false) and component(lot,supply)==0
static func exempt(lot:Dictionary,supply:Dictionary,kind:String)->bool:
	return sewer_legacy(lot,supply) if kind=="sewage" else legacy(lot,supply)
static func budget(housing)->Dictionary:
	var out:=empty_budget()
	out["networks"]={}
	out["states"]={}
	out["road_components"]=housing.road_components
	out["disconnected"]=0
	out["resources"]=Resources.production(housing.lots)
	out["sewage_generated"]=0
	out["sewage_treated"]=0
	out["sewage_untreated"]=0
	out["sewage_external"]=0
	out["alerts"]=0
	for lot in housing.lots:
		var group:=component(lot,out)
		if not out.networks.has(group): out.networks[group]=empty_budget()
		var net:Dictionary=out.networks[group]
		if is_service(lot.zone):
			if lot.stage==2 and group>=0:
				var amount:int=out.resources.sources[int(lot.id)].amount if lot.zone=="water" else Catalog.for_lot(lot).capacity
				net[lot.zone]+=amount
				out[lot.zone]+=amount
		else:
			if legacy(lot,out):
				net.legacy+=1
				out.legacy+=1
			if sewer_legacy(lot,out):
				net.sewage_legacy+=1
				out.sewage_legacy+=1
		if group!=0: out.disconnected+=1
	# Reservas incluem obras admitidas; prioridade estável pela ordem dos lotes.
	for lot in housing.lots:
		if is_service(lot.zone): continue
		var net:Dictionary=local_budget(lot,out)
		var served:Dictionary={}
		for kind in KINDS:
			if exempt(lot,out,kind): served[kind]=true
			elif not lot.get("demand_pending",false):
				served[kind]=lot.road>=0 and net[kind]-net[kind+"_used"]>=load_for(lot,kind)
				net[kind+"_used"]+=load_for(lot,kind)
				out[kind+"_used"]+=load_for(lot,kind)
		if not served.is_empty(): out.states[int(lot.id)]=served
		if lot.stage==2 and served.get("water",false):
			var generated:=load_for(lot,"sewage")
			out.sewage_generated+=generated
			if sewer_legacy(lot,out): out.sewage_external+=generated
			elif served.get("sewage",false): out.sewage_treated+=generated
			else: out.sewage_untreated+=generated
	for lot in housing.lots:
		if not operational(lot,out) and (lot.stage==2 or not is_service(lot.zone)): out.alerts+=1
	return out
static func can_start(lot:Dictionary,supply:Dictionary)->bool:
	if lot.road<0: return false
	if is_service(lot.zone): return true
	if component(lot,supply)!=0: return false
	var net:=local_budget(lot,supply)
	for kind in KINDS:
		if not exempt(lot,supply,kind) and net[kind]-net[kind+"_used"]<load_for(lot,kind): return false
	return true
static func reserve(lot:Dictionary,supply:Dictionary)->void:
	if is_service(lot.zone): return
	var net:=local_budget(lot,supply)
	for kind in KINDS:
		if exempt(lot,supply,kind): continue
		net[kind+"_used"]+=load_for(lot,kind)
		if supply.has("networks"): supply[kind+"_used"]+=load_for(lot,kind)
	if supply.has("states"): supply.states[int(lot.id)]={"water":true,"power":true,"sewage":true}
static func state(lot:Dictionary,supply:Dictionary)->Dictionary:
	var group:=component(lot,supply)
	var result:Dictionary={"water":false,"power":false,"sewage":false,"legacy":legacy(lot,supply),"sewer_legacy":sewer_legacy(lot,supply),"component":group,"operational":false,"text":""}
	if lot.road<0:
		result.text="Sem acesso à rua. Reconecte a frente do lote."
		return result
	if is_service(lot.zone):
		var ready:bool=lot.stage==2
		var amount:int=Catalog.for_lot(lot).capacity if ready else 0
		if lot.zone=="water": amount=int(supply.get("resources",{}).get("sources",{}).get(int(lot.id),{}).get("amount",0))
		result.operational=ready and amount>0
		for kind in KINDS: result[kind]=result.operational
		result.text="Oferta %d / %d • %s" % [amount,Catalog.for_lot(lot).capacity,"em operação" if result.operational else ("em construção" if not ready else "sem vazão disponível")]
		if lot.zone=="water":
			var field:=Resources.field_at(Vector2(lot.x,lot.z))
			result.text+=". Captação legada preservada." if lot.get("source_legacy",false) else (". "+str(Resources.FIELDS[field].name)+"; vazão compartilhada." if field>=0 else ". Fora de aquífero.")
		elif lot.zone=="sewage": result.text+=". Coleta e tratamento pela rede; descarte por infiltração controlada."
	else:
		var net:=local_budget(lot,supply)
		var served:Dictionary=supply.get("states",{}).get(int(lot.id),{})
		var missing:Array[String]=[]
		for kind in KINDS:
			result[kind]=exempt(lot,supply,kind) or served.get(kind,net[kind]-net[kind+"_used"]>=load_for(lot,kind))
			if not result[kind]: missing.append({"water":"água","power":"energia","sewage":"coleta/tratamento de esgoto"}[kind])
		result.operational=missing.is_empty()
		result.text="Água, energia e esgoto disponíveis." if result.operational else "Falta "+", ".join(missing)+". Conecte ou amplie as instalações desta rede."
		if result.legacy: result.text+=" Água/energia legadas pela entrada."
		if result.sewer_legacy: result.text+=" Esgoto legado pela entrada."
	if group>0: result.text+=" Rede isolada da entrada."
	return result
static func apply(housing)->void:
	var supply:=budget(housing)
	for lot in housing.lots:
		lot["operational"]=operational(lot,supply)
		lot["external_access"]=component(lot,supply)==0

static func operational(lot:Dictionary,supply:Dictionary)->bool:
	if lot.road<0: return false
	if is_service(lot.zone):
		if lot.stage!=2: return false
		return lot.zone!="water" or int(supply.resources.sources[int(lot.id)].amount)>0
	var net:=local_budget(lot,supply)
	var served:Dictionary=supply.get("states",{}).get(int(lot.id),{})
	for kind in KINDS:
		if not exempt(lot,supply,kind) and not served.get(kind,net[kind]-net[kind+"_used"]>=load_for(lot,kind)): return false
	return true
