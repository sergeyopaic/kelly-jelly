class_name RunRules
extends RefCounted

const START_MASS = 30.0
const HEART_EVERY = 12
const MAX_ENEMIES = 110
const SPRINT_SECONDS = 1.2
const SPRINT_RECOVERY = .6
const SPRINT_RECOVERY_DELAY = .65
const SPRINT_MULTIPLIER = 1.7
const UP_RU = ["Тяжёлый удар","Разгон","Упругая пружина","Питательная добыча","Вторая порция","Сахарный магнит","Лёгкий шаг","Хрустящая корочка","Большая ложка","Быстрое обучение","Длинный рывок","Сладкая аптечка","Сахарный запас","Второе дыхание","Попутный ветер"]
const UP_EN = ["Heavy impact","Acceleration","Spring belly","Nutritious prey","Second helping","Sugar magnet","Light feet","Crispy shell","Big spoon","Quick learner","Long dash","Sweet first aid","Sugar reserve","Second wind","Tailwind"]
const DESC_RU = ["Импульс столкновения +20%","Скорость рывка +12%","Перезарядка рывка −12%","Масса от поглощения +20%","+1 максимум ♥; восстановить 2 ♥","Радиус сбора опыта и сердец +35%","Скорость ходьбы +12%","Защита от удара; обновляется раз в 30 с","Импульс толчка +30% и дальность +20%","Получаемый опыт +20%","Длительность рывка +15%","Восстановить всё здоровье; сердца чаще","Запас ускорения +0,4 с","Восстановление выносливости +25%","Скорость ускоренного бега +10%"]
const DESC_EN = ["Collision momentum +20%","Dash speed +12%","Dash cooldown −12%","Absorbed mass +20%","+1 maximum heart; heal 2","XP and heart pickup radius +35%","Movement speed +12%","Block one hit; refresh every 30s","Push momentum +30%, range +20%","Experience gained +20%","Dash duration +15%","Full heal; hearts drop more often","Sprint duration +0.4s","Stamina recovery +25%","Sprint movement speed +10%"]

static func radius(mass: float) -> float:
	return 18.0*pow(maxf(1,mass)/START_MASS,0.35)

static func motion_scale(mass: float) -> float:
	return pow(maxf(1,mass)/START_MASS,0.20)

static func zoom_for(mass: float) -> float:
	# The body grows on screen as well as in world space. At enormous scales the
	# camera follows the world scale, keeping the whole body visible indefinitely.
	var growth=radius(mass)/18.0
	return minf(pow(growth,-0.48),58.0/radius(mass))

static func xp_needed(level: int) -> float:
	return 12.0+level*7.0+level*level*1.0

static func absorbed_mass(own_mass:float,prey_mass:float,nutrition_rank:int) -> float:
	# Oversized prey still rewards a clean kill, without multiplying the next spawn tier.
	var efficiency=1.0/sqrt(1.0+maxf(0,log(maxf(1,own_mass)/START_MASS))/3.0)
	return .08*minf(prey_mass,own_mass)*(1+.2*nutrition_rank)*efficiency

static func prey_xp(own_mass:float,prey_mass:float) -> int:
	# Reward relative threat instead of absolute mass: tiny late-game prey stays tiny.
	return 4+int(clampf(sqrt(prey_mass/maxf(1,own_mass))*5,0,12))

static func impact(mass: float,enemy_mass: float,speed: float,bonus: float=1.0,armored: bool=false) -> Dictionary:
	var ratio=mass/maxf(1,enemy_mass)
	var power=ratio*maxf(0,speed)/600.0*bonus
	var reason="hit"
	if armored: reason="armor"
	elif ratio<0.30: reason="mass"
	elif power<0.55: reason="speed"
	return {"success":reason=="hit","reason":reason,"power":power,"damage":maxi(1,int(floor(power*2.2))) if reason=="hit" else 0,"required_mass":enemy_mass*0.30}

static func amount(value: float) -> String:
	if value>=1e12: return "%.1fT"%(value/1e12)
	if value>=1e9: return "%.1fB"%(value/1e9)
	if value>=1e6: return "%.1fM"%(value/1e6)
	if value>=10000: return "%.1fk"%(value/1000)
	return str(int(value))

static func time_text(seconds: float) -> String:
	return "%02d:%02d"%[int(seconds)/60,int(seconds)%60]
