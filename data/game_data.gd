class_name GameData
extends RefCounted

const LEVELS = [
 {"ru":"Побег с тарелки", "en":"Off the plate", "waves":[[0,0,0,0],[0,0,0,0,0,1,1],[0,0,0,0,1,1,1]], "theme":0},
 {"ru":"Пудинг недоволен", "en":"Pudding has a problem", "waves":[[0,0,0,0,1,1],[0,0,0,2,2],[5]], "theme":0},
 {"ru":"Липкое дело", "en":"A sticky situation", "waves":[[0,0,0,0,4,4,4],[1,1,1,3,3,3],[2,2,2,4,4,4,3,3]], "theme":1},
 {"ru":"Раскатать праздник", "en":"Rolling into trouble", "waves":[[1,1,1,2,2,2],[3,3,3,4,4,4,4],[6]], "theme":1},
 {"ru":"Холодный приём", "en":"A chilly reception", "waves":[[1,1,1,1,3,3,3],[2,2,2,2,4,4,4,4],[0,0,0,0,1,1,1,3,3,3,2,2]], "theme":2},
 {"ru":"Право быть желе", "en":"Born to wobble", "waves":[[0,0,0,1,1,3,3],[2,2,4,4,4,3,3],[7]], "theme":2}
]
const HP = [2,3,4,2,3,28,36,48]
const NAMES_RU = ["Мармеладка","Вилка-задира","Вафельный щит","Перечница","Ириска","Сэр Пудинг","Мадам Скалка","Главный Венчик"]
const NAMES_EN = ["Sour gummy","Fork punk","Waffle guard","Pepper pot","Sticky toffee","Sir Pudding","Madame Rolling Pin","The Grand Whisk"]
const UP_RU = ["Пружинный животик","Сахарный магнит","Плотное желе","Лёгкая рецептура","Вторая порция","Скользкий характер","Долгое послевкусие","Хрустящая корочка","Большая ложка"]
const UP_EN = ["Spring belly","Sugar magnet","Dense jelly","Light recipe","Second helping","Slippery soul","Sweet aftertaste","Crispy shell","Big spoon"]
const DESC_RU = ["Ещё один рикошет от стены","Радиус подбора +40%","Сила отбрасывания +20%","Рывок расходует на 3 массы меньше","+1 максимум здоровья; лечение +2","Скорость +12%; лужи слабее вдвое","Окно цепочки +0,75 с","Защита от первого удара каждой волны","Толчок: +1 урон и +20% ширина"]
const DESC_EN = ["One extra wall ricochet","Pickup radius +40%","Knockback force +20%","Dash costs 3 less mass","+1 maximum heart; heal 2","Speed +12%; puddles half as sticky","Chain window +0.75 seconds","Block the first hit of each wave","Push: +1 damage, +20% width"]
const COLORS = [Color("ef7da6"),Color("a9d6dc"),Color("e7b66b"),Color("c19ecb"),Color("dc9565"),Color("f3bf73"),Color("cf9361"),Color("9ae0dc")]

static func radius(mass: float) -> float:
	return 12.0 if mass < 30 else (16.0 if mass < 70 else 21.0)

static func dash_stats(mass: float, charge: float, light: bool) -> Dictionary:
	var tier = 0 if charge < 0.3 else (1 if charge < 0.6 else 2)
	var cost = maxi(2, [5,10,15][tier] - (3 if light else 0))
	if mass < cost:
		return {"cost":0, "damage":2, "force":1.0, "speed":650.0, "duration":0.16}
	return {"cost":cost,"damage":2 + (1 if tier > 0 else 0) + (1 if mass >= 70 else 0),"force":1.0 if mass < 30 else (1.3 if mass < 70 else 1.6),"speed":650.0+350.0*charge/0.8,"duration":0.16+0.12*charge/0.8}
