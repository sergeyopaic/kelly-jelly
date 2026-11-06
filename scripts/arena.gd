class_name JellyArena
extends Node2D

signal finished(won: bool)
signal choose_upgrade
signal tutorial_complete

const FIELD = Rect2(62,112,836,366)
var profile: JellyProfile
var sound: JellySound
var art
var level = 0
var wave = -1
var player = Vector2(480,330)
var velocity = Vector2.ZERO
var aim = Vector2.RIGHT
var mass = 30.0
var hp = 5
var max_hp = 5
var invincible = 0.0
var charge = 0.0
var charging = false
var dash_left = 0.0
var dash_cooldown = 0.0
var dash_damage = 2
var dash_force = 1.0
var dash_id = 0
var bounces = 0
var push_cd = 0.0
var push_visual = 0.0
var hit_flash = 0.0
var absorb_visual = 0.0
var squash = 0.0
var clock = 0.0
var elapsed = 0.0
var score = 0
var chain = 0
var best_chain = 0
var chain_left = 0.0
var chain_targets = {}
var pair_hits = {}
var hurt_count = 0
var incoming = 0
var shield = false
var upgrades: Array = []
var enemies: Array[JellyEnemy] = []
var items: Array = []
var bullets: Array = []
var particles: Array = []
var puddles: Array = []
var bumpers: Array[Vector2] = []
var uid = 0
var wave_wait = 2.0
var between = false
var active = true
var ended = false
var gamepad = false
var joy_device = 0
var banner = ""
var banner_time = 0.0
var tutorial = -1
var tutorial_walk = 0.0
var tutorial_pickups = 0
var tutorial_dashes = 0
var tutorial_pushes = 0
var rng = RandomNumberGenerator.new()
var run_seed = 0
var bot = false
var bot_charge = 0.0
var bot_pickup = 0.0
var queued_wave: Array = []
var shake = 0.0
var hit_pause = 0.0
var hit_pause_budget = 0.0
var hit_pause_window = 0.0

func trx(ru: String,en: String) -> String:
	return ru if profile.data.lang == "ru" else en

func setup(index: int,p: JellyProfile,s: JellySound,renderer,training: bool = false):
	level = index
	profile = p
	sound = s
	art = renderer
	run_seed = int(Time.get_unix_time_from_system()) + index*997
	rng.seed = run_seed
	if level in [0,1]: bumpers = [Vector2(240,260),Vector2(720,350)]
	elif level in [2,3]: bumpers = [Vector2(290,230),Vector2(670,370),Vector2(290,370),Vector2(670,230)]
	else: bumpers = [Vector2(220,230),Vector2(740,390)]
	for i in 8: drop(Vector2(360+(i%4)*80,210+(i/4)*160),5)
	if training:
		tutorial = 0
		wave_wait = 999
	else:
		banner = GameData.LEVELS[level][profile.data.lang]
		banner_time = 2
	sound.song("arena")

func keep_inside(p: Vector2,r: float) -> Vector2:
	return Vector2(clampf(p.x,FIELD.position.x+r,FIELD.end.x-r),clampf(p.y,FIELD.position.y+r,FIELD.end.y-r))

func preview_segment(origin: Vector2,direction: Vector2,length: float,r: float) -> Dictionary:
	var distance = length
	var normal = Vector2.ZERO
	for axis in 2:
		if absf(direction[axis]) < .0001: continue
		var edge = FIELD.end[axis]-r if direction[axis]>0 else FIELD.position[axis]+r
		var t = (edge-origin[axis])/direction[axis]
		if t >= 0 and t < distance:
			distance=t
			normal=Vector2.ZERO
			normal[axis]=-signf(direction[axis])
	for bumper in bumpers:
		var offset = origin-bumper
		var b = offset.dot(direction)
		var discriminant = b*b-offset.length_squared()+(r+22)*(r+22)
		if discriminant >= 0:
			var t = -b-sqrt(discriminant)
			if t>=0 and t<distance:
				distance=t
				normal=(origin+direction*t-bumper).normalized()
	return {"point":origin+direction*distance,"normal":normal,"distance":distance}

func start_wave():
	wave += 1
	if wave >= 3:
		finish(true)
		return
	between = false
	shield = 7 in upgrades
	queued_wave = GameData.LEVELS[level].waves[wave].duplicate()
	if level%2 == 1 and wave == 2:
		hp = max_hp
		mass = maxf(50,mass)
		sound.song("boss")
		banner = trx("ДЕСЕРТНЫЙ ПОЕДИНОК","DESSERT SHOWDOWN")
	else: banner = trx("ВОЛНА ","WAVE ")+str(wave+1)+" / 3"
	banner_time = 1.8
	spawn_queue()

func spawn_queue():
	while enemies.size() < 14 and not queued_wave.is_empty(): spawn_enemy(int(queued_wave.pop_front()))

func spawn_enemy(kind: int, at: Vector2 = Vector2(-1,-1)):
	uid += 1
	var p = at
	if p.x < 0:
		p = Vector2(rng.randf_range(120,840),rng.randf_range(160,435))
		for attempt in 30:
			if p.distance_to(player) > 140 and safe_point(p,45): break
			p = Vector2(rng.randf_range(120,840),rng.randf_range(160,435))
		if p.distance_to(player) < 110: p = Vector2(160 if player.x > 480 else 800,170)
	enemies.append(JellyEnemy.new(kind,uid,p))

func safe_point(p: Vector2,r: float) -> bool:
	for b in bumpers:
		if p.distance_to(b) < r+22: return false
	return true

func steer(origin: Vector2,direction: Vector2,r: float) -> Vector2:
	var result = direction
	for b in bumpers:
		var offset = b-origin
		if offset.length() < r+77 and direction.dot(offset.normalized()) > 0.15:
			var tangent = offset.normalized().orthogonal()
			if tangent.dot(direction) < -0.05: tangent = -tangent
			result = (direction*0.25+tangent*1.1-offset.normalized()*0.2).normalized()
	return result

func drop(p: Vector2,value: float,heal: bool = false,delay: float = 0.0,life: float = 99.0):
	p = keep_inside(p,10)
	for b in bumpers:
		if p.distance_to(b) < 34: p = b+(p-b).normalized()*38 if p != b else b+Vector2(38,0)
	if items.size() >= 100 and not heal:
		for item in items:
			if not item.heal:
				item.value += value
				item.life = maxf(item.life,life)
				item.delay = maxf(item.delay,delay)
				return
	items.append({"p":p,"value":value,"heal":heal,"delay":delay,"life":life,"age":0.0,"style":rng.randi_range(0,2)})

func shoot(p: Vector2,v: Vector2,friendly: bool):
	if bullets.size() < 80: bullets.append({"p":p,"v":v,"friendly":friendly,"life":6.0})

func burst(p: Vector2,color: Color,count: int):
	for i in mini(count,200-particles.size()):
		particles.append({"p":p,"v":Vector2.from_angle(randf()*TAU)*randf_range(35,150),"life":randf_range(0.25,0.6),"c":color,"r":randf_range(2,5)})

func begin_charge():
	if active and not ended and dash_left <= 0 and dash_cooldown <= 0:
		charging = true
		charge = 0.0
		sound.play("charge")

func release_dash():
	if not charging: return
	charging = false
	var stats = GameData.dash_stats(mass,charge,3 in upgrades)
	dash_damage = stats.damage
	dash_force = stats.force*(1.2 if 2 in upgrades else 1.0)
	var spent: int = stats.cost
	mass -= spent
	for i in mini(3,spent):
		var value = spent/mini(3,spent)+(1 if i < spent%mini(3,spent) else 0)
		drop(player-aim*35+aim.orthogonal()*(i-1)*12,value,false,0.65,9.0)
	dash_left = stats.duration
	velocity = aim*stats.speed
	dash_cooldown = dash_left+0.3
	bounces = 0
	dash_id += 1
	pair_hits.clear()
	charge = 0
	tutorial_dashes += 1
	sound.play("dash")

func push():
	if not active or ended or push_cd > 0 or dash_left > 0: return
	push_cd = 0.45
	push_visual = 0.18
	tutorial_pushes += 1
	dash_id += 1
	for e in enemies:
		var offset = e.pos-player
		if offset.length() < 70+e.radius and aim.dot(offset.normalized()) > (0.2 if 8 in upgrades else 0.4):
			hit_enemy(e,2 if 8 in upgrades else 1,aim*300,dash_id)
	sound.play("push")

func hit_enemy(e: JellyEnemy,damage: int,impulse: Vector2,id: int,indirect: bool = false):
	if e.state in ["spawn","stunned","defeated"] or e.dead: return
	if not indirect and e.last_hit == id: return
	if not indirect: e.last_hit = id
	if e.kind == 2 and not indirect and impulse.length() > 0 and e.face.dot(-impulse.normalized()) > 0.64:
		damage = 0
	if e.kind >= 5 and e.state != "rest": damage = 0
	e.flash = 0.12
	if e.kind < 5 and impulse.length() > 0:
		e.vel = impulse.limit_length(760)
		e.launched = 0.65
		e.attack_id = id
	if damage <= 0:
		burst(e.pos,Color("a9d6dc"),4)
		sound.play("bounce")
		return
	e.hp -= damage
	if not chain_targets.has(e.uid):
		chain_targets[e.uid] = true
		chain += 1
		best_chain = maxi(best_chain,chain)
	chain_left = 1.5+(0.75 if 6 in upgrades else 0.0)
	burst(e.pos,GameData.COLORS[e.kind],8)
	shake = 2.5
	if hit_pause_budget < 0.09:
		var duration = minf(0.035,0.09-hit_pause_budget)
		hit_pause = maxf(hit_pause,duration)
		hit_pause_budget += duration
	sound.play("hit")
	if e.hp <= 0:
		score += (1000 if e.kind >= 5 else 100)*mini(4,maxi(chain,1))
		e.state = "defeated" if e.kind >= 5 else "stunned"
		e.timer = 1.7 if e.kind >= 5 else 3.0
		if e.kind >= 5:
			bullets.clear()
			burst(e.pos,Color("fff0c7"),40)
			sound.play("win")

func hurt():
	if invincible > 0 or ended: return
	incoming += 1
	if shield:
		shield = false
		invincible = 0.5
		burst(player,Color("fff0c7"),12)
		return
	if profile.data.assist and incoming%2 == 0:
		invincible = 0.6
		return
	hp -= 1
	hurt_count += 1
	invincible = 1.0
	hit_flash = 0.2
	shake = 4.0
	sound.play("hurt")
	burst(player,Color("f5649a"),12)
	if hp <= 0: finish(false)

func finish(won: bool):
	if ended: return
	ended = true
	active = false
	charging = false
	if won:
		profile.record(level,score,hurt_count == 0,best_chain)
		sound.play("win")
	else: sound.play("lose")
	finished.emit(won)

func grant_upgrade(id: int):
	if id in upgrades: return
	upgrades.append(id)
	if id == 4:
		max_hp += 1
		hp = mini(max_hp,hp+2)
	active = true
	wave_wait = 2.0
	between = true

func choices() -> Array:
	var available: Array = []
	for i in 9:
		if i not in upgrades: available.append(i)
	var result: Array = []
	for i in 3:
		var index = rng.randi_range(0,available.size()-1)
		result.append(available.pop_at(index))
	return result

func skip_tutorial():
	tutorial = -1
	profile.data.tutorial = true
	profile.save()
	wave_wait = 1.0
	tutorial_complete.emit()

func _physics_process(dt: float):
	clock += dt
	for p in particles:
		p.life -= dt
		p.p += p.v*dt
		p.v *= 0.94
	particles = particles.filter(func(p): return p.life > 0)
	queue_redraw()
	if not active or ended: return
	hit_pause_window += dt
	if hit_pause_window >= 0.5:
		hit_pause_window = 0
		hit_pause_budget = 0
	if hit_pause > 0:
		hit_pause -= dt
		return
	elapsed += dt
	banner_time = maxf(0,banner_time-dt)
	invincible = maxf(0,invincible-dt)
	hit_flash = maxf(0,hit_flash-dt)
	absorb_visual = maxf(0,absorb_visual-dt)
	push_cd = maxf(0,push_cd-dt)
	push_visual = maxf(0,push_visual-dt)
	dash_cooldown = maxf(0,dash_cooldown-dt)
	shake = maxf(0,shake-20*dt)
	chain_left -= dt
	if chain_left <= 0:
		chain = 0
		chain_targets.clear()
	var move = Input.get_vector("left","right","up","down")
	if bot: move = bot_step(dt)
	else:
		var stick = Vector2(Input.get_joy_axis(joy_device,JOY_AXIS_RIGHT_X),Input.get_joy_axis(joy_device,JOY_AXIS_RIGHT_Y))
		if gamepad:
			if stick.length() > 0.2: aim = stick.normalized()
			elif move.length() > 0.2 and not charging: aim = move.normalized()
		else:
			var delta = get_global_mouse_position()-player
			if delta.length() > 5: aim = delta.normalized()
	if profile.data.aim_help and charging:
		for e in enemies:
			if e.state in ["spawn","stunned","defeated"]: continue
			var dir = (e.pos-player).normalized()
			if aim.dot(dir) > 0.985:
				aim = aim.lerp(dir,0.08).normalized()
				break
	if charging: charge = minf(0.8,charge+dt)
	var r = GameData.radius(mass)
	if dash_left > 0:
		dash_left -= dt
		# Four swept substeps keep a 1000-unit/s dash below the smallest target diameter.
		for step in 4:
			var candidate = player+velocity*dt/4
			var bounded = keep_inside(candidate,r)
			if candidate.distance_to(bounded) > 0.01:
				if candidate.x != bounded.x: velocity.x *= -1
				if candidate.y != bounded.y: velocity.y *= -1
				aim = velocity.normalized()
				bounces += 1
				burst(bounded,Color("fff0c7"),6)
				sound.play("bounce")
				if bounces >= (3 if 0 in upgrades else 2): dash_left = 0
			player = bounded
			resolve_bumpers(r,true)
			for e in enemies:
				if player.distance_to(e.pos) < r+e.radius: hit_enemy(e,dash_damage,velocity.normalized()*520*dash_force,dash_id)
		if randf() < 0.5: burst(player,Color("ffc2d8"),1)
	else:
		var speed = 210*(1.1 if mass < 30 else (0.9 if mass >= 70 else 1.0))
		if 5 in upgrades: speed *= 1.12
		if charging: speed *= 0.45
		for puddle in puddles:
			if player.distance_to(puddle.p) < 28: speed *= 0.875 if 5 in upgrades else 0.75
		var acceleration = 2400.0
		if level >= 4 and (absf(player.y-230)<20 or absf(player.y-390)<20): acceleration /= 1.2
		velocity = velocity.move_toward(move*speed,acceleration*dt)
		player = keep_inside(player+velocity*dt,r)
		resolve_bumpers(r,false)
	if tutorial >= 0:
		tutorial_walk += move.length()*dt
		if tutorial == 0 and tutorial_walk > 1: tutorial = 1
		if tutorial == 1 and tutorial_pickups >= 1: tutorial = 2
		if tutorial == 2 and tutorial_dashes > 0: tutorial = 3
		if tutorial == 3 and tutorial_pushes > 0: skip_tutorial()
	for e in enemies: e.step(dt,self)
	resolve_enemy_pairs()
	for e in enemies:
		if e.dead: continue
		if e.state == "stunned" and player.distance_to(e.pos) < r+e.radius+8:
			e.dead = true
			mass = minf(100,mass+10)
			absorb_visual = 0.3
			burst(e.pos,Color("ffc2d8"),8)
			sound.play("absorb")
		elif e.state not in ["spawn","stunned","defeated"] and e.launched <= 0 and dash_left <= 0 and player.distance_to(e.pos) < r+e.radius-3:
			hurt()
			player = keep_inside(player+(player-e.pos).normalized()*8,r)
	enemies = enemies.filter(func(e): return not e.dead)
	step_items(dt,r)
	step_bullets(dt,r)
	for p in puddles: p.life -= dt
	puddles = puddles.filter(func(p): return p.life > 0)
	if tutorial < 0 and not ended:
		spawn_queue()
		if enemies.is_empty() and queued_wave.is_empty():
			if wave == -1 or between:
				wave_wait -= dt
				if wave_wait <= 0: start_wave()
			elif wave < 2:
				drop(player+Vector2(0,22),0,true)
				# Collect remaining earned rewards before opening the paused choice screen.
				for item in items:
					if item.heal: hp = mini(max_hp,hp+1)
					else: mass = minf(100,mass+item.value)
				items.clear()
				active = false
				charging = false
				choose_upgrade.emit()
			else: finish(true)

func resolve_bumpers(r: float,dashing: bool):
	for b in bumpers:
		var delta = player-b
		if delta.length() < r+22:
			var normal = delta.normalized() if delta.length() > 0 else Vector2.RIGHT
			player = b+normal*(r+22+0.1)
			if dashing and velocity.dot(normal) < 0:
				velocity = velocity.bounce(normal)
				aim = velocity.normalized()
				sound.play("bounce")
				burst(b,Color("fff0c7"),8)

func resolve_enemy_pairs():
	for i in enemies.size():
		var e = enemies[i]
		for b in bumpers:
			if e.pos.distance_to(b) < e.radius+22:
				var normal = (e.pos-b).normalized() if e.pos != b else Vector2.RIGHT
				e.pos = b+normal*(e.radius+23)
				if e.launched > 0 and e.vel.dot(normal) < 0:
					e.vel = e.vel.bounce(normal)*0.7
					hit_enemy(e,1,Vector2.ZERO,e.attack_id,true)
		for j in range(i+1,enemies.size()):
			var other = enemies[j]
			var delta = other.pos-e.pos
			var distance = delta.length()
			if distance >= e.radius+other.radius: continue
			var normal = delta.normalized() if distance > 0 else Vector2.RIGHT
			if e.launched > 0 and e.vel.length() > 100:
				chain_collision(e,other,normal)
			elif other.launched > 0 and other.vel.length() > 100: chain_collision(other,e,-normal)
			if e.state not in ["stunned","defeated"] and other.state not in ["stunned","defeated"]:
				var correction = normal*(e.radius+other.radius-distance)*0.5
				e.pos = keep_inside(e.pos-correction,e.radius)
				other.pos = keep_inside(other.pos+correction,other.radius)

func chain_collision(source: JellyEnemy,target: JellyEnemy,normal: Vector2):
	var key = str(mini(source.uid,target.uid))+":"+str(maxi(source.uid,target.uid))+":"+str(source.attack_id)
	if pair_hits.has(key): return
	pair_hits[key] = true
	hit_enemy(target,1,normal*source.vel.length()*0.7,source.attack_id,true)
	source.vel *= 0.65

func step_items(dt: float,r: float):
	for item in items:
		item.age += dt
		item.life -= dt
		item.delay -= dt
		if item.delay > 0: continue
		var distance = player.distance_to(item.p)
		var pickup = (r+18)*(1.4 if 1 in upgrades else 1.0)
		if distance < pickup+30: item.p = item.p.move_toward(player,260*dt)
		if distance < pickup:
			if item.heal:
				if hp == max_hp: score += 100
				hp = mini(max_hp,hp+1)
				sound.play("heal")
			else:
				mass = minf(100,mass+item.value)
				score += 10
				sound.play("pickup")
				tutorial_pickups += 1
			item.life = -1
			absorb_visual = 0.15
	items = items.filter(func(item): return item.life > 0)

func step_bullets(dt: float,r: float):
	for b in bullets:
		b.life -= dt
		b.p += b.v*dt
		if not FIELD.has_point(b.p): b.life = -1
		if not b.friendly and b.p.distance_to(player) < r+8:
			if dash_left > 0:
				b.friendly = true
				b.v = aim*400
				sound.play("bounce")
			else:
				hurt()
				b.life = -1
		if b.friendly:
			for e in enemies:
				if b.p.distance_to(e.pos) < e.radius+7 and b.life > 0:
					dash_id += 1
					hit_enemy(e,2,b.v,dash_id)
					b.life = -1
	bullets = bullets.filter(func(b): return b.life > 0)

func bot_step(dt: float) -> Vector2:
	# Test driver uses the same public attacks and real damage; never grants health or kills enemies.
	var target: JellyEnemy = null
	var closest = 10000.0
	for e in enemies:
		var distance = player.distance_to(e.pos)
		if distance < closest and e.state not in ["spawn","defeated"]:
			target = e
			closest = distance
	if target:
		aim = (target.pos-player).normalized()
		if target.kind >= 5 and target.state != "rest":
			if target.kind == 6:
				# Stay beside the announced lane; don't follow the rolling pin into it.
				var safe_y = 315.0 if target.pos.y<285 else 190.0
				return steer(player,(Vector2(clampf(target.pos.x,180,780),safe_y)-player).normalized(),GameData.radius(mass))
			if target.state == "telegraph": return steer(player,aim.orthogonal(),GameData.radius(mass))
			return steer(player,-aim if closest < 200 else aim.orthogonal(),GameData.radius(mass))
		if closest < 90: push()
		if not charging and dash_cooldown <= 0: begin_charge()
		if charging and charge >= 0.65: release_dash()
		if target.kind == 2 and target.face.dot(-aim) > .64:
			return steer(player,aim.rotated(1.2),GameData.radius(mass))
		return steer(player,aim if closest > 60 else -aim*0.5,GameData.radius(mass))
	if not items.is_empty():
		return (items[0].p-player).normalized()
	return Vector2.ZERO

func _draw():
	if art: art.draw_arena(self)
