extends RefCounted
const ZONE_SPACING := 30.0
const MAX_STOCK := 48
const MAX_WORKERS := 3
const ZONES := [
 {
  "name": "Крижаний причал",
  "kitchen": "Продаж сирого улову",
  "dish": "Сира риба",
  "cost": 0,
  "price": 8,
  "time": 0.0,
  "color": "c28c78",
  "icon": "pad_fish",
  "design": 0
 },
 {
  "name": "Табір гриля",
  "kitchen": "Вугільний гриль",
  "dish": "Рибний стейк",
  "cost": 120,
  "price": 20,
  "time": 3.55,
  "color": "bd8875",
  "icon": "recipe_grill",
  "design": 1
 },
 {
  "name": "Хвойна коптильня",
  "kitchen": "Дерев’яна коптильня",
  "dish": "Копчене філе",
  "cost": 700,
  "price": 29,
  "time": 3.9,
  "color": "b47d66",
  "icon": "recipe_smoke",
  "design": 2
 },
 {
  "name": "Гаряче джерело",
  "kitchen": "Казан на вогнищі",
  "dish": "Північна юшка",
  "cost": 1900,
  "price": 50,
  "time": 4.25,
  "color": "b58a79",
  "icon": "recipe_soup",
  "design": 3
 },
 {
  "name": "Полярний ресторан",
  "kitchen": "Подвійна ресторанна піч",
  "dish": "Полярне асорті",
  "cost": 4600,
  "price": 82,
  "time": 4.6,
  "color": "b98672",
  "icon": "feast",
  "design": 4
 },
 {
  "name": "Бамбукова затока",
  "kitchen": "Суші-бар",
  "dish": "Роли з рибою",
  "cost": 9000,
  "price": 125,
  "time": 4.95,
  "color": "7e9b60",
  "icon": "feast",
  "design": 5
 },
 {
  "name": "Солоний маяк",
  "kitchen": "Соляна піч",
  "dish": "Риба в солі",
  "cost": 17000,
  "price": 185,
  "time": 5.3,
  "color": "b5a78b",
  "icon": "feast",
  "design": 6
 },
 {
  "name": "Бурштиновий ліс",
  "kitchen": "Медова жаровня",
  "dish": "Медове філе",
  "cost": 30000,
  "price": 260,
  "time": 5.65,
  "color": "bf925a",
  "icon": "feast",
  "design": 7
 },
 {
  "name": "Льодовикові печери",
  "kitchen": "Крижаний бар",
  "dish": "Сашимі",
  "cost": 50000,
  "price": 355,
  "time": 6.0,
  "color": "81b4cb",
  "icon": "feast",
  "design": 8
 },
 {
  "name": "Мідна кузня",
  "kitchen": "Мідна сковорода",
  "dish": "Риба на сковороді",
  "cost": 80000,
  "price": 480,
  "time": 6.35,
  "color": "b47750",
  "icon": "feast",
  "design": 9
 },
 {
  "name": "Туманні болота",
  "kitchen": "Парова кухня",
  "dish": "Рибні пельмені",
  "cost": 125000,
  "price": 640,
  "time": 6.7,
  "color": "658e7a",
  "icon": "feast",
  "design": 10
 },
 {
  "name": "Кораловий берег",
  "kitchen": "Гриль для шпажок",
  "dish": "Рибні шашлички",
  "cost": 190000,
  "price": 845,
  "time": 7.05,
  "color": "c38e83",
  "icon": "feast",
  "design": 11
 },
 {
  "name": "Піщаний оазис",
  "kitchen": "Тандир",
  "dish": "Риба тандурі",
  "cost": 280000,
  "price": 1100,
  "time": 7.4,
  "color": "cbb177",
  "icon": "feast",
  "design": 12
 },
 {
  "name": "Гірська фортеця",
  "kitchen": "Кам’яна піч",
  "dish": "Гірська печеня",
  "cost": 410000,
  "price": 1420,
  "time": 7.75,
  "color": "8e979e",
  "icon": "feast",
  "design": 13
 },
 {
  "name": "Сад лотоса",
  "kitchen": "Бамбукова пароварка",
  "dish": "Риба в лотосі",
  "cost": 590000,
  "price": 1820,
  "time": 8.1,
  "color": "94b5a2",
  "icon": "feast",
  "design": 14
 },
 {
  "name": "Лавова пристань",
  "kitchen": "Лавовий гриль",
  "dish": "Гострий стейк",
  "cost": 840000,
  "price": 2320,
  "time": 8.45,
  "color": "84665f",
  "icon": "feast",
  "design": 15
 },
 {
  "name": "Срібний архіпелаг",
  "kitchen": "Срібний бар",
  "dish": "Рибний тартар",
  "cost": 1180000,
  "price": 2940,
  "time": 8.8,
  "color": "a7b7c2",
  "icon": "feast",
  "design": 16
 },
 {
  "name": "Небесна обсерваторія",
  "kitchen": "Сферична піч",
  "dish": "Рибні кульки",
  "cost": 1640000,
  "price": 3710,
  "time": 9.15,
  "color": "8793ad",
  "icon": "feast",
  "design": 17
 },
 {
  "name": "Палац сяйва",
  "kitchen": "Кришталева кухня",
  "dish": "Асорті сяйва",
  "cost": 2250000,
  "price": 4660,
  "time": 9.5,
  "color": "b69abb",
  "icon": "feast",
  "design": 18
 },
 {
  "name": "Королівська гавань",
  "kitchen": "Королівська кухня",
  "dish": "Королівське асорті",
  "cost": 3050000,
  "price": 5820,
  "time": 9.85,
  "color": "c1aa75",
  "icon": "feast",
  "design": 19
 }
]
const FISH := [
 {"name":"Дрібна","scale":0.8,"hp":3,"yield":1,"kg":0.8,"ice":1.4,"height":1.45,"respawn":7.0,"value":8},
 {"name":"Середня","scale":1.3,"hp":8,"yield":2,"kg":2.5,"ice":2.15,"height":2.0,"respawn":10.0,"value":18},
 {"name":"Велика","scale":2.0,"hp":18,"yield":4,"kg":6.0,"ice":3.0,"height":2.65,"respawn":14.0,"value":40},
 {"name":"Гігантська","scale":2.8,"hp":36,"yield":7,"kg":12.0,"ice":3.9,"height":3.45,"respawn":18.0,"value":72}
]
const ROLES := {"fisher":{"title":"Рибалка","cost":180},"runner":{"title":"Кур’єр","cost":80},"seller":{"title":"Продавець","cost":100}}

static func new_profile() -> Dictionary:
 var zones: Array=[]
 for i in range(ZONES.size()):
  zones.append({"unlocked":i==0,"kitchen_level":1,"running":false,"catch":[],"input":[],"output":[],"counter":[],"cash":0,"cooking":null,"progress":0.0})
 return {"schema":33,"wardrobe":preload("res://Wardrobe.gd").initial(),"zone_rewards":[0],"ice_cycles":{},"tutorial_step":0,"recovered_cargo":[],"sound_mix":{"effects":1.0,"music":0.32,"ambient":0.70},"wallet":0,"level":1,"xp":0,"hero":{"tool":1,"bag":1,"speed":1,"trade":1},"bag":[],"workers":[],"next_uid":1,"zones":zones,"last_zone":0,"audio_volume":1.0,"sounds_enabled":true}

const SPECIES := [
 {"name":"Окунь","rarity":"Звичайна","weight":42,"multiplier":1.0,"color":"75b8cf","shape":0},
 {"name":"Карась","rarity":"Звичайна","weight":28,"multiplier":1.15,"color":"bdc692","shape":1},
 {"name":"Форель","rarity":"Незвичайна","weight":18,"multiplier":1.5,"color":"ed9aab","shape":0},
 {"name":"Щука","rarity":"Рідкісна","weight":8,"multiplier":2.0,"color":"78bb86","shape":2},
 {"name":"Крижаний короп","rarity":"Епічна","weight":3,"multiplier":2.8,"color":"b69be9","shape":1},
 {"name":"Золота рибка","rarity":"Легендарна","weight":1,"multiplier":4.0,"color":"f4c765","shape":1}
]

static func roll_species(roll: float) -> int:
 var cumulative := 0.0
 for i in range(SPECIES.size()):
  cumulative+=float(SPECIES[i].weight)
  if clampf(roll,0,0.999999)*100<cumulative:return i
 return 0

static func raw(size: int,species: int = 0) -> Dictionary:
 size=clampi(size,0,3)
 species=clampi(species,0,SPECIES.size()-1)
 return {"kind":"raw","size":size,"species":species,"recipe":0,"value":int(round(FISH[size].value*float(SPECIES[species].multiplier)))}

static func dish(recipe: int,species: int = 0) -> Dictionary:
 recipe=clampi(recipe,1,ZONES.size()-1)
 species=clampi(species,0,SPECIES.size()-1)
 return {"kind":"food","size":0,"species":species,"recipe":recipe,"value":int(round(ZONES[recipe].price*(1.0+0.4*(float(SPECIES[species].multiplier)-1.0))))}

static func item_weight(item: Dictionary) -> int:
 return FISH[clampi(int(item.get("size",0)),0,3)].yield if item.get("kind","")=="raw" else 1

static func weight(items: Array) -> int:
 var result := 0
 for item in items:
  result+=item_weight(item)
 return result

static func role_limit(role: String) -> int:
 return 1 if role=="seller" else MAX_WORKERS

static func rounded_cost(value: float) -> int:
 return int(ceil(value/5.0))*5

static func hire_cost(role: String,zone: int,count: int) -> int:
 var base := float({"fisher":110,"runner":100,"seller":120}[role]) if zone==0 else float({"fisher":200,"runner":180,"seller":220}[role])*pow(1.35,zone)
 return rounded_cost(base*pow(1.6,count))
