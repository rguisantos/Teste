extends RefCounted
## Contas em reais fictícios. Um dia econômico corresponde a 180 s ativos.
const DAY_SECONDS := 180.0
const Catalog=preload("res://scripts/city_catalog.gd")
var public_works_spent:=0
var last_maintenance:={"roads":0,"water":0,"power":0,"sewage":0,"unclassified":0}
var last_breakdown_known:=true
var elapsed := 0.0
var day := 0
var municipal_delta := 0
var exterior_balance := 0
var last := {"taxes": 0, "wages": 0, "sales": 0, "exports": 0, "imports": 0, "maintenance": 0, "net": 0}

var current := {"taxes":0,"wages":0,"sales":0,"exports":0,"imports":0,"maintenance":0,"net":0}

func fund_household(person: Dictionary) -> void:
	person["balance"] = 300
	person["job"] = 0
	exterior_balance -= 300

func fund_business(lot: Dictionary) -> void:
	lot["business"] = {"cash": 2000, "stock": 0}
	exterior_balance -= 2000

func hire(housing) -> void:
	var openings := {}
	for lot in housing.lots:
		if lot.stage==2 and lot.zone in ["commercial","industrial"]: openings[lot.id]=job_capacity(lot)
	# Mantém vínculos válidos para não trocar o destino de quem está a caminho.
	for person in housing.residents:
		if person.age<=65 and openings.get(person.job,0)>0:
			openings[person.job]-=1
		else: person.job=0
	for person in housing.residents:
		if person.job>0 or person.age>65: continue
		for lot_id in openings:
			if openings[lot_id]>0:
				person.job=lot_id
				openings[lot_id]-=1
				break

static func job_capacity(lot: Dictionary) -> int:
	return maxi(1, int(lot.width * lot.depth / (22.0 if lot.zone == "industrial" else 30.0)))

func workers(housing, lot_id: int) -> int:
	var count := 0
	for person in housing.residents:
		if person.job == lot_id:
			count += 1
	return count

func employment_count(housing) -> int:
	var count := 0
	for person in housing.residents:
		if person.job > 0:
			count += 1
	return count

func _tax(amount: int) -> void:
	municipal_delta+=amount
	current.taxes+=amount
	current.net+=amount

func work_visit(person: Dictionary, employer: Dictionary) -> void:
	if not employer.get("operational",true) or employer.stage!=2 or employer.zone not in ["commercial","industrial"] or person.job!=employer.id: return
	if employer.zone=="industrial" and employer.get("external_access",true):
		employer.business.cash+=180
		exterior_balance-=180
		current.exports+=180
		employer.business.cash-=18
		_tax(18)
	elif employer.zone=="commercial" and employer.get("external_access",true):
		var units:=mini(maxi(0,32-int(employer.business.stock)),mini(8,int(employer.business.cash/5)))
		employer.business.stock+=units
		employer.business.cash-=units*5
		exterior_balance+=units*5
		current.imports+=units*5
	var amount:=mini(100 if employer.zone=="industrial" else 35,int(employer.business.cash))
	employer.business.cash-=amount
	person.balance+=amount
	current.wages+=amount

func purchase(person: Dictionary, shop: Dictionary) -> bool:
	if not shop.get("operational",true) or shop.zone!="commercial" or shop.stage!=2 or shop.business.stock<1 or person.balance<20: return false
	person.balance-=20
	shop.business.stock-=1
	shop.business.cash+=18
	current.sales+=20
	_tax(2)
	return true

func advance(delta: float, _housing, road_length: float) -> int:
	elapsed+=maxf(0.0,delta)
	var total:=0
	while elapsed>=DAY_SECONDS-0.00000001:
		elapsed=maxf(0.0,elapsed-DAY_SECONDS)
		day+=1
		last_maintenance=maintenance_breakdown(_housing,road_length)
		last_breakdown_known=true
		var maintenance:=breakdown_total(last_maintenance)
		exterior_balance+=maintenance
		municipal_delta-=maintenance
		current.maintenance=maintenance
		current.net-=maintenance
		total-=maintenance
		last=current.duplicate(true)
		current={"taxes":0,"wages":0,"sales":0,"exports":0,"imports":0,"maintenance":0,"net":0}
	return total

func account_total(housing) -> int:
	var total := exterior_balance + municipal_delta
	for person in housing.residents:
		total += int(person.balance)
	for lot in housing.lots:
		if lot.has("business"):
			total += int(lot.business.cash)
	return total

func serialize() -> Dictionary:
	return {"budget_version":1,"last_maintenance":last_maintenance.duplicate(true),"last_breakdown_known":last_breakdown_known,"public_works_spent":public_works_spent,"day_seconds":DAY_SECONDS,"elapsed": elapsed, "day": day, "municipal_delta": municipal_delta, "exterior_balance": exterior_balance, "last": last.duplicate(true), "current": current.duplicate(true)}

static func restore(data: Dictionary):
	var result = load("res://scripts/economy.gd").new()
	for key in ["elapsed", "day", "municipal_delta", "exterior_balance"]:
		if not (data.get(key) is int or data.get(key) is float) or not is_finite(float(data[key])):
			return null
	var duration=data.get("day_seconds",30.0)
	if not (duration is int or duration is float) or not is_finite(float(duration)): return null
	var previous_duration: float=float(duration)
	if previous_duration not in [30.0,DAY_SECONDS]: return null
	if data.elapsed < 0 or data.elapsed >= previous_duration or data.day < 0 or data.day != int(data.day):
		return null
	if not data.get("last") is Dictionary:
		return null
	for key in result.last:
		if not (data.last.get(key) is float or data.last.get(key) is int) or data.last[key] != int(data.last[key]):
			return null
		result.last[key] = int(data.last[key])
	if data.has("current"):
		if not data.current is Dictionary: return null
		for key in result.current:
			if not (data.current.get(key) is float or data.current.get(key) is int) or not is_finite(float(data.current[key])) or data.current[key]!=int(data.current[key]): return null
			result.current[key]=int(data.current[key])
	var spent=data.get("public_works_spent",0)
	if not (spent is int or spent is float) or not is_finite(float(spent)) or spent<0 or spent!=int(spent): return null
	result.public_works_spent=int(spent)
	if data.has("budget_version"):
		var version=data.budget_version
		if not (version is int or version is float) or not is_finite(float(version)) or version!=1: return null
		if not data.get("last_maintenance") is Dictionary or not data.get("last_breakdown_known") is bool: return null
		for key in result.last_maintenance:
			var amount=data.last_maintenance.get(key)
			if not (amount is int or amount is float) or not is_finite(float(amount)) or amount<0 or amount!=int(amount): return null
			result.last_maintenance[key]=int(amount)
		if breakdown_total(result.last_maintenance)!=int(result.last.maintenance): return null
		result.last_breakdown_known=data.last_breakdown_known
		if result.last_breakdown_known and result.last_maintenance.unclassified!=0: return null
		if not result.last_breakdown_known and result.last_maintenance.unclassified!=result.last.maintenance: return null
	else:
		result.last_breakdown_known=false
		result.last_maintenance.unclassified=int(result.last.maintenance)
	result.elapsed = float(data.elapsed)*DAY_SECONDS/previous_duration
	result.day = int(data.day)
	result.municipal_delta = int(data.municipal_delta)
	result.exterior_balance = int(data.exterior_balance)
	return result

static func maintenance_breakdown(housing,road_length:float,include_pending:bool=false)->Dictionary:
	var out:={"roads":int(ceil(road_length*0.05)),"water":0,"power":0,"sewage":0,"unclassified":0}
	for lot in housing.lots:
		var item:=Catalog.for_lot(lot)
		if not item.is_empty() and (include_pending or lot.stage==2): out[lot.zone]+=int(item.maintenance)
	return out
static func breakdown_total(values:Dictionary)->int:
	var total:=0
	for amount in values.values(): total+=int(amount)
	return total
