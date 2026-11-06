class_name RunEnemy
extends RefCounted

var kind=0
var uid=0
var mass=10.0
var radius=14.0
var hp=3
var max_hp=3
var pos=Vector2.ZERO
var velocity=Vector2.ZERO
var face=Vector2.DOWN
var state="spawn"
var timer=1.0
var clock=0.0
var stun=0.0
var flash=0.0
var hit_cooldown=0.0
var last_attack=-1
var phase=0
var cycle=0
var dead=false
var warning_seen=false
var hit_direction=Vector2.RIGHT

func _init(type: int,id: int,point: Vector2,weight: float):
	kind=type
	uid=id
	pos=point
	mass=weight
	radius=RunRules.radius(mass)
	max_hp=[2,3,4,3,3,18,22,28][kind]
	hp=max_hp
	clock=id*.53

func armored() -> bool:
	return kind>=5 and state not in ["rest","stunned"]

func blocks_from(point:Vector2) -> bool:
	if armored(): return true
	return kind==2 and state=="guard" and stun<=0 and face.dot((point-pos).normalized())>.5

func warning_duration() -> float:
	return 1.2 if kind>=5 else (.9 if kind==3 else .7)

func attack_duration() -> float:
	return 1.0 if kind>=5 else .5

func attack_speed() -> float:
	if fires_volley(): return 0.0
	return (470.0 if kind==6 else 350.0) if kind>=5 else (300.0 if kind==1 else 170.0)

func fires_volley() -> bool:
	return kind==3 or (kind==7 and cycle%2==0)

func volley_angles() -> Array:
	if kind==3: return [-.22,0.0,.22]
	var angles:Array=[]
	for i in 9: angles.append((i-4)*.19)
	return angles

func projectile_speed() -> float:
	return 180.0 if kind==3 else 200.0

func projectile_radius() -> float:
	return radius*(.25 if kind==3 else .15)

func step(dt: float,a):
	clock+=dt
	timer-=dt
	stun=maxf(0,stun-dt)
	flash=maxf(0,flash-dt)
	hit_cooldown=maxf(0,hit_cooldown-dt)
	if state=="spawn":
		if timer<=0: state="approach";timer=1.0+fmod(uid*.33,1.2)
		return
	if stun>0:
		pos+=velocity*dt
		velocity=velocity.move_toward(Vector2.ZERO,900*RunRules.motion_scale(mass)*dt)
		return
	if state not in ["telegraph","attack","guard_windup","guard"]: face=(a.player-pos).normalized()
	var unit=RunRules.motion_scale(mass)
	if kind>=5:
		boss_step(dt,a,unit)
		return
	match state:
		"approach":
			var direction=face
			if kind==3 and pos.distance_to(a.player)<220*unit: direction=-face*.5
			var side=face.orthogonal()*sin(clock*.8+uid)*.22
			pos+=(direction+side)*[42,57,34,37,40][kind]*unit*dt
			if timer<=0:
				if kind==4:
					a.add_puddle(pos,radius*2)
					timer=3
				elif kind==2: state="guard_windup";timer=.45
				else:
					state="telegraph"
					timer=warning_duration()
		"guard_windup":
			if timer<=0: state="guard";timer=.95
		"guard":
			if timer<=0: state="rest";timer=1.6
		"telegraph":
			if timer<=0:
				state="attack"
				timer=attack_duration()
				velocity=face*attack_speed()*unit
				if fires_volley():
					for angle in volley_angles(): a.shoot(pos,face.rotated(angle)*projectile_speed()*unit,projectile_radius(),kind)
		"attack":
			if kind!=3: pos+=velocity*dt
			if timer<=0: state="rest";timer=.9
		"rest":
			if timer<=0: state="approach";timer=1.5

func boss_step(dt: float,a,unit: float):
	var new_phase=1 if hp<=max_hp*.5 else 0
	if new_phase>phase:
		phase=new_phase
		a.drop_item(pos+Vector2(radius*2,0),"heart",1)
		if kind==5:
			for i in 4: a.spawn_enemy(0,mass*.08,pos+Vector2.from_angle(i*TAU/4)*radius*3)
	match state:
		"approach":
			pos+=face*25*unit*dt
			if timer<=0:
				state="telegraph"
				timer=warning_duration()
				face=(a.player-pos).normalized()
				if kind==6: face=Vector2(signf(face.x),0)
				a.sound.play("warning")
		"telegraph":
			if timer<=0:
				state="attack"
				timer=attack_duration()
				velocity=face*attack_speed()*unit
				if fires_volley():
					for angle in volley_angles(): a.shoot(pos,face.rotated(angle)*projectile_speed()*unit,projectile_radius(),kind)
		"attack":
			pos+=velocity*dt
			if timer<=0:
				state="rest"
				timer=3.2
				cycle+=1
				velocity=Vector2.ZERO
				a.notice(a.trx("БРОНЯ РАСКРЫТА","ARMOR OPEN"),Color("9be8c5"))
		"rest":
			if timer<=0: state="approach";timer=.7
