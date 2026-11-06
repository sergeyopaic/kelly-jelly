class_name JellyEnemy
extends RefCounted

var kind = 0
var uid = 0
var pos = Vector2.ZERO
var vel = Vector2.ZERO
var face = Vector2.DOWN
var hp = 2
var max_hp = 2
var radius = 17.0
var state = "spawn"
var timer = 0.85
var clock = 0.0
var flash = 0.0
var launched = 0.0
var attack_id = -1
var last_hit = -2
var phase = 0
var cycle = 0
var target = Vector2.ZERO
var dead = false

func _init(type: int, id: int, point: Vector2):
	kind = type
	uid = id
	pos = point
	hp = GameData.HP[kind]
	max_hp = hp
	radius = 32.0 if kind >= 5 else 17.0
	if kind == 6: radius = 38
	clock = float(id)*0.9

func step(dt: float, arena):
	clock += dt
	flash = maxf(0,flash-dt)
	timer -= dt
	if state == "stunned":
		pos = arena.keep_inside(pos + vel*dt,radius)
		vel = vel.move_toward(Vector2.ZERO,900*dt)
		if timer <= 0:
			arena.drop(pos,10)
			dead = true
		return
	if state == "defeated":
		if timer <= 0: dead = true
		return
	if state == "spawn":
		if timer <= 0:
			state = "approach"
			timer = 0.8 + fmod(float(uid)*0.23,0.8)
		return
	if launched > 0:
		launched -= dt
		var before = pos + vel*dt
		pos = arena.keep_inside(before,radius)
		if pos.distance_to(before) > 0.1 and vel.length() > 150:
			if pos.x != before.x: vel.x *= -0.5
			if pos.y != before.y: vel.y *= -0.5
			arena.hit_enemy(self,1,Vector2.ZERO,attack_id,true)
			arena.burst(pos,GameData.COLORS[kind],8)
			arena.sound.play("bounce")
		vel = vel.move_toward(Vector2.ZERO,600*dt)
		return
	var to_player: Vector2 = arena.player-pos
	if state != "telegraph" and state != "attack": face = to_player.normalized()
	if kind >= 5:
		boss_step(dt,arena)
		return
	match state:
		"approach":
			var speed = [48,60,40,34,43][kind]
			var direction = face
			if kind == 3 and to_player.length() < 210: direction = -face*0.5
			pos = arena.keep_inside(pos+arena.steer(pos,direction,radius)*speed*dt,radius)
			if kind == 4 and timer <= 0:
				arena.puddles.append({"p":pos,"life":4.0})
				timer = 2.5
			elif timer <= 0 and kind != 4:
				if kind == 2:
					timer = 1.2
				else:
					state = "telegraph"
					timer = [0.45,0.7,0.7,0.8,0.7][kind]
					target = arena.player
					face = (target-pos).normalized()
		"telegraph":
			if timer <= 0:
				state = "attack"
				timer = 0.30 if kind == 0 else 0.48
				if kind == 3:
					for a in [-0.22,0.0,0.22]: arena.shoot(pos,face.rotated(a)*180,false)
				else: vel = face*(230 if kind == 0 else 390)
		"attack":
			if kind != 3: pos = arena.keep_inside(pos+vel*dt,radius)
			if timer <= 0:
				state = "rest"
				timer = 0.8
		"rest":
			if timer <= 0:
				state = "approach"
				timer = 1.3

func boss_step(dt: float, arena):
	var next_phase = 0
	if kind == 7:
		next_phase = 2 if hp <= max_hp*0.3 else (1 if hp <= max_hp*0.65 else 0)
	else: next_phase = 1 if hp <= max_hp*0.5 else 0
	if next_phase > phase:
		phase = next_phase
		arena.bullets.clear()
		arena.drop(arena.keep_inside(pos+Vector2(0,65),12),0,true)
		if kind == 5 or (kind == 7 and phase == 2):
			for i in (2 if kind == 5 else 4): arena.spawn_enemy(i%2)
		arena.banner = arena.trx("Ещё не всё!","Not done yet!")
		arena.banner_time = 1.5
	match state:
		"approach":
			pos = arena.keep_inside(pos+face*35*dt,radius)
			if timer <= 0:
				state = "telegraph"
				timer = 1.0
				target = arena.player
				face = (target-pos).normalized()
				if kind == 6:
					pos.x = 110 if cycle%2 == 0 else 850
					pos.y = [180.0,290.0,405.0][cycle%3]
					face = Vector2.RIGHT if cycle%2 == 0 else Vector2.LEFT
				arena.sound.play("warning")
		"telegraph":
			if timer <= 0:
				state = "attack"
				timer = 1.8 if kind == 6 else 0.8
				vel = face*(430 if kind == 6 else 500)
				if kind == 7 and (phase == 0 or (phase == 2 and cycle%2 == 0)):
					for i in 9: arena.shoot(pos,face.rotated((i-4)*0.18)*190,false)
					vel = Vector2.ZERO
		"attack":
			var candidate = pos+vel*dt
			pos = arena.keep_inside(candidate,radius)
			if timer <= 0 or candidate.distance_to(pos) > 0.1:
				cycle += 1
				state = "rest"
				timer = 2.5
				vel = Vector2.ZERO
				arena.burst(pos,Color("fff0c7"),10)
		"rest":
			if timer <= 0:
				state = "approach"
				timer = 0.6
