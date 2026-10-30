extends RefCounted
const SLOTS = ["hat","coat","boots"]
const SLOT_NAMES = {"hat":"Шапки","coat":"Куртки","boots":"Взуття"}
const ITEMS = [
 {"id":"hat_default","slot":"hat","name":"Шапка рибалки","cost":0,"color":"218caf","trim":"fff0ce","shape":0},
 {"id":"hat_berry","slot":"hat","name":"Ягідна шапка","cost":45,"color":"b94765","trim":"ffe1b4","shape":1},
 {"id":"hat_forest","slot":"hat","name":"Лісова вушанка","cost":110,"color":"458369","trim":"dfc598","shape":2},
 {"id":"hat_captain","slot":"hat","name":"Капітанська кепка","cost":250,"color":"263f68","trim":"efc86f","shape":3},
 {"id":"hat_sun","slot":"hat","name":"Сонячна шапка","cost":520,"color":"e0a12f","trim":"fff1bf","shape":1},
 {"id":"hat_explorer","slot":"hat","name":"Шапка мандрівника","cost":0,"color":"914f9c","trim":"f5d886","shape":2,"reward_zone":1},
 {"id":"coat_default","slot":"coat","name":"Куртка рибалки","cost":0,"color":"218caf","trim":"fff0ce","shape":0},
 {"id":"coat_red","slot":"coat","name":"Червона парка","cost":65,"color":"c84f4e","trim":"f4dbb3","shape":1},
 {"id":"coat_forest","slot":"coat","name":"Лісова куртка","cost":160,"color":"42755c","trim":"dec496","shape":2},
 {"id":"coat_captain","slot":"coat","name":"Морський бушлат","cost":360,"color":"30476e","trim":"efc86f","shape":3},
 {"id":"coat_ice","slot":"coat","name":"Полярна парка","cost":750,"color":"c1dbe2","trim":"579bad","shape":1},
 {"id":"coat_explorer","slot":"coat","name":"Парка мандрівника","cost":0,"color":"7751a0","trim":"f5d886","shape":3,"reward_zone":4},
 {"id":"boots_default","slot":"boots","name":"Черевики рибалки","cost":0,"color":"43505a","trim":"dfcba9","shape":0},
 {"id":"boots_trail","slot":"boots","name":"Похідні черевики","cost":35,"color":"a86b3f","trim":"efdbaf","shape":1},
 {"id":"boots_rain","slot":"boots","name":"Гумові чоботи","cost":90,"color":"dfac37","trim":"566b58","shape":2},
 {"id":"boots_snow","slot":"boots","name":"Зимові чоботи","cost":220,"color":"f0e8d4","trim":"6999ac","shape":2},
 {"id":"boots_navy","slot":"boots","name":"Морські черевики","cost":460,"color":"355a7b","trim":"f0c76d","shape":1},
 {"id":"boots_explorer","slot":"boots","name":"Чоботи мандрівника","cost":0,"color":"7751a0","trim":"f5d886","shape":2,"reward_zone":9}
]
static func initial() -> Dictionary:
 return {"owned":["hat_default","coat_default","boots_default"],"equipped":{"hat":"hat_default","coat":"coat_default","boots":"boots_default"}}
static func item(id: String) -> Dictionary:
 for entry in ITEMS:
  if entry.id==id:return entry
 return {}
static func sanitize(value: Variant) -> Dictionary:
 var result := initial()
 if not value is Dictionary:return result
 var owned=value.get("owned",[])
 if owned is Array:
  for id in owned:
   if id is String and not item(id).is_empty() and not result.owned.has(id):result.owned.append(id)
 var equipped=value.get("equipped",{})
 if equipped is Dictionary:
  for slot in SLOTS:
   var id := str(equipped.get(slot,slot+"_default"))
   if result.owned.has(id) and item(id).slot==slot:result.equipped[slot]=id
 return result
static func reward(index: int,cost: int) -> Dictionary:
 if index<1 or index>=20:return {"coins":0,"xp":0,"clothes":[]}
 var clothes: Array=[]
 for entry in ITEMS:
  if int(entry.get("reward_zone",-1))==index:clothes.append(entry.id)
 return {"coins":maxi(15,int(round(float(cost)*0.08))),"xp":10+index*5,"clothes":clothes}
