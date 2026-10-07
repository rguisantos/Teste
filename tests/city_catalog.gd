extends SceneTree
const Network=preload("res://scripts/streets_model.gd")
const Catalog=preload("res://scripts/city_catalog.gd")
func _initialize()->void:
 for kind in ["water","power","sewage"]:
  for tier in ["small","medium","large"]:
   var model=Network.new()
   assert(model.commit(Vector2(-80,0),Vector2(70,0)))
   var spec:=Catalog.spec(kind,kind+"_"+tier)
   var lot:Dictionary=model.housing.candidate(Vector2(-20,4.6+spec.depth/2.0),model.roads,func(_x,_z):return 0.0,kind,"auto",kind+"_"+tier)
   assert(not lot.is_empty() and lot.width==spec.width and lot.depth==spec.depth)
   var cash:int=model.cash
   var quote:Dictionary=model.budget_forecast(lot)
   assert(quote.price==spec.price and quote.cash_after==cash-spec.price and quote.candidate==spec.maintenance)
   assert(quote.net==-8-spec.maintenance)
   assert(Catalog.upkeep(model.housing)==0)
   assert(model.place_lot(lot).ok)
   assert(model.cash==cash-spec.price and model.housing.economy.account_total(model.housing)==0)
   assert(not model.place_lot(lot).ok and model.cash==cash-spec.price,"Não cobra duas vezes")
   assert(Catalog.upkeep(model.housing)==0 and Catalog.upkeep(model.housing,true)==spec.maintenance)
   model.simulate(24.1)
   assert(Catalog.upkeep(model.housing)==spec.maintenance)
   assert(preload("res://scripts/city_utilities.gd").budget(model.housing)[kind]==spec.capacity)
   var restored=Network.restore(JSON.parse_string(JSON.stringify(model.serialize())))
   assert(restored!=null and restored.cash==model.cash)
   model.simulate(156.0)
   assert(model.housing.economy.last.maintenance==8+spec.maintenance)
   assert(model.cash==cash-spec.price-8-spec.maintenance and model.housing.economy.account_total(model.housing)==0)
   var before:int=model.cash
   assert(model.demolish_lot(1).ok)
   assert(model.cash==before and Catalog.upkeep(model.housing)==0,"Demolição sem reembolso, interrompe manutenção")
   model.cash=0
   lot=model.housing.candidate(Vector2(-20,9),model.roads,func(_x,_z):return 0.0,kind,"auto",kind+"_"+tier)
   assert(not model.place_lot(lot).ok and model.cash==0 and model.housing.lots.is_empty())
 var cancel_model=Network.new()
 assert(cancel_model.commit(Vector2(-80,0),Vector2(70,0)))
 var pending:Dictionary=cancel_model.housing.candidate(Vector2(-20,9),cancel_model.roads,func(_x,_z):return 0.0,"water","auto","water_small")
 assert(cancel_model.place_lot(pending).ok)
 var paid_cash:int=cancel_model.cash
 assert(cancel_model.cancel_unfinished_lot(1).ok)
 assert(cancel_model.cash==paid_cash and Catalog.upkeep(cancel_model.housing,true)==0)
 assert(Network.restore(JSON.parse_string(JSON.stringify(cancel_model.serialize())))!=null)
 var legacy:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/city-0.0.14.json"))
 var migrated=Network.restore(legacy)
 assert(migrated!=null and migrated.cash==legacy.cash and migrated.housing.economy.public_works_spent==0)
 for lot in migrated.housing.lots:
  if lot.zone in ["water","power"]: assert(lot.catalog_id==lot.zone+"_medium" and lot.build_paid==0)
 var bad:Dictionary=migrated.serialize()
 for lot in bad.residential.lots:
  if lot.zone in ["water","power"]:
   lot.catalog_id="unknown"
   break
 assert(Network.restore(bad)==null)
 print("CITY_CATALOG_OK: nove instalações, área, preço, manutenção, previsão, caixa, save e demolição")
 quit()
